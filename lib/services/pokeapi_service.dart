import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../models/pokemon_model.dart';

class PokeApiService {
  static const int maxCacheEntries = 300;
  static const int maxSpeciesEntries = 150;
  static const int maxConcurrentRequests = 5;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pokeapi.co/api/v2/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  // Caché LRU: conserva elementos consultados recientemente.
  final LinkedHashMap<int, PokemonModel> _pokemonCache =
      LinkedHashMap<int, PokemonModel>();

  final LinkedHashMap<int, Map<String, dynamic>> _speciesCache =
      LinkedHashMap<int, Map<String, dynamic>>();

  final LinkedHashMap<String, List<EvolutionStage>> _evolutionCache =
      LinkedHashMap<String, List<EvolutionStage>>();

  // Solicitudes en curso para evitar duplicados.
  final Map<int, Future<PokemonModel>> _pendingPokemon = {};
  final Map<int, Future<Map<String, dynamic>>> _pendingSpecies = {};
  final Map<String, Future<List<EvolutionStage>>> _pendingEvolution = {};

  int _networkRequests = 0;
  int _cacheHits = 0;

  int get networkRequests => _networkRequests;
  int get cacheHits => _cacheHits;
  int get cachedPokemonCount => _pokemonCache.length;

  // ===================================================
  // PETICIONES CON REINTENTOS LIMITADOS
  // ===================================================

  Future<Response<dynamic>> _request(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _networkRequests++;

        return await _dio.get(url, queryParameters: queryParameters);
      } on DioException catch (error) {
        final status = error.response?.statusCode;

        // No repetimos errores permanentes como 404.
        final retryable = status == null || status == 429 || status >= 500;

        if (!retryable || attempt == maxAttempts) {
          rethrow;
        }

        // Espera progresiva antes de reintentar.
        await Future.delayed(Duration(milliseconds: 450 * attempt));
      }
    }

    throw StateError('No fue posible completar la petición.');
  }

  // ===================================================
  // CACHÉ DE POKÉMON
  // ===================================================

  PokemonModel? _readPokemonCache(int id) {
    final pokemon = _pokemonCache.remove(id);

    if (pokemon != null) {
      _cacheHits++;
      _pokemonCache[id] = pokemon;
    }

    return pokemon;
  }

  void _savePokemonCache(PokemonModel pokemon) {
    _pokemonCache.remove(pokemon.id);
    _pokemonCache[pokemon.id] = pokemon;

    while (_pokemonCache.length > maxCacheEntries) {
      _pokemonCache.remove(_pokemonCache.keys.first);
    }
  }

  Future<PokemonModel> getPokemon(int id) {
    final cached = _readPokemonCache(id);

    if (cached != null) {
      return Future.value(cached);
    }

    final pending = _pendingPokemon[id];

    if (pending != null) {
      return pending;
    }

    final request = _fetchPokemon(id);
    _pendingPokemon[id] = request;

    return request.whenComplete(() {
      _pendingPokemon.remove(id);
    });
  }

  Future<PokemonModel> _fetchPokemon(int id) async {
    final response = await _request('pokemon/$id/');

    final pokemon = PokemonModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );

    _savePokemonCache(pokemon);

    return pokemon;
  }

  // ===================================================
  // PAGINACIÓN CON CONCURRENCIA CONTROLADA
  // ===================================================

  Future<List<PokemonModel>> getPokemonPage({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _request(
      'pokemon/',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    final results = response.data['results'] as List;

    final ids = results.map<int>((item) {
      final url = item['url'] as String;

      final segments = Uri.parse(url).pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();

      return int.parse(segments.last);
    }).toList();

    final allPokemon = <PokemonModel>[];

    // Descargamos lotes de máximo cinco Pokémon.
    for (int start = 0; start < ids.length; start += maxConcurrentRequests) {
      final end = (start + maxConcurrentRequests).clamp(0, ids.length);

      final batch = ids.sublist(start, end);

      final pokemonBatch = await Future.wait(batch.map((id) => getPokemon(id)));

      allPokemon.addAll(pokemonBatch);
    }

    return allPokemon;
  }

  // ===================================================
  // INFORMACIÓN DE ESPECIES
  // ===================================================

  Future<Map<String, dynamic>> getSpecies(int id) {
    final cached = _speciesCache.remove(id);

    if (cached != null) {
      _cacheHits++;
      _speciesCache[id] = cached;
      return Future.value(cached);
    }

    final pending = _pendingSpecies[id];

    if (pending != null) {
      return pending;
    }

    final request = _fetchSpecies(id);
    _pendingSpecies[id] = request;

    return request.whenComplete(() {
      _pendingSpecies.remove(id);
    });
  }

  Future<Map<String, dynamic>> _fetchSpecies(int id) async {
    final response = await _request('pokemon-species/$id/');

    final data = Map<String, dynamic>.from(response.data as Map);

    _speciesCache[id] = data;

    while (_speciesCache.length > maxSpeciesEntries) {
      _speciesCache.remove(_speciesCache.keys.first);
    }

    return data;
  }

  // ===================================================
  // DESCRIPCIÓN Y EVOLUCIONES
  // ===================================================

  Future<PokemonExtra> getPokemonExtra(int id) async {
    final species = await getSpecies(id);

    final entries = species['flavor_text_entries'] as List? ?? [];

    String description = 'Sin descripción disponible.';

    // Preferimos español.
    for (final entry in entries) {
      if (entry['language']['name'] == 'es') {
        description = _cleanText(entry['flavor_text'] as String);
        break;
      }
    }

    // Si no hay español, buscamos inglés.
    if (description == 'Sin descripción disponible.') {
      for (final entry in entries) {
        if (entry['language']['name'] == 'en') {
          description = _cleanText(entry['flavor_text'] as String);
          break;
        }
      }
    }

    final evolutionUrl = species['evolution_chain']?['url'] as String?;

    final evolutions = evolutionUrl == null
        ? <EvolutionStage>[]
        : await getEvolutionChain(evolutionUrl);

    return PokemonExtra(description: description, evolutions: evolutions);
  }

  // ===================================================
  // CACHÉ DE CADENAS EVOLUTIVAS
  // ===================================================

  Future<List<EvolutionStage>> getEvolutionChain(String url) {
    final cached = _evolutionCache.remove(url);

    if (cached != null) {
      _cacheHits++;
      _evolutionCache[url] = cached;
      return Future.value(cached);
    }

    final pending = _pendingEvolution[url];

    if (pending != null) {
      return pending;
    }

    final request = _fetchEvolutionChain(url);
    _pendingEvolution[url] = request;

    return request.whenComplete(() {
      _pendingEvolution.remove(url);
    });
  }

  Future<List<EvolutionStage>> _fetchEvolutionChain(String url) async {
    final response = await _request(url);

    final data = Map<String, dynamic>.from(response.data as Map);

    final root = Map<String, dynamic>.from(data['chain'] as Map);

    final stages = <EvolutionStage>[];

    void walk(Map<String, dynamic> node, int depth) {
      final species = Map<String, dynamic>.from(node['species'] as Map);

      final speciesUrl = species['url'] as String;

      final id = int.parse(
        Uri.parse(speciesUrl).pathSegments
            .where((segment) => segment.isNotEmpty)
            .last,
      );

      stages.add(
        EvolutionStage(id: id, name: species['name'] as String, depth: depth),
      );

      for (final child in node['evolves_to'] as List? ?? []) {
        walk(Map<String, dynamic>.from(child as Map), depth + 1);
      }
    }

    walk(root, 0);

    _evolutionCache[url] = stages;

    // Evita que la caché de evoluciones crezca sin límite.
    while (_evolutionCache.length > 100) {
      _evolutionCache.remove(_evolutionCache.keys.first);
    }

    return stages;
  }

  String _cleanText(String text) {
    return text
        .replaceAll('\n', ' ')
        .replaceAll('\f', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

// =====================================================
// MODELOS ADICIONALES
// =====================================================

class PokemonExtra {
  final String description;
  final List<EvolutionStage> evolutions;

  const PokemonExtra({required this.description, required this.evolutions});
}

class EvolutionStage {
  final int id;
  final String name;
  final int depth;

  const EvolutionStage({
    required this.id,
    required this.name,
    required this.depth,
  });

  String get imageUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
      'sprites/pokemon/other/official-artwork/$id.png';
}
