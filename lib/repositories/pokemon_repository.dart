import '../models/pokemon_model.dart';
import '../services/pokeapi_service.dart';

class PokemonRepository {
  final PokeApiService _apiService;

  PokemonRepository(this._apiService);

  Future<List<PokemonModel>> getPokemonPage({int limit = 20, int offset = 0}) {
    return _apiService.getPokemonPage(limit: limit, offset: offset);
  }

  Future<PokemonModel> getPokemon(int id) {
    return _apiService.getPokemon(id);
  }
}
