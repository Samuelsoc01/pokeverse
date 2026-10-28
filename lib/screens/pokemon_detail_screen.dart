import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/pokemon_model.dart';
import '../services/pokeapi_service.dart';
import '../services/collection_store.dart';

// =====================================================
// COLORES DE LOS TIPOS POKÉMON
// =====================================================

const Map<String, Color> _typeColors = {
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

String _pretty(String value) {
  return value
      .split('-')
      .map((part) {
        if (part.isEmpty) return part;

        return '${part[0].toUpperCase()}'
            '${part.substring(1)}';
      })
      .join(' ');
}

// =====================================================
// PANTALLA DE DETALLES
// =====================================================

class PokemonDetailScreen extends StatefulWidget {
  final PokemonModel pokemon;
  final PokeApiService apiService;
  final CollectionStore collectionStore;

  final Future<void> Function(PokemonModel pokemon) onAddToTeam;

  const PokemonDetailScreen({
    super.key,
    required this.pokemon,
    required this.apiService,
    required this.collectionStore,
    required this.onAddToTeam,
  });

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final AudioPlayer _player;
  late Future<PokemonExtra> _extraFuture;

  bool _shiny = false;
  bool _playing = false;

  bool _savingFavorite = false;
  bool _savingCaught = false;

  PokemonModel get pokemon => widget.pokemon;

  // ===================================================
  // SISTEMA DE COLORES ADAPTATIVOS
  // ===================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _text => Theme.of(context).colorScheme.onSurface;

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB7C0D0) : const Color(0xFF667085);

  Color get _subtleSurface =>
      _isDark ? const Color(0xFF293345) : const Color(0xFFF5F6FA);

  Color get accent {
    final type = pokemon.types.isNotEmpty ? pokemon.types.first : 'normal';

    return _typeColors[type] ?? const Color(0xFF78909C);
  }

  Color get _actionColor => _isDark
      ? Color.lerp(accent, Colors.white, 0.22)!
      : Color.lerp(accent, Colors.black, 0.14)!;

  String get artwork => _shiny ? pokemon.shinyUrl : pokemon.imageUrl;

  // ===================================================
  // INICIALIZACIÓN
  // ===================================================

  @override
  void initState() {
    super.initState();

    _tabs = TabController(length: 3, vsync: this);

    _player = AudioPlayer();

    _extraFuture = widget.apiService.getPokemonExtra(pokemon.id);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _player.dispose();
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ===================================================
  // SONIDO DEL POKÉMON
  // ===================================================

  Future<void> _playCry() async {
    final url = pokemon.cryUrl;

    if (url == null || url.isEmpty) {
      _notify('Este Pokémon no tiene sonido disponible.');
      return;
    }

    if (_playing) return;

    setState(() => _playing = true);

    try {
      await _player.stop();
      await _player.setUrl(url);
      await _player.play();
    } catch (error) {
      _notify('No se pudo reproducir el sonido.');
    } finally {
      if (mounted) {
        setState(() => _playing = false);
      }
    }
  }

  // ===================================================
  // FAVORITOS Y CAPTURAS
  // ===================================================

  Future<void> _toggleFavorite() async {
    if (_savingFavorite || widget.collectionStore.isLoading) {
      return;
    }

    setState(() => _savingFavorite = true);

    try {
      await widget.collectionStore.toggleFavorite(pokemon.id);
    } catch (error) {
      _notify('No se pudo guardar el favorito.');
    } finally {
      if (mounted) {
        setState(() => _savingFavorite = false);
      }
    }
  }

  Future<void> _toggleCaught() async {
    if (_savingCaught || widget.collectionStore.isLoading) {
      return;
    }

    setState(() => _savingCaught = true);

    try {
      await widget.collectionStore.toggleCaught(pokemon.id);
    } catch (error) {
      _notify('No se pudo guardar la captura.');
    } finally {
      if (mounted) {
        setState(() => _savingCaught = false);
      }
    }
  }

  // ===================================================
  // ESTRUCTURA DE LA PANTALLA
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _heroHeader()),

                      SliverToBoxAdapter(child: _tabsHeader()),

                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: TabBarView(
                          controller: _tabs,
                          children: [_aboutTab(), _statsTab(), _evolutionTab()],
                        ),
                      ),
                    ],
                  ),
                ),

                _bottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================
  // ENCABEZADO DEL POKÉMON
  // ===================================================

  Widget _heroHeader() {
    final topColor = Color.lerp(accent, Colors.black, _isDark ? 0.45 : 0.20)!;

    final bottomColor = Color.lerp(
      accent,
      Colors.black,
      _isDark ? 0.70 : 0.40,
    )!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [topColor, bottomColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -55,
            top: 75,
            child: Icon(
              Icons.catching_pokemon,
              size: 310,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              children: [
                // Barra superior.
                Row(
                  children: [
                    _circleButton(
                      Icons.arrow_back_rounded,
                      () => Navigator.pop(context),
                    ),

                    const Spacer(),

                    const Text(
                      'POKÉMON PROFILE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const Spacer(),

                    _circleButton(
                      Icons.volume_up_rounded,
                      _playing ? null : _playCry,
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Nombre, número y shiny.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pretty(pokemon.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 31,
                              height: 1.1,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            '#${pokemon.id.toString().padLeft(4, '0')}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _shiny = !_shiny;
                        });
                      },
                      icon: Icon(
                        _shiny ? Icons.auto_awesome : Icons.star_outline,
                        size: 18,
                      ),
                      label: const Text('Shiny'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Tipos.
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: pokemon.types.map((type) {
                    final typeColor =
                        _typeColors[type] ?? const Color(0xFF78909C);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        // Usamos el color real del tipo Pokémon.
                        color: Color.lerp(typeColor, Colors.black, 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        _pretty(type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 5),

                // Ilustración.
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Center(
                    child: Hero(
                      tag: 'pokemon-${pokemon.id}',
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: CachedNetworkImage(
                          key: ValueKey(artwork),
                          imageUrl: artwork,
                          height: 215,
                          fit: BoxFit.contain,
                          fadeInDuration: const Duration(milliseconds: 250),
                          placeholder: (context, url) => const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.catching_pokemon,
                            color: Colors.white,
                            size: 125,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.19),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _shiny ? '✨ SHINY EDITION' : 'ORIGINAL EDITION',
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: Colors.white,
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

  Widget _circleButton(IconData icon, VoidCallback? action) {
    return Material(
      color: Colors.white.withValues(alpha: 0.20),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: action,
        color: Colors.white,
        icon: Icon(icon),
      ),
    );
  }

  // ===================================================
  // PESTAÑAS: ACERCA DE, STATS, EVOLUCIÓN
  // ===================================================

  Widget _tabsHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: _isDark ? Border.all(color: const Color(0xFF354154)) : null,
      ),
      child: TabBar(
        controller: _tabs,
        labelColor: _actionColor,
        unselectedLabelColor: _secondaryText,
        indicatorColor: _actionColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        tabs: const [
          Tab(text: 'Acerca de'),
          Tab(text: 'Stats'),
          Tab(text: 'Evolución'),
        ],
      ),
    );
  }

  // ===================================================
  // PESTAÑA: ACERCA DE
  // ===================================================

  Widget _aboutTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _sectionCard(
          title: 'Acerca de este Pokémon',
          child: FutureBuilder<PokemonExtra>(
            future: _extraFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return LinearProgressIndicator(color: _actionColor);
              }

              if (snapshot.hasError) {
                return _retryExtra();
              }

              return Text(
                snapshot.data?.description ?? 'Sin descripción disponible.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: _secondaryText,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        _sectionCard(
          title: 'Características',
          child: Row(
            children: [
              Expanded(
                child: _measurement(
                  Icons.height_rounded,
                  'Altura',
                  '${pokemon.heightMeters.toStringAsFixed(1)} m',
                ),
              ),

              Container(
                height: 55,
                width: 1,
                color: _isDark
                    ? const Color(0xFF394457)
                    : const Color(0xFFE6E8EF),
              ),

              Expanded(
                child: _measurement(
                  Icons.monitor_weight_outlined,
                  'Peso',
                  '${pokemon.weightKg.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _sectionCard(
          title: 'Habilidades',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pokemon.abilities.map((ability) {
              return Chip(
                label: Text(_pretty(ability)),
                backgroundColor: _isDark
                    ? _subtleSurface
                    : accent.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: _isDark
                      ? _text
                      : Color.lerp(accent, Colors.black, 0.35),
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _measurement(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, color: _actionColor, size: 27),

        const SizedBox(height: 7),

        Text(
          value,
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),

        Text(title, style: TextStyle(color: _secondaryText)),
      ],
    );
  }

  // ===================================================
  // PESTAÑA: ESTADÍSTICAS
  // ===================================================

  Widget _statsTab() {
    const labels = {
      'hp': 'HP',
      'attack': 'Ataque',
      'defense': 'Defensa',
      'special-attack': 'Ataque Esp.',
      'special-defense': 'Defensa Esp.',
      'speed': 'Velocidad',
    };

    final total = pokemon.stats.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _sectionCard(
          title: 'Estadísticas base',
          child: Column(
            children: [
              for (final item in labels.entries)
                _statBar(item.value, pokemon.stats[item.key] ?? 0),

              const Divider(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),

                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: _actionColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _sectionCard(
          title: '¿Qué significan?',
          child: Text(
            'Estas son las estadísticas base de la especie. '
            'Los atributos de un Pokémon concreto también '
            'dependen de otros factores del videojuego.',
            style: TextStyle(height: 1.6, color: _secondaryText),
          ),
        ),
      ],
    );
  }

  Widget _statBar(String name, int value) {
    final fraction = (value / 200).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            child: Text(
              name,
              style: TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SizedBox(
            width: 38,
            child: Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _actionColor,
              ),
            ),
          ),

          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) {
                return LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(12),
                  color: _actionColor,
                  backgroundColor: _isDark
                      ? const Color(0xFF394457)
                      : accent.withValues(alpha: 0.13),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // PESTAÑA: EVOLUCIONES
  // ===================================================

  Widget _evolutionTab() {
    return FutureBuilder<PokemonExtra>(
      future: _extraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: _actionColor));
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [_retryExtra()],
          );
        }

        final stages = snapshot.data?.evolutions ?? [];

        if (stages.isEmpty) {
          return Center(
            child: Text(
              'No hay información evolutiva.',
              style: TextStyle(color: _secondaryText),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _sectionCard(
              title: 'Cadena evolutiva',
              child: Column(
                children: [
                  Text(
                    'Las ramificaciones se identifican '
                    'por etapa.',
                    style: TextStyle(fontSize: 12, color: _secondaryText),
                  ),

                  const SizedBox(height: 14),

                  for (final stage in stages) _evolutionTile(stage),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _evolutionTile(EvolutionStage stage) {
    final current = stage.id == pokemon.id;

    final currentBackground = _isDark
        ? Color.lerp(_subtleSurface, accent, 0.18)!
        : accent.withValues(alpha: 0.13);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: current ? currentBackground : _subtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: current
            ? Border.all(color: accent.withValues(alpha: 0.5))
            : Border.all(
                color: _isDark ? const Color(0xFF354154) : Colors.transparent,
              ),
      ),
      child: Row(
        children: [
          // Sangría para representar la profundidad.
          SizedBox(width: stage.depth * 16.0),

          if (stage.depth > 0)
            Icon(
              Icons.subdirectory_arrow_right_rounded,
              color: _actionColor,
              size: 22,
            ),

          CachedNetworkImage(
            imageUrl: stage.imageUrl,
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(
              width: 72,
              height: 72,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) =>
                Icon(Icons.catching_pokemon, size: 48, color: _actionColor),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pretty(stage.name),
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '#${stage.id.toString().padLeft(4, '0')} · '
                  'Etapa ${stage.depth + 1}',
                  style: TextStyle(fontSize: 12, color: _secondaryText),
                ),
              ],
            ),
          ),

          if (current) Icon(Icons.check_circle_rounded, color: _actionColor),
        ],
      ),
    );
  }

  // ===================================================
  // REINTENTAR INFORMACIÓN ADICIONAL
  // ===================================================

  Widget _retryExtra() {
    return Column(
      children: [
        Text(
          'No se pudo cargar la información adicional.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _secondaryText),
        ),

        const SizedBox(height: 8),

        TextButton.icon(
          onPressed: () {
            setState(() {
              _extraFuture = widget.apiService.getPokemonExtra(pokemon.id);
            });
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }

  // ===================================================
  // TARJETAS DE INFORMACIÓN
  // ===================================================

  Widget _sectionCard({required String title, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isDark ? const Color(0xFF354154) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black.withValues(alpha: _isDark ? 0.10 : 0.025),
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 15),

          child,
        ],
      ),
    );
  }

  // ===================================================
  // ACCIONES INFERIORES
  // ===================================================

  Widget _bottomActions() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(
            color: _isDark ? const Color(0xFF354154) : const Color(0xFFEBEDF2),
          ),
        ),
      ),
      child: Row(
        children: [
          // AGREGAR A EQUIPO.
          Expanded(
            child: FilledButton.icon(
              onPressed: () => widget.onAddToTeam(pokemon),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                'Agregar a equipo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _actionColor,
                foregroundColor: _isDark
                    ? const Color(0xFF171F2C)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 10,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // FAVORITOS.
          AnimatedBuilder(
            animation: widget.collectionStore,
            builder: (context, _) {
              final isFavorite = widget.collectionStore.isFavorite(pokemon.id);

              return IconButton.filledTonal(
                tooltip: isFavorite
                    ? 'Quitar de favoritos'
                    : 'Agregar a favoritos',
                onPressed: _savingFavorite || widget.collectionStore.isLoading
                    ? null
                    : _toggleFavorite,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(isFavorite),
                    color: isFavorite
                        ? (_isDark
                              ? const Color(0xFFFF7E94)
                              : const Color(0xFFDC0A2D))
                        : null,
                  ),
                ),
              );
            },
          ),

          // CAPTURADOS.
          AnimatedBuilder(
            animation: widget.collectionStore,
            builder: (context, _) {
              final isCaught = widget.collectionStore.isCaught(pokemon.id);

              return IconButton.filledTonal(
                tooltip: isCaught
                    ? 'Desmarcar captura'
                    : 'Marcar como capturado',
                onPressed: _savingCaught || widget.collectionStore.isLoading
                    ? null
                    : _toggleCaught,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    isCaught
                        ? Icons.check_circle
                        : Icons.catching_pokemon_outlined,
                    key: ValueKey(isCaught),
                    color: isCaught ? const Color(0xFF37B877) : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
