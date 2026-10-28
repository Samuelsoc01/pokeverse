class PokemonTeam {
  final String id;
  final String name;
  final List<int> pokemonIds;

  const PokemonTeam({
    required this.id,
    required this.name,
    required this.pokemonIds,
  });

  PokemonTeam copyWith({String? name, List<int>? pokemonIds}) {
    return PokemonTeam(
      id: id,
      name: name ?? this.name,
      pokemonIds: pokemonIds ?? this.pokemonIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pokemonIds': pokemonIds,
  };

  factory PokemonTeam.fromJson(Map<String, dynamic> json) {
    return PokemonTeam(
      id: json['id'] as String,
      name: json['name'] as String,
      pokemonIds: (json['pokemonIds'] as List)
          .map((id) => (id as num).toInt())
          .toList(),
    );
  }
}
