// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import '../db/hive_helper.dart';
import '../models/custom_theme.dart';

class ThemeProvider extends ChangeNotifier {
  final _db = HiveHelper.instance;
  
  CustomTheme? _currentTheme;
  CustomTheme? get currentTheme => _currentTheme;

  List<CustomTheme> _customThemes = [];
  List<CustomTheme> get customThemes => _customThemes;

  ThemeProvider() {
    _loadThemes();
  }

  void _loadThemes() {
    _customThemes = _db.getAllCustomThemes();
    final savedThemeId = _db.getSetting<String>('current_theme_id');
    
    if (savedThemeId != null) {
      _currentTheme = _customThemes.firstWhere(
        (t) => t.id == savedThemeId,
        orElse: () => CustomTheme.darkTheme,
      );
    } else {
      _currentTheme = CustomTheme.darkTheme;
    }
    notifyListeners();
  }

  Future<void> setTheme(CustomTheme theme) async {
    _currentTheme = theme;
    await _db.setSetting('current_theme_id', theme.id);
    notifyListeners();
  }

  Future<void> createCustomTheme(CustomTheme theme) async {
    await _db.saveCustomTheme(theme);
    _customThemes = _db.getAllCustomThemes();
    notifyListeners();
  }

  Future<void> updateCustomTheme(CustomTheme theme) async {
    await _db.updateCustomTheme(theme);
    _customThemes = _db.getAllCustomThemes();
    if (_currentTheme?.id == theme.id) {
      _currentTheme = theme;
    }
    notifyListeners();
  }

  Future<void> deleteCustomTheme(String id) async {
    await _db.deleteCustomTheme(id);
    _customThemes = _db.getAllCustomThemes();
    if (_currentTheme?.id == id) {
      _currentTheme = CustomTheme.darkTheme;
      await _db.setSetting('current_theme_id', 'dark');
    }
    notifyListeners();
  }

  // Build ThemeData from CustomTheme
  ThemeData buildThemeData(CustomTheme theme) {
    final isDark = theme.backgroundColor == CustomTheme.darkTheme.backgroundColor;
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: theme.bgColor,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: theme.accentCol,
        onPrimary: Colors.white,
        secondary: theme.accent2Col,
        onSecondary: Colors.white,
        surface: theme.surfColor,
        onSurface: theme.textPriCol,
        error: Colors.red,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: theme.bgColor,
        foregroundColor: theme.textPriCol,
        elevation: 0,
      ),
      cardColor: theme.surfColor,
      splashFactory: InkRipple.splashFactory,
    );
  }
}
