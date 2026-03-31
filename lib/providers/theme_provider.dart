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
    // Load persisted custom themes, then prepend the two built-in ones so they
    // always appear first in any selector UI.
    final persisted = _db.getAllCustomThemes();
    _customThemes = [
      CustomTheme.darkTheme,
      CustomTheme.lightTheme,
      ...persisted.where((t) => !t.isDefault), // user-created themes only
    ];

    final savedId = _db.getSetting<String>('current_theme_id');
    if (savedId != null) {
      _currentTheme = _customThemes.firstWhere(
        (t) => t.id == savedId,
        orElse: () => CustomTheme.darkTheme, // fall back to dark if id stale
      );
    } else {
      // ── Dark is the default ───────────────────────────────────────────────
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
    // Rebuild list keeping built-ins at the front
    final persisted = _db.getAllCustomThemes();
    _customThemes = [
      CustomTheme.darkTheme,
      CustomTheme.lightTheme,
      ...persisted.where((t) => !t.isDefault),
    ];
    notifyListeners();
  }

  Future<void> updateCustomTheme(CustomTheme theme) async {
    await _db.updateCustomTheme(theme);
    final persisted = _db.getAllCustomThemes();
    _customThemes = [
      CustomTheme.darkTheme,
      CustomTheme.lightTheme,
      ...persisted.where((t) => !t.isDefault),
    ];
    if (_currentTheme?.id == theme.id) {
      _currentTheme = theme;
    }
    notifyListeners();
  }

  Future<void> deleteCustomTheme(String id) async {
    // Guard: never allow deleting built-in themes
    if (id == 'dark' || id == 'light') return;

    await _db.deleteCustomTheme(id);
    final persisted = _db.getAllCustomThemes();
    _customThemes = [
      CustomTheme.darkTheme,
      CustomTheme.lightTheme,
      ...persisted.where((t) => !t.isDefault),
    ];
    if (_currentTheme?.id == id) {
      _currentTheme = CustomTheme.darkTheme;
      await _db.setSetting('current_theme_id', 'dark');
    }
    notifyListeners();
  }

  // ── ThemeData builder ──────────────────────────────────────────────────────
  //
  // Previously this inferred light/dark by comparing backgroundColor to the
  // dark theme's value — that broke as soon as any custom theme had a similar
  // background color.  We now derive brightness from the luminance of the
  // background color itself, which works for any theme.

  ThemeData buildThemeData(CustomTheme theme) {
    // A background with relative luminance > 0.35 is perceptually "light".
    final luminance = theme.bgColor.computeLuminance();
    final isDark    = luminance <= 0.35;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    // Border color: a semi-transparent version of the primary text color.
    final borderColor = theme.textPriCol.withOpacity(isDark ? 0.12 : 0.10);

    // Switch thumb & track colors that match the accent on both themes.
    final switchTheme = SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return isDark
            ? const Color(0xFF6E6E8A)
            : const Color(0xFFAAAAAA);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return theme.accentCol;
        return isDark
            ? const Color(0xFF2A2A3E)
            : const Color(0xFFDDDDDD);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );

    return ThemeData(
      useMaterial3:            true,
      brightness:              brightness,
      scaffoldBackgroundColor: theme.bgColor,

      colorScheme: ColorScheme(
        brightness:   brightness,
        primary:      theme.accentCol,
        onPrimary:    Colors.white,
        secondary:    theme.accent2Col,
        onSecondary:  Colors.white,
        surface:      theme.surfColor,
        onSurface:    theme.textPriCol,
        // Provide surfaceContainerHighest so Material widgets that use it
        // (e.g. BottomNavigationBar, NavigationBar) pick up the right color.
        surfaceContainerHighest: theme.surf2Color,
        outline:      borderColor,
        error:        theme.accent2Col,
        onError:      Colors.white,
      ),

      // AppBar matches scaffold bg with no shadow.
      appBarTheme: AppBarTheme(
        backgroundColor: theme.bgColor,
        foregroundColor: theme.textPriCol,
        iconTheme:       IconThemeData(color: theme.textPriCol),
        elevation:       0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color:       theme.textPriCol,
          fontSize:    17,
          fontWeight:  FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // Card / dialog surfaces.
      cardColor:  theme.surfColor,
      cardTheme: CardThemeData(
        color:        theme.surfColor,
        elevation:    0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
      ),

      // AlertDialog — keeps the app's visual language inside dialogs.
      dialogTheme: DialogThemeData(
        backgroundColor: theme.surfColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        titleTextStyle: TextStyle(
          color:      theme.textPriCol,
          fontSize:   17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color:    theme.textSecCol,
          fontSize: 14,
          height:   1.5,
        ),
      ),

      // SnackBar.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.surf2Color,
        contentTextStyle: TextStyle(color: theme.textPriCol, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // Input / TextField — used in the search bar.
      inputDecorationTheme: InputDecorationTheme(
        filled:           true,
        fillColor:        theme.surfColor,
        hintStyle:        TextStyle(color: theme.textSecCol, fontSize: 14),
        border:           InputBorder.none,
        enabledBorder:    InputBorder.none,
        focusedBorder:    InputBorder.none,
      ),

      // ListTile defaults (used inside dialogs for manage-themes list).
      listTileTheme: ListTileThemeData(
        textColor:       theme.textPriCol,
        iconColor:       theme.accentCol,
        tileColor:       Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // Divider.
      dividerTheme: DividerThemeData(
        color:     borderColor,
        thickness: 0.5,
        space:     0,
      ),

      switchTheme: switchTheme,
      splashFactory: InkRipple.splashFactory,
    );
  }
}