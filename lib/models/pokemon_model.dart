class PokemonModel {
  final int id;
  final String name;
  final List<String> types;
  final int height;
  final int weight;
  final List<String> abilities;
  final Map<String, int> stats;
  final String? cryUrl;

  const PokemonModel({
    required this.id,
    required this.name,
    required this.types,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.stats,
    this.cryUrl,
  });

  String get imageUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
      'sprites/pokemon/other/official-artwork/$id.png';

  String get spriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
      'sprites/pokemon/$id.png';

  String get shinyUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
      'sprites/pokemon/other/official-artwork/shiny/$id.png';

  double get heightMeters => height / 10;
  double get weightKg => weight / 10;

  factory PokemonModel.fromJson(Map<String, dynamic> json) {
    return PokemonModel(
      id: json['id'] as int,
      name: json['name'] as String,
      types: (json['types'] as List)
          .map((item) => item['type']['name'] as String)
          .toList(),
      height: json['height'] as int,
      weight: json['weight'] as int,
      abilities: (json['abilities'] as List)
          .map((item) => item['ability']['name'] as String)
          .toList(),
      stats: {
        for (final item in json['stats'] as List)
          item['stat']['name'] as String: item['base_stat'] as int,
      },
      cryUrl: json['cries']?['latest'] as String?,
    );
  }
}
