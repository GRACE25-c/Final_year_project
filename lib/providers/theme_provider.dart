import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData;

  // Initial default theme (Classic Blue)
  ThemeProvider()
      : _themeData = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ) {
    _loadThemeFromPrefs(); // Load saved color on startup
  }

  ThemeData get themeData => _themeData;

  void setSelectedTheme(Color color) async {
    _themeData = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: color),
      appBarTheme:
          AppBarTheme(backgroundColor: color, foregroundColor: Colors.white),
    );

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_theme_color', color.value);
  }

  void _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('selected_theme_color');

    if (colorValue != null) {
      Color savedColor = Color(colorValue);
      _themeData = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: savedColor),
        appBarTheme: AppBarTheme(
            backgroundColor: savedColor, foregroundColor: Colors.white),
      );
      notifyListeners();
    }
  }
}
