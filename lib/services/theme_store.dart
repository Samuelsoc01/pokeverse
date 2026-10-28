import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore extends ChangeNotifier {
  static const String _storageKey = 'pokeverse_dark_mode';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    try {
      _isDark = await _prefs.getBool(_storageKey) ?? false;
      notifyListeners();
    } catch (error) {
      debugPrint('Error cargando tema: $error');
    }
  }

  Future<void> toggleTheme() async {
    final newValue = !_isDark;

    // Primero guardamos la preferencia.
    await _prefs.setBool(_storageKey, newValue);

    // Después actualizamos la interfaz.
    _isDark = newValue;
    notifyListeners();
  }
}
