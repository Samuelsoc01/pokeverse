import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pokemon_team.dart';

class TeamStore extends ChangeNotifier {
  static const _storageKey = 'pokeverse_teams_v1';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  final List<PokemonTeam> _teams = [];

  List<PokemonTeam> get teams => List.unmodifiable(_teams);

  bool isLoading = true;
  String? error;

  Future<void> load() async {
    try {
      final raw = await _prefs.getString(_storageKey);
      _teams.clear();

      if (raw != null) {
        final decoded = jsonDecode(raw) as List;

        _teams.addAll(
          decoded.map(
            (item) =>
                PokemonTeam.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      }

      error = null;
    } catch (e) {
      error = 'No se pudieron recuperar los equipos: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Garantiza que los cambios solo se confirmen
  // cuando el almacenamiento local responda.
  Future<void> _commit(List<PokemonTeam> updated) async {
    final data = jsonEncode(updated.map((team) => team.toJson()).toList());

    await _prefs.setString(_storageKey, data);

    _teams
      ..clear()
      ..addAll(updated);

    notifyListeners();
  }

  Future<PokemonTeam> createTeam(String name) async {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      throw StateError('Escribe un nombre para tu equipo.');
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final team = PokemonTeam(id: id, name: trimmed, pokemonIds: const []);

    await _commit([..._teams, team]);
    return team;
  }

  Future<void> renameTeam(String teamId, String newName) async {
    final trimmed = newName.trim();

    if (trimmed.isEmpty) {
      throw StateError('El nombre no puede estar vacío.');
    }

    await _commit([
      for (final team in _teams)
        if (team.id == teamId) team.copyWith(name: trimmed) else team,
    ]);
  }

  Future<void> deleteTeam(String teamId) async {
    await _commit(_teams.where((team) => team.id != teamId).toList());
  }

  Future<void> addPokemon(String teamId, int pokemonId) async {
    final index = _teams.indexWhere((team) => team.id == teamId);

    if (index == -1) {
      throw StateError('El equipo no existe.');
    }

    final team = _teams[index];

    if (team.pokemonIds.length >= 6) {
      throw StateError('Un equipo puede tener máximo 6 Pokémon.');
    }

    if (team.pokemonIds.contains(pokemonId)) {
      throw StateError('Este Pokémon ya pertenece al equipo.');
    }

    final updated = [..._teams];
    updated[index] = team.copyWith(pokemonIds: [...team.pokemonIds, pokemonId]);

    await _commit(updated);
  }

  Future<void> removePokemon(String teamId, int pokemonId) async {
    final index = _teams.indexWhere((team) => team.id == teamId);

    if (index == -1) return;

    final updated = [..._teams];
    final team = updated[index];

    updated[index] = team.copyWith(
      pokemonIds: team.pokemonIds.where((id) => id != pokemonId).toList(),
    );

    await _commit(updated);
  }
}
