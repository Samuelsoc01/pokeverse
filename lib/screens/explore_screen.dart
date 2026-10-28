import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/pokemon_model.dart';
import '../services/explore_catalog_service.dart';
import '../services/pokeapi_service.dart';

// =====================================================
// PANTALLA EXPLORAR
// =====================================================

class ExploreScreen extends StatefulWidget {
  final PokeApiService apiService;
  final ValueChanged<PokemonModel> onOpenPokemon;

  const ExploreScreen({
    super.key,
    required this.apiService,
    required this.onOpenPokemon,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ExploreCatalogService _catalog = ExploreCatalogService();

  final TextEditingController _search = TextEditingController();

  final ScrollController _scroll = ScrollController();

  Timer? _debounce;

  static const int _pageSize = 16;

  static const Color _red = Color(0xFFDC0A2D);

  static const List<String> _types = [
    'Todos',
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

  static const Map<String, Color> _typeColors = {
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

  String _query = '';
  String _type = 'Todos';
  int _generation = 0;

  List<PokemonIndexEntry> _matches = [];
  final List<PokemonModel> _visible = [];

  int _next = 0;
  int _revision = 0;

  bool _filtering = true;
  bool _loadingPage = false;

  String? _error;

  // ===================================================
  // COLORES DINÁMICOS
  // ===================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _text => Theme.of(context).colorScheme.onSurface;

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB7C0D0) : const Color(0xFF7B8492);

  Color get _accent => _isDark ? const Color(0xFFFF6679) : _red;

  Color get _chipBackground => _isDark ? const Color(0xFF293345) : Colors.white;

  // ===================================================
  // INICIALIZACIÓN
  // ===================================================

  @override
  void initState() {
    super.initState();

    _scroll.addListener(_onScroll);
    _applyFilters();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();

    super.dispose();
  }

  // ===================================================
  // SCROLL INFINITO
  // ===================================================

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 550) {
      _loadPage();
    }
  }

  // ===================================================
  // BÚSQUEDA CON DEBOUNCE
  // ===================================================

  void _updateQuery(String input) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = input.trim().toLowerCase();
      _applyFilters();
    });
  }

  // ===================================================
  // FILTROS GLOBALES
  // ===================================================

  Future<void> _applyFilters() async {
    _debounce?.cancel();

    _query = _search.text.trim().toLowerCase();

    final revision = ++_revision;

    setState(() {
      _filtering = true;
      _loadingPage = false;
      _error = null;

      _matches = [];
      _visible.clear();
      _next = 0;
    });

    try {
      final indexFuture = _catalog.getIndex();

      final Future<Set<int>?> typeFuture = _type == 'Todos'
          ? Future<Set<int>?>.value(null)
          : _catalog.getTypeIds(_type);

      final Future<Set<int>?> generationFuture = _generation == 0
          ? Future<Set<int>?>.value(null)
          : _catalog.getGenerationIds(_generation);

      final index = await indexFuture;
      final typeIds = await typeFuture;
      final generationIds = await generationFuture;

      if (!mounted || revision != _revision) {
        return;
      }

      final matches = index.where((item) {
        final matchesSearch =
            item.name.contains(_query) ||
            item.id.toString() == _query ||
            item.id.toString().padLeft(4, '0') == _query;

        final matchesType = typeIds == null || typeIds.contains(item.id);

        final matchesGeneration =
            generationIds == null || generationIds.contains(item.id);

        return matchesSearch && matchesType && matchesGeneration;
      }).toList();

      setState(() {
        _matches = matches;
        _filtering = false;
      });

      _loadPage();
    } catch (error) {
      if (!mounted || revision != _revision) {
        return;
      }

      setState(() {
        _filtering = false;
        _error = 'No se pudieron consultar los filtros.';
      });

      debugPrint('Error de filtros: $error');
    }
  }

  // ===================================================
  // PAGINACIÓN
  // ===================================================

  Future<void> _loadPage() async {
    if (_filtering ||
        _loadingPage ||
        _error != null ||
        _next >= _matches.length) {
      return;
    }

    final revision = _revision;
    final start = _next;

    final end = start + _pageSize < _matches.length
        ? start + _pageSize
        : _matches.length;

    setState(() {
      _loadingPage = true;
    });

    try {
      final results = <PokemonModel>[];

      for (int i = start; i < end; i += 4) {
        final chunkEnd = i + 4 < end ? i + 4 : end;

        final chunk = await Future.wait(
          _matches
              .sublist(i, chunkEnd)
              .map((entry) => widget.apiService.getPokemon(entry.id)),
        );

        if (!mounted || revision != _revision) {
          return;
        }

        results.addAll(chunk);
      }

      if (!mounted || revision != _revision) {
        return;
      }

      setState(() {
        _visible.addAll(results);
        _next = end;
        _loadingPage = false;
      });

      // Permite continuar cargando cuando todavía
      // no existe suficiente contenido para deslizar.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            revision == _revision &&
            _scroll.hasClients &&
            _scroll.position.extentAfter < 550) {
          _loadPage();
        }
      });
    } catch (error) {
      if (!mounted || revision != _revision) {
        return;
      }

      setState(() {
        _loadingPage = false;
        _error = 'Hubo un problema al cargar esta página.';
      });

      debugPrint('Error cargando resultados: $error');
    }
  }

  // ===================================================
  // REINTENTAR Y RESTABLECER
  // ===================================================

  void _retry() {
    setState(() {
      _error = null;
    });

    if (_matches.isEmpty) {
      _applyFilters();
    } else {
      _loadPage();
    }
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();

    _query = '';
    _type = 'Todos';
    _generation = 0;

    _applyFilters();
  }

  String _pretty(String value) {
    return value
        .split('-')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
        )
        .join(' ');
  }

  // ===================================================
  // ESTRUCTURA PRINCIPAL
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _filterHeader()),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Resultados',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: _text,
                        ),
                      ),
                    ),

                    Text(
                      _filtering
                          ? 'Buscando...'
                          : '${_matches.length} encontrados · '
                                '${_visible.length} visibles',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: _secondaryText),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.builder(
                itemCount: _visible.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 215,
                  mainAxisSpacing: 13,
                  crossAxisSpacing: 13,
                ),
                itemBuilder: (context, index) {
                  return _pokemonCard(_visible[index]);
                },
              ),
            ),

            SliverToBoxAdapter(child: _footer()),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // ENCABEZADO Y BUSCADOR
  // ===================================================

  Widget _filterHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explora el universo',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Encuentra cualquier Pokémon por nombre, '
            'tipo o generación.',
            style: TextStyle(color: _secondaryText, fontSize: 13),
          ),

          const SizedBox(height: 20),

          // Buscador adaptable al tema.
          TextField(
            controller: _search,
            onChanged: _updateQuery,
            style: TextStyle(color: _text),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: _accent),
              hintText: 'Ej. Garchomp, Pikachu o 445',
              hintStyle: TextStyle(color: _secondaryText),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                tooltip: 'Limpiar búsqueda',
                onPressed: _reset,
                icon: Icon(Icons.close, color: _secondaryText),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Tipo de Pokémon',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),

          const SizedBox(height: 10),

          _typeSelector(),

          const SizedBox(height: 18),

          _generationSelector(),
        ],
      ),
    );
  }

  // ===================================================
  // SELECTOR DE TIPOS
  // ===================================================

  Widget _typeSelector() {
    return SizedBox(
      height: 43,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _types.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = _types[index];
          final selected = _type == value;

          final typeColor = _typeColors[value];

          return ChoiceChip(
            showCheckmark: false,
            label: Text(value == 'Todos' ? value : _pretty(value)),
            selected: selected,
            selectedColor: _isDark ? const Color(0xFF963447) : _red,
            backgroundColor: _chipBackground,
            side: BorderSide(
              color: selected
                  ? Colors.transparent
                  : _isDark
                  ? const Color(0xFF3A475A)
                  : Colors.transparent,
            ),
            avatar: value == 'Todos'
                ? null
                : CircleAvatar(
                    radius: 5,
                    backgroundColor: typeColor ?? _accent,
                  ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _text,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) {
              _type = value;
              _applyFilters();
            },
          );
        },
      ),
    );
  }

  // ===================================================
  // SELECTOR DE GENERACIÓN
  // ===================================================

  Widget _generationSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _isDark ? const Color(0xFF354154) : const Color(0xFFE9EBF1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: _accent),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Generación',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _text,
              ),
            ),
          ),

          DropdownButton<int>(
            value: _generation,
            dropdownColor: _surface,
            style: TextStyle(
              color: _text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Todas')),
              for (int i = 1; i <= 9; i++)
                DropdownMenuItem(value: i, child: Text('Gen $i')),
            ],
            onChanged: (value) {
              if (value == null) return;

              _generation = value;
              _applyFilters();
            },
          ),

          TextButton(
            onPressed: _reset,
            style: TextButton.styleFrom(foregroundColor: _accent),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // TARJETAS POKÉMON
  // ===================================================

  Widget _pokemonCard(PokemonModel pokemon) {
    final color =
        _typeColors[pokemon.types.isEmpty ? 'normal' : pokemon.types.first] ??
        const Color(0xFF919AA2);

    final background = _isDark
        ? Color.lerp(const Color(0xFF202838), color, 0.17)!
        : color.withValues(alpha: 0.17);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onOpenPokemon(pokemon),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '#${pokemon.id.toString().padLeft(4, '0')}',
                  style: TextStyle(
                    color: _isDark ? Colors.white70 : color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: pokemon.imageUrl,
                    fit: BoxFit.contain,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (context, url) => Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.catching_pokemon, size: 62, color: color),
                  ),
                ),
              ),

              Text(
                _pretty(pokemon.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 7),

              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final type in pokemon.types)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _typeColors[type] ?? color,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        _pretty(type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================================================
  // PIE DE RESULTADOS
  // ===================================================

  Widget _footer() {
    if (_filtering || _loadingPage) {
      return Padding(
        padding: const EdgeInsets.all(35),
        child: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, size: 44, color: _accent),

            const SizedBox(height: 10),

            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: _text),
            ),

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(35),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, color: _secondaryText, size: 50),

              const SizedBox(height: 12),

              Text(
                'No hay Pokémon con esos filtros.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    if (_next >= _matches.length) {
      return Padding(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: Text(
            '¡Has visto todos los resultados!',
            style: TextStyle(
              color: _secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadPage,
          icon: const Icon(Icons.expand_more),
          label: const Text('Cargar más'),
        ),
      ),
    );
  }
}
