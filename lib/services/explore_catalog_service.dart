import 'package:dio/dio.dart';

class PokemonIndexEntry {
  final int id;
  final String name;

  const PokemonIndexEntry({required this.id, required this.name});
}

class ExploreCatalogService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pokeapi.co/api/v2/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );

  List<PokemonIndexEntry>? _index;
  Future<List<PokemonIndexEntry>>? _indexRequest;

  final Map<String, Set<int>> _typeCache = {};
  final Map<int, Set<int>> _generationCache = {};

  Future<List<PokemonIndexEntry>> getIndex() {
    if (_index != null) {
      return Future.value(_index!);
    }

    return _indexRequest ??= _loadIndex().whenComplete(() {
      _indexRequest = null;
    });
  }

  Future<List<PokemonIndexEntry>> _loadIndex() async {
    final response = await _dio.get(
      'pokemon/',
      queryParameters: {'limit': 20000, 'offset': 0},
    );

    final results = response.data['results'] as List;
    final entries = <PokemonIndexEntry>[];

    for (final item in results) {
      final url = item['url'] as String;

      final segments = Uri.parse(url).pathSegments
          .where((part) => part.isNotEmpty)
          .toList();

      final id = int.tryParse(segments.last);

      if (id != null) {
        entries.add(PokemonIndexEntry(id: id, name: item['name'] as String));
      }
    }

    entries.sort((a, b) => a.id.compareTo(b.id));
    _index = entries;

    return entries;
  }

  Future<Set<int>> getTypeIds(String type) async {
    if (_typeCache.containsKey(type)) {
      return _typeCache[type]!;
    }

    final response = await _dio.get('type/$type/');
    final items = response.data['pokemon'] as List;
    final ids = <int>{};

    for (final item in items) {
      final url = item['pokemon']['url'] as String;

      final segments = Uri.parse(url).pathSegments
          .where((part) => part.isNotEmpty)
          .toList();

      final id = int.tryParse(segments.last);

      if (id != null) {
        ids.add(id);
      }
    }

    _typeCache[type] = ids;
    return ids;
  }

  Future<Set<int>> getGenerationIds(int generation) async {
    if (_generationCache.containsKey(generation)) {
      return _generationCache[generation]!;
    }

    final response = await _dio.get('generation/$generation/');

    final items = response.data['pokemon_species'] as List;
    final ids = <int>{};

    for (final item in items) {
      final url = item['url'] as String;

      final segments = Uri.parse(url).pathSegments
          .where((part) => part.isNotEmpty)
          .toList();

      final id = int.tryParse(segments.last);

      if (id != null) {
        ids.add(id);
      }
    }

    _generationCache[generation] = ids;
    return ids;
  }
}
