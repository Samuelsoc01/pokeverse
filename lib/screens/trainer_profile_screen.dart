import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/pokemon_model.dart';
import '../services/pokeapi_service.dart';
import '../services/collection_store.dart';
import 'pokemon_quiz_screen.dart';

class TrainerProfileScreen extends StatefulWidget {
  final CollectionStore store;
  final PokeApiService apiService;
  final ValueChanged<PokemonModel> onOpenPokemon;

  const TrainerProfileScreen({
    super.key,
    required this.store,
    required this.apiService,
    required this.onOpenPokemon,
  });

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  static const red = Color(0xFFDC0A2D);

  int selected = 0;

  final Map<int, Future<PokemonModel>> _requests = {};

  bool get dark => Theme.of(context).brightness == Brightness.dark;

  Color get surface => Theme.of(context).colorScheme.surface;

  Color get foreground => Theme.of(context).colorScheme.onSurface;

  Color get muted => dark ? const Color(0xFFB7C0D0) : const Color(0xFF838B99);

  Color get accent => dark ? const Color(0xFFFF6679) : red;

  Future<PokemonModel> _get(int id) {
    return _requests.putIfAbsent(id, () => widget.apiService.getPokemon(id));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;

        if (store.isLoading) {
          return Center(child: CircularProgressIndicator(color: accent));
        }

        if (store.error != null) {
          return Center(child: Text(store.error!));
        }

        final ids =
            (selected == 0
                    ? store.favorites
                    : selected == 1
                    ? store.seen
                    : store.caught)
                .toList()
              ..sort();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(store)),

                SliverToBoxAdapter(child: _gameBanner()),

                SliverToBoxAdapter(child: _tabs()),

                if (ids.isEmpty)
                  SliverToBoxAdapter(child: _empty())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                    sliver: SliverGrid.builder(
                      itemCount: ids.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230,
                            mainAxisExtent: 205,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemBuilder: (context, index) => _card(ids[index]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================================================
  // PANEL DEL ENTRENADOR
  // ===================================================

  Widget _header(CollectionStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi aventura',
            style: TextStyle(
              color: foreground,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Tu colección personal de Pokémon',
            style: TextStyle(color: muted),
          ),

          const SizedBox(height: 20),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF79172D), const Color(0xFF42263F)]
                    : [red, const Color(0xFFFE6A75)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.catching_pokemon, color: Colors.white, size: 25),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ENTRENADOR POKÉVERSE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Wrap(
                  spacing: 28,
                  runSpacing: 16,
                  children: [
                    _counter('Favoritos', store.favorites.length),
                    _counter('Vistos', store.seen.length),
                    _counter('Capturados', store.caught.length),
                  ],
                ),

                const SizedBox(height: 22),

                const Text(
                  'Progreso de descubrimiento',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 9),

                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    // Primera meta personal de 100 vistos.
                    value: (store.seen.length / 100).clamp(0.0, 1.0),
                    minHeight: 11,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  '${store.seen.length}/100 vistos · '
                  'Primer objetivo',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),

          if (store.caught.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF3C475A)
                      : const Color(0xFFE8EAF0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFBD47),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Insignia de primera captura '
                      'desbloqueada!',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _counter(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  // ===================================================
  // TARJETA DE POKÉCHALLENGE
  // ===================================================

  Widget _gameBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Material(
        color: dark ? const Color(0xFF303C57) : const Color(0xFF253148),
        borderRadius: BorderRadius.circular(23),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PokemonQuizScreen(apiService: widget.apiService),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: const Icon(
                    Icons.gamepad_rounded,
                    size: 36,
                    color: Color(0xFFFFD36A),
                  ),
                ),

                const SizedBox(width: 17),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POKÉCHALLENGE',
                        style: TextStyle(
                          color: Color(0xFFFFD36A),
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '¿Quién es ese Pokémon?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '10 rondas, 3 dificultades. '
                        '¡Demuestra cuánto sabes!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================
  // SELECTOR DE COLECCIÓN
  // ===================================================

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Favoritos'),
            icon: Icon(Icons.favorite),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Vistos'),
            icon: Icon(Icons.visibility),
          ),
          ButtonSegment(
            value: 2,
            label: Text('Capturados'),
            icon: Icon(Icons.catching_pokemon),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return dark ? Colors.white : const Color(0xFF761529);
            }
            return foreground;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return dark ? const Color(0xFF713348) : const Color(0xFFFFE0E7);
            }
            return surface;
          }),
        ),
        onSelectionChanged: (value) {
          setState(() {
            selected = value.first;
          });
        },
      ),
    );
  }

  // ===================================================
  // ESTADO VACÍO
  // ===================================================

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            selected == 0
                ? Icons.favorite_border
                : selected == 1
                ? Icons.visibility_outlined
                : Icons.catching_pokemon,
            size: 65,
            color: accent,
          ),

          const SizedBox(height: 15),

          Text(
            selected == 0
                ? 'Aún no tienes favoritos'
                : selected == 1
                ? 'Todavía no has visto Pokémon'
                : 'Todavía no has marcado capturas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Abre un Pokémon desde Pokédex o '
            'Explorar para comenzar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // TARJETAS DE LA COLECCIÓN
  // ===================================================

  Widget _card(int id) {
    return FutureBuilder<PokemonModel>(
      future: _get(id),
      builder: (context, snapshot) {
        final pokemon = snapshot.data;

        final background = dark
            ? const Color(0xFF293345)
            : const Color(0xFFFFE9EE);

        return Material(
          color: background,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: pokemon == null ? null : () => widget.onOpenPokemon(pokemon),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: snapshot.hasError
                  ? Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _requests.remove(id);
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    )
                  : pokemon == null
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Text(
                            '#${id.toString().padLeft(4, '0')}',
                            style: TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: pokemon.imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, _) => Center(
                              child: CircularProgressIndicator(
                                color: accent,
                                strokeWidth: 2,
                              ),
                            ),
                            errorWidget: (_, _, _) => Icon(
                              Icons.catching_pokemon,
                              size: 55,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          pokemon.name.isEmpty
                              ? 'Pokémon'
                              : pokemon.name[0].toUpperCase() +
                                    pokemon.name.substring(1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
