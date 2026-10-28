import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CollectionStore extends ChangeNotifier {
  static const _key = 'pokeverse_collection_v1';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Set<int> _favorites = {};
  Set<int> _seen = {};
  Set<int> _caught = {};

  bool isLoading = true;
  String? error;

  Set<int> get favorites => Set.unmodifiable(_favorites);
  Set<int> get seen => Set.unmodifiable(_seen);
  Set<int> get caught => Set.unmodifiable(_caught);

  bool isFavorite(int id) => _favorites.contains(id);
  bool isSeen(int id) => _seen.contains(id);
  bool isCaught(int id) => _caught.contains(id);

  Future<void> load() async {
    try {
      final raw = await _prefs.getString(_key);

      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;

        Set<int> parse(String key) {
          return ((data[key] as List?) ?? [])
              .map((e) => (e as num).toInt())
              .toSet();
        }

        _favorites = parse('favorites');
        _seen = parse('seen');
        _caught = parse('caught');

        _seen.addAll(_caught);
      }

      error = null;
    } catch (_) {
      error = 'No se pudo leer la colección guardada.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _commit(
    Set<int> favorites,
    Set<int> seen,
    Set<int> caught,
  ) async {
    final data = jsonEncode({
      'favorites': favorites.toList()..sort(),
      'seen': seen.toList()..sort(),
      'caught': caught.toList()..sort(),
    });

    await _prefs.setString(_key, data);

    _favorites = favorites;
    _seen = seen;
    _caught = caught;

    notifyListeners();
  }

  Future<void> markSeen(int id) async {
    if (isLoading || isSeen(id)) return;

    await _commit({..._favorites}, {..._seen, id}, {..._caught});
  }

  Future<void> toggleFavorite(int id) async {
    if (isLoading) return;

    final updated = {..._favorites};

    if (!updated.add(id)) {
      updated.remove(id);
    }

    await _commit(updated, {..._seen, id}, {..._caught});
  }

  Future<void> toggleCaught(int id) async {
    if (isLoading) return;

    final updated = {..._caught};

    if (!updated.add(id)) {
      updated.remove(id);
    }

    await _commit({..._favorites}, {..._seen, id}, updated);
  }
}
