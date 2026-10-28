
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokeverse/main.dart';

void main() {
  testWidgets('PokéVerse muestra su pantalla principal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PokeVerseApp());

    expect(find.text('PokéVerse'), findsOneWidget);
    expect(find.text('¡Hola, entrenador!'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });
}
