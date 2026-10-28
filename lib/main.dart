import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'models/pokemon_model.dart';
import 'repositories/pokemon_repository.dart';

import 'screens/pokemon_detail_screen.dart';
import 'screens/teams_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/trainer_profile_screen.dart';

import 'services/pokeapi_service.dart';
import 'services/team_store.dart';
import 'services/collection_store.dart';
import 'services/theme_store.dart';

// =====================================================
// PUNTO DE ENTRADA
// =====================================================

void main() {
  runApp(const PokeVerseApp());
}

// =====================================================
// APLICACIÓN PRINCIPAL Y SISTEMA DE TEMAS
// =====================================================

class PokeVerseApp extends StatefulWidget {
  const PokeVerseApp({super.key});

  @override
  State<PokeVerseApp> createState() => _PokeVerseAppState();
}

class _PokeVerseAppState extends State<PokeVerseApp> {
  final ThemeStore themeStore = ThemeStore();

  @override
  void initState() {
    super.initState();
    themeStore.load();
  }

  @override
  void dispose() {
    themeStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeStore,
      builder: (context, _) {
        return MaterialApp(
          title: 'PokéVerse',
          debugShowCheckedModeBanner: false,

          // Tema seleccionado por el usuario.
          themeMode: themeStore.themeMode,

          // ===============================
          // MODO CLARO
          // ===============================
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFDC0A2D),
              brightness: Brightness.light,
            ),
            cardColor: Colors.white,
          ),

          // ===============================
          // MODO OSCURO
          // ===============================
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121722),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF5365),
              brightness: Brightness.dark,
              surface: const Color(0xFF202838),
            ),
            cardColor: const Color(0xFF202838),
          ),

          // Pantalla principal.
          home: HomeScreen(themeStore: themeStore),
        );
      },
    );
  }
}

// =====================================================
// COLORES DE LOS TIPOS POKÉMON
// =====================================================

Color pokemonTypeColor(String type) {
  const colors = <String, Color>{
    'normal': Color(0xFF919AA2),
    'fire': Color(0xFFFF9D55),
    'water': Color(0xFF5090D6),
    'electric': Color(0xFFF4D23C),
    'grass': Color(0xFF63BC5A),
    'ice': Color(0xFF73CEC0),
    'fighting': Color(0xFFCE416B),
    'poison': Color(0xFFAA6BC8),
    'ground': Color(0xFFD97845),
    'flying': Color(0xFF89AAE3),
    'psychic': Color(0xFFFA7179),
    'bug': Color(0xFF91C12F),
    'rock': Color(0xFFC5B78C),
    'ghost': Color(0xFF5269AD),
    'dragon': Color(0xFF0B6DC3),
    'dark': Color(0xFF5A5465),
    'steel': Color(0xFF5A8EA2),
    'fairy': Color(0xFFEC8FE6),
  };

  return colors[type.toLowerCase()] ?? const Color(0xFF78909C);
}

// =====================================================
// FORMATEO DE NOMBRES
// =====================================================

String capitalize(String value) {
  return value
      .split('-')
      .map((word) {
        if (word.isEmpty) return word;

        return '${word[0].toUpperCase()}'
            '${word.substring(1)}';
      })
      .join(' ');
}

// =====================================================
// PANTALLA PRINCIPAL
// =====================================================

class HomeScreen extends StatefulWidget {
  final ThemeStore themeStore;

  const HomeScreen({super.key, required this.themeStore});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ===================================================
  // ESTADO DE NAVEGACIÓN Y FILTROS
  // ===================================================

  int selectedTab = 0;
  String searchQuery = '';
  String selectedType = 'All';

  final TextEditingController searchController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  // ===================================================
  // SERVICIOS COMPARTIDOS
  // ===================================================

  final PokeApiService apiService = PokeApiService();

  final TeamStore teamStore = TeamStore();

  final CollectionStore collectionStore = CollectionStore();

  late final PokemonRepository repository = PokemonRepository(apiService);

  // ===================================================
  // ESTADO DE LA POKÉDEX
  // ===================================================

  final List<PokemonModel> pokemons = [];

  bool isLoading = false;
  bool hasMore = true;
  String? errorMessage;

  int offset = 0;

  static const int pageSize = 20;

  static const List<String> types = [
    'All',
    'normal',
    'fire',
    'water',
    'electric',
    'grass',
    'ice',
    'fighting',
    'poison',
    'ground',
    'flying',
    'psychic',
    'bug',
    'rock',
    'ghost',
    'dragon',
    'dark',
    'steel',
    'fairy',
  ];

  // ===================================================
  // COLORES DINÁMICOS DEL TEMA
  // ===================================================

  bool get isDarkMode => widget.themeStore.isDark;

  Color get surfaceColor => isDarkMode ? const Color(0xFF202838) : Colors.white;

  Color get secondaryTextColor =>
      isDarkMode ? const Color(0xFFB7C0D0) : const Color(0xFF828A98);

  Color get inputTextColor =>
      isDarkMode ? Colors.white : const Color(0xFF253148);

  // ===================================================
  // INICIALIZACIÓN
  // ===================================================

  @override
  void initState() {
    super.initState();

    // Recuperar equipos guardados.
    teamStore.load();

    // Recuperar favoritos, vistos y capturados.
    collectionStore.load();

    // Detectar proximidad al final del catálogo.
    scrollController.addListener(_onScroll);

    // Cargar primeros Pokémon.
    loadMorePokemon();
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);

    scrollController.dispose();
    searchController.dispose();

    teamStore.dispose();
    collectionStore.dispose();

    super.dispose();
  }

  // ===================================================
  // SCROLL INFINITO
  // ===================================================

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }

    if (scrollController.position.extentAfter < 650) {
      loadMorePokemon();
    }
  }

  Future<void> loadMorePokemon() async {
    if (isLoading || !hasMore || errorMessage != null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final next = await repository.getPokemonPage(
        limit: pageSize,
        offset: offset,
      );

      if (!mounted) return;

      setState(() {
        pokemons.addAll(next);

        offset += next.length;

        hasMore = next.length == pageSize;

        isLoading = false;
      });

      // Evita dejar el catálogo con una cantidad
      // insuficiente de elementos para hacer scroll.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !scrollController.hasClients ||
            !hasMore ||
            isLoading ||
            errorMessage != null) {
          return;
        }

        if (scrollController.position.extentAfter < 650) {
          loadMorePokemon();
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'No se pudieron cargar más Pokémon.';
      });

      debugPrint('Error de PokéAPI: $error');
    }
  }

  void _retryLoading() {
    if (isLoading) return;

    setState(() {
      errorMessage = null;
    });

    loadMorePokemon();
  }

  // ===================================================
  // MENSAJES
  // ===================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ===================================================
  // AGREGAR POKÉMON A UN EQUIPO
  // ===================================================

  Future<void> _addPokemonToTeam(PokemonModel pokemon) async {
    if (teamStore.isLoading) {
      _showMessage('Tus equipos se están cargando.');
      return;
    }

    if (teamStore.error != null) {
      _showMessage('No se pudieron recuperar los equipos guardados.');
      return;
    }

    // Si no hay equipos, ofrecer crear uno.
    if (teamStore.teams.isEmpty) {
      final goToTeams = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Aún no tienes equipos'),
            content: const Text(
              'Crea uno en Mis equipos para agregar Pokémon.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Crear equipo'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (goToTeams == true) {
        _navigateToTab(2);
      }

      return;
    }

    // Seleccionar equipo de destino.
    final teamId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Agregar a ${capitalize(pokemon.name)}'),
          content: SizedBox(
            width: 380,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final team in teamStore.teams)
                  ListTile(
                    leading: const Icon(
                      Icons.catching_pokemon,
                      color: Color(0xFFDC0A2D),
                    ),
                    title: Text(team.name),
                    subtitle: Text(
                      team.pokemonIds.contains(pokemon.id)
                          ? 'Ya está en este equipo'
                          : team.pokemonIds.length >= 6
                          ? 'Equipo completo'
                          : '${team.pokemonIds.length}/6 Pokémon',
                    ),
                    enabled:
                        team.pokemonIds.length < 6 &&
                        !team.pokemonIds.contains(pokemon.id),
                    onTap: () {
                      Navigator.pop(dialogContext, team.id);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (!mounted || teamId == null) return;

    try {
      await teamStore.addPokemon(teamId, pokemon.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${capitalize(pokemon.name)} agregado al equipo!'),
          action: SnackBarAction(
            label: 'VER EQUIPO',
            onPressed: () {
              _navigateToTab(2);
            },
          ),
        ),
      );
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  // ===================================================
  // NAVEGACIÓN
  // ===================================================

  void _navigateToTab(int index) {
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    setState(() {
      selectedTab = index;
    });
  }

  Future<void> _goToPokedex(int pokemonId) async {
    setState(() {
      selectedTab = 0;
    });

    _showMessage(
      'Elige un Pokémon del catálogo y pulsa '
      '«Agregar a equipo».',
    );
  }

  // Abre detalles y registra al Pokémon como visto.
  void _openPokemon(PokemonModel pokemon) {
    collectionStore.markSeen(pokemon.id).catchError((Object error) {
      if (mounted) {
        _showMessage('No se pudo guardar el Pokémon visto.');
      }
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return PokemonDetailScreen(
            pokemon: pokemon,
            apiService: apiService,
            onAddToTeam: _addPokemonToTeam,
            collectionStore: collectionStore,
          );
        },
      ),
    );
  }

  // ===================================================
  // NAVEGACIÓN PRINCIPAL
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: [
            // 0. POKÉDEX
            _buildPokedex(),

            // 1. EXPLORAR
            ExploreScreen(apiService: apiService, onOpenPokemon: _openPokemon),

            // 2. EQUIPOS
            TeamsScreen(
              store: teamStore,
              apiService: apiService,
              onAddPokemon: _goToPokedex,
            ),

            // 3. MI AVENTURA
            TrainerProfileScreen(
              store: collectionStore,
              apiService: apiService,
              onOpenPokemon: _openPokemon,
            ),
          ],
        ),
      ),

      bottomNavigationBar: NavigationBar(
        height: 76,
        selectedIndex: selectedTab,

        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
          });
        },

        // Colores adaptados al tema.
        backgroundColor: surfaceColor,

        indicatorColor: isDarkMode
            ? const Color(0xFF51313D)
            : const Color(0xFFFFE1E7),

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.catching_pokemon_outlined),
            selectedIcon: Icon(Icons.catching_pokemon),
            label: 'Pokédex',
          ),

          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorar',
          ),

          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Equipos',
          ),

          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Mi aventura',
          ),
        ],
      ),
    );
  }

  // ===================================================
  // POKÉDEX PRINCIPAL
  // ===================================================

  Widget _buildPokedex() {
    final query = searchQuery.trim().toLowerCase();

    // Filtrar Pokémon previamente cargados.
    final filtered = pokemons.where((pokemon) {
      final matchesSearch =
          pokemon.name.toLowerCase().contains(query) ||
          pokemon.id.toString() == query;

      final matchesType =
          selectedType == 'All' || pokemon.types.contains(selectedType);

      return matchesSearch && matchesType;
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1250),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            // Encabezado.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 26),

                    _buildWelcomeBanner(),

                    const SizedBox(height: 28),

                    const Text(
                      'Descubre Pokémon',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Explora, descubre y forma '
                      'tu equipo ideal.',
                      style: TextStyle(fontSize: 13, color: secondaryTextColor),
                    ),

                    const SizedBox(height: 20),

                    _buildSearchBar(),

                    const SizedBox(height: 22),

                    const Text(
                      'Explorar por tipo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Filtros.
            SliverToBoxAdapter(child: _buildTypeFilters()),

            // Encabezado de resultados.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
                child: Row(
                  children: [
                    const Text(
                      'Pokémon',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const Spacer(),

                    Flexible(
                      child: Text(
                        '${filtered.length} mostrados · '
                        '${pokemons.length} cargados',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tarjetas con carga diferida.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              sliver: SliverGrid.builder(
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 245,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 220,
                ),
                itemBuilder: (context, index) {
                  final pokemon = filtered[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      _openPokemon(pokemon);
                    },
                    child: PokemonCard(
                      key: ValueKey(pokemon.id),
                      pokemon: pokemon,
                    ),
                  );
                },
              ),
            ),

            // Sin resultados.
            if (filtered.isEmpty && !isLoading && errorMessage == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(35),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 55,
                        color: Color(0xFFB0B5BE),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'No hay coincidencias entre '
                        'los Pokémon cargados.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ),

            // Carga, errores y final.
            SliverToBoxAdapter(child: _buildLoadingFooter()),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // ENCABEZADO CON BOTÓN DE MODO OSCURO
  // ===================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFDC0A2D),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.catching_pokemon,
            size: 28,
            color: Colors.white,
          ),
        ),

        const SizedBox(width: 12),

        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PokéVerse',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),

            Text(
              'YOUR POKÉMON UNIVERSE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Color(0xFF9299A6),
              ),
            ),
          ],
        ),

        const Spacer(),

        // Botón de cambio de tema.
        IconButton.filledTonal(
          tooltip: isDarkMode ? 'Activar modo claro' : 'Activar modo oscuro',

          onPressed: () async {
            try {
              await widget.themeStore.toggleTheme();
            } catch (error) {
              _showMessage('No se pudo guardar la preferencia del tema.');
            }
          },

          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDarkMode),
            ),
          ),
        ),
      ],
    );
  }

  // ===================================================
  // BANNER DE BIENVENIDA
  // ===================================================

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC0A2D), Color(0xFFFF5365)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC0A2D).withValues(alpha: 0.17),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -35,
            child: Icon(
              Icons.catching_pokemon,
              size: 195,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Hola, entrenador!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 9),

                const Text(
                  'Tu próxima aventura Pokémon\n'
                  'comienza aquí.',
                  style: TextStyle(
                    color: Color(0xFFFFE9ED),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '¡Atrápalos a todos!',
                    style: TextStyle(
                      color: Color(0xFFDC0A2D),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // BUSCADOR DE LA POKÉDEX
  // ===================================================

  Widget _buildSearchBar() {
    return TextField(
      controller: searchController,

      // Texto adaptable al modo oscuro.
      style: TextStyle(color: inputTextColor),

      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },

      decoration: InputDecoration(
        hintText: 'Busca por nombre o número...',

        hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),

        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFDC0A2D)),

        suffixIcon: searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  searchController.clear();

                  setState(() {
                    searchQuery = '';
                  });
                },
              ),

        filled: true,

        // Fondo adaptable al modo oscuro.
        fillColor: surfaceColor,

        contentPadding: const EdgeInsets.symmetric(
          vertical: 17,
          horizontal: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ===================================================
  // FILTROS POR TIPO
  // ===================================================

  Widget _buildTypeFilters() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: types.length,

        separatorBuilder: (_, _) {
          return const SizedBox(width: 8);
        },

        itemBuilder: (context, index) {
          final type = types[index];
          final selected = selectedType == type;

          return ChoiceChip(
            label: Text(type == 'All' ? 'Todos' : capitalize(type)),

            selected: selected,
            showCheckmark: false,

            onSelected: (_) {
              setState(() {
                selectedType = type;
              });
            },

            // Fondo adaptable.
            backgroundColor: surfaceColor,

            selectedColor: const Color(0xFFDC0A2D),

            side: BorderSide.none,

            labelStyle: TextStyle(
              color: selected ? Colors.white : secondaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }

  // ===================================================
  // CARGA, REINTENTOS Y FINAL DEL CATÁLOGO
  // ===================================================

  Widget _buildLoadingFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          // Descargando Pokémon.
          if (isLoading)
            Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFFDC0A2D)),

                const SizedBox(height: 14),

                Text(
                  'Descubriendo más Pokémon...',
                  style: TextStyle(color: secondaryTextColor),
                ),
              ],
            ),

          // Error de conexión.
          if (errorMessage != null)
            Column(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 45,
                  color: Color(0xFFDC0A2D),
                ),

                const SizedBox(height: 12),

                Text(errorMessage!, textAlign: TextAlign.center),

                const SizedBox(height: 15),

                ElevatedButton.icon(
                  onPressed: _retryLoading,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),

          // Catálogo completo.
          if (!hasMore && !isLoading)
            Text(
              '¡Has explorado todos los Pokémon!',
              style: TextStyle(
                color: secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================
// TARJETAS DEL CATÁLOGO
// =====================================================

class PokemonCard extends StatelessWidget {
  final PokemonModel pokemon;

  const PokemonCard({super.key, required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final typeColor = pokemonTypeColor(
      pokemon.types.isNotEmpty ? pokemon.types.first : 'normal',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Color.lerp(const Color(0xFF202838), typeColor, 0.17)
            : typeColor.withValues(alpha: 0.17),

        borderRadius: BorderRadius.circular(22),
      ),

      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: 28,
            child: Icon(
              Icons.catching_pokemon,
              size: 130,
              color: typeColor.withValues(alpha: isDark ? 0.16 : 0.11),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número.
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '#${pokemon.id.toString().padLeft(4, '0')}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : typeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                // Ilustración con caché.
                Expanded(
                  child: Center(
                    child: Hero(
                      tag: 'pokemon-${pokemon.id}',
                      child: CachedNetworkImage(
                        imageUrl: pokemon.imageUrl,
                        fit: BoxFit.contain,

                        fadeInDuration: const Duration(milliseconds: 250),

                        placeholder: (context, url) {
                          return Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: typeColor,
                              ),
                            ),
                          );
                        },

                        errorWidget: (context, url, error) {
                          return Icon(
                            Icons.catching_pokemon,
                            size: 65,
                            color: typeColor,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Nombre.
                Text(
                  capitalize(pokemon.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                // Tipos.
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: pokemon.types.map((type) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),

                      decoration: BoxDecoration(
                        color: pokemonTypeColor(type),
                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Text(
                        capitalize(type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
