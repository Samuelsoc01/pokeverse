import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pokemon_model.dart';
import '../services/pokeapi_service.dart';
import '../services/explore_catalog_service.dart';

class PokemonQuizScreen extends StatefulWidget {
  final PokeApiService apiService;

  const PokemonQuizScreen({super.key, required this.apiService});

  @override
  State<PokemonQuizScreen> createState() => _PokemonQuizScreenState();
}

class _PokemonQuizScreenState extends State<PokemonQuizScreen> {
  static const int totalRounds = 10;
  static const Color red = Color(0xFFDC0A2D);

  final Random _random = Random();
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final ExploreCatalogService _catalog = ExploreCatalogService();

  final Set<int> _usedIds = {};

  List<PokemonIndexEntry> _options = [];
  List<PokemonIndexEntry> _pool = [];

  PokemonModel? _pokemon;

  int _difficulty = 0;
  int _round = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _record = 0;

  int? _selectedId;
  int _requestVersion = 0;

  bool _loading = false;
  bool _finished = false;
  bool _answered = false;
  bool _newRecord = false;

  String? _error;

  static const List<String> _difficultyNames = ['Fácil', 'Normal', 'Difícil'];

  static const List<int> _limits = [151, 493, 1025];

  static const List<int> _points = [100, 150, 200];

  bool get dark => Theme.of(context).brightness == Brightness.dark;

  Color get surface => Theme.of(context).colorScheme.surface;

  Color get foreground => Theme.of(context).colorScheme.onSurface;

  Color get muted => dark ? const Color(0xFFB7C0D0) : const Color(0xFF838B99);

  Color get accent => dark ? const Color(0xFFFF6679) : red;

  Color get quizBackground =>
      dark ? const Color(0xFF1D2940) : const Color(0xFF253148);

  Color get optionBackground => dark ? const Color(0xFF293345) : Colors.white;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

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

  // ===================================================
  // INICIAR PARTIDA Y LEER RÉCORD
  // ===================================================

  Future<void> _startGame([int? difficulty]) async {
    final version = ++_requestVersion;
    final nextDifficulty = difficulty ?? _difficulty;

    setState(() {
      _difficulty = nextDifficulty;
      _round = 0;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _record = 0;
      _selectedId = null;
      _pokemon = null;
      _options = [];
      _pool = [];
      _usedIds.clear();
      _answered = false;
      _finished = false;
      _newRecord = false;
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _catalog.getIndex(),
        _prefs.getInt('pokeverse_quiz_record_$nextDifficulty'),
      ]);

      if (!mounted || version != _requestVersion) {
        return;
      }

      final index = results[0] as List<PokemonIndexEntry>;

      final savedRecord = results[1] as int? ?? 0;

      final pool = index.where((entry) {
        return entry.id >= 1 && entry.id <= _limits[nextDifficulty];
      }).toList();

      if (pool.length < 4) {
        throw StateError('No hay suficientes Pokémon disponibles.');
      }

      _pool = pool;
      _record = savedRecord;

      await _nextRound(version);
    } catch (error) {
      if (!mounted || version != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'No pudimos preparar PokéChallenge.';
      });

      debugPrint('Error inicializando quiz: $error');
    }
  }

  // ===================================================
  // GENERAR PREGUNTA
  // ===================================================

  Future<void> _nextRound(int version) async {
    if (!mounted || version != _requestVersion) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _answered = false;
      _selectedId = null;
      _pokemon = null;
    });

    try {
      final available = _pool
          .where((item) => !_usedIds.contains(item.id))
          .toList();

      if (available.length < 4) {
        throw StateError('No hay más Pokémon disponibles.');
      }

      final correct = available[_random.nextInt(available.length)];

      final distractors = _pool.where((item) => item.id != correct.id).toList()
        ..shuffle(_random);

      final options = <PokemonIndexEntry>[correct, ...distractors.take(3)]
        ..shuffle(_random);

      final pokemon = await widget.apiService.getPokemon(correct.id);

      if (!mounted || version != _requestVersion) {
        return;
      }

      setState(() {
        _usedIds.add(correct.id);
        _options = options;
        _pokemon = pokemon;
        _round++;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'No pudimos cargar el siguiente Pokémon.';
      });

      debugPrint('Error de ronda: $error');
    }
  }

  // ===================================================
  // RESPONDER
  // ===================================================

  void _answer(int id) {
    if (_answered || _loading || _pokemon == null) {
      return;
    }

    final correct = id == _pokemon!.id;

    setState(() {
      _selectedId = id;
      _answered = true;

      if (correct) {
        _streak++;

        if (_streak > _bestStreak) {
          _bestStreak = _streak;
        }

        final bonus = _streak >= 3 ? 25 : 0;
        _score += _points[_difficulty] + bonus;
      } else {
        _streak = 0;
      }
    });
  }

  Future<void> _continueGame() async {
    if (_loading || !_answered) return;

    if (_round >= totalRounds) {
      await _finishGame();
    } else {
      await _nextRound(_requestVersion);
    }
  }

  // ===================================================
  // GUARDAR RÉCORD SIN CAMBIAR SU CLAVE
  // ===================================================

  Future<void> _finishGame() async {
    if (_finished) return;

    if (_score > _record) {
      try {
        await _prefs.setInt('pokeverse_quiz_record_$_difficulty', _score);

        if (!mounted) return;

        setState(() {
          _record = _score;
          _newRecord = true;
          _finished = true;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _finished = true;
          _error = 'No se pudo guardar el nuevo récord.';
        });
      }
    } else {
      setState(() {
        _finished = true;
      });
    }
  }

  // ===================================================
  // INTERFAZ PRINCIPAL
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PokéChallenge',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _difficultySelector(),
                const SizedBox(height: 18),

                if (_finished)
                  _results()
                else ...[
                  _scoreboard(),
                  const SizedBox(height: 18),
                  _mysteryCard(),
                  const SizedBox(height: 20),

                  if (!_loading && _error == null) _answers(),

                  if (_answered) ...[
                    const SizedBox(height: 18),
                    _feedback(),
                    const SizedBox(height: 18),

                    FilledButton.icon(
                      onPressed: _continueGame,
                      icon: Icon(
                        _round == totalRounds
                            ? Icons.emoji_events_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _round == totalRounds
                            ? 'Ver mis resultados'
                            : 'Siguiente Pokémon',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(17),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================
  // SELECCIÓN DE DIFICULTAD
  // ===================================================

  Widget _difficultySelector() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona tu dificultad',
            style: TextStyle(
              color: foreground,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(3, (index) {
              final selected = _difficulty == index;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 7 : 0),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        _difficultyNames[index],
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: dark ? const Color(0xFF873549) : red,
                    backgroundColor: dark
                        ? const Color(0xFF293345)
                        : const Color(0xFFF3F4F8),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : foreground,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: _loading
                        ? null
                        : (_) {
                            if (!_finished && _round > 1) {
                              _confirmRestart(index);
                            } else {
                              _startGame(index);
                            }
                          },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestart(int difficulty) async {
    final restart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Reiniciar partida?'),
        content: const Text(
          'Cambiar la dificultad reiniciará tus puntos '
          'y las rondas de esta partida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );

    if (restart == true && mounted) {
      _startGame(difficulty);
    }
  }

  // ===================================================
  // MARCADOR
  // ===================================================

  Widget _scoreboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: quizBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _scoreItem('RONDA', '$_round/$totalRounds', Icons.flag_rounded),
          _scoreItem('PUNTOS', '$_score', Icons.stars_rounded),
          _scoreItem('RACHA', '$_streak', Icons.local_fire_department),
        ],
      ),
    );
  }

  Widget _scoreItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFFD36A), size: 20),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  // ===================================================
  // SILUETA Y REVELACIÓN
  // ===================================================

  Widget _mysteryCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [const Color(0xFF273955), const Color(0xFF131C2C)]
              : [const Color(0xFF344566), const Color(0xFF171F35)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const Text(
            '¿QUIÉN ES ESE POKÉMON?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 245,
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _error != null
                  ? _errorContent()
                  : _pokemon == null
                  ? const SizedBox.shrink()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: _answered
                          ? CachedNetworkImage(
                              key: ValueKey('revealed-${_pokemon!.id}'),
                              imageUrl: _pokemon!.imageUrl,
                              height: 225,
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.catching_pokemon,
                                color: Colors.white,
                                size: 110,
                              ),
                            )
                          : ColorFiltered(
                              key: ValueKey('hidden-${_pokemon!.id}'),
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: _pokemon!.imageUrl,
                                height: 225,
                                fit: BoxFit.contain,
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.help_outline, size: 110),
                              ),
                            ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _answered && _pokemon != null
                ? _pretty(_pokemon!.name)
                : 'Pokémon misterioso',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige una de las cuatro respuestas',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _errorContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 44),
        const SizedBox(height: 10),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        TextButton(
          onPressed: () {
            if (_pool.isEmpty) {
              _startGame();
            } else {
              _nextRound(_requestVersion);
            }
          },
          child: const Text('Reintentar'),
        ),
      ],
    );
  }

  // ===================================================
  // OPCIONES DE RESPUESTA
  // ===================================================

  Widget _answers() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 67,
      ),
      itemBuilder: (context, index) {
        final option = _options[index];

        final isCorrect = _answered && option.id == _pokemon?.id;

        final isWrong = _answered && option.id == _selectedId && !isCorrect;

        final background = isCorrect
            ? (dark ? const Color(0xFF174735) : const Color(0xFFDCF8E9))
            : isWrong
            ? (dark ? const Color(0xFF632B3A) : const Color(0xFFFFE0E4))
            : optionBackground;

        final textColor = isCorrect
            ? (dark ? const Color(0xFF9EF1C2) : const Color(0xFF16864A))
            : isWrong
            ? (dark ? const Color(0xFFFFABB8) : const Color(0xFFCC2040))
            : foreground;

        return Material(
          color: background,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _answered ? null : () => _answer(option.id),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _pretty(option.name),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===================================================
  // RETROALIMENTACIÓN
  // ===================================================

  Widget _feedback() {
    final correct = _selectedId == _pokemon?.id;

    final background = correct
        ? (dark ? const Color(0xFF174735) : const Color(0xFFDCF8E9))
        : (dark ? const Color(0xFF632B3A) : const Color(0xFFFFE0E4));

    final textColor = correct
        ? (dark ? const Color(0xFF9EF1C2) : const Color(0xFF16864A))
        : (dark ? const Color(0xFFFFABB8) : const Color(0xFFCC2040));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: textColor,
            size: 29,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              correct
                  ? '¡Correcto! Excelente, entrenador.'
                  : 'Era ${_pretty(_pokemon!.name)}. '
                        '¡Inténtalo en la siguiente ronda!',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // RESULTADOS FINALES
  // ===================================================

  Widget _results() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFC44F),
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            '¡Partida terminada!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$_score',
            style: TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          Text(
            'PUNTOS TOTALES',
            style: TextStyle(color: muted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Mejor racha: $_bestStreak',
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Récord: $_record puntos',
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
          if (_newRecord) ...[
            const SizedBox(height: 14),
            const Chip(
              avatar: Icon(Icons.stars_rounded),
              label: Text('¡Nuevo récord personal!'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: accent),
            ),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startGame(),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Jugar otra vez'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
