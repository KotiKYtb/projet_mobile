import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeKey);
      if (themeString != null) {
        _themeMode = themeString == 'dark' ? ThemeMode.dark : ThemeMode.light;
        notifyListeners();
      }
    } catch (e) {
      print('Erreur lors du chargement du thème: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      print('Erreur lors de la sauvegarde du thème: $e');
    }
  }

  Future<void> toggleTheme() async {
    await setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

