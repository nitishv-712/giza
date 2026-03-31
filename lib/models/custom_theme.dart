// lib/models/custom_theme.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'custom_theme.g.dart';

@HiveType(typeId: 2)
class CustomTheme extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  // Raw color values stored as ints (ARGB, e.g. 0xFFFF8C42)
  @HiveField(2)
  final int backgroundColor;

  @HiveField(3)
  final int surfaceColor;

  @HiveField(4)
  final int surface2Color;

  @HiveField(5)
  final int accentColor;

  @HiveField(6)
  final int accent2Color;

  @HiveField(7)
  final int textPrimaryColor;

  @HiveField(8)
  final int textSecondaryColor;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final bool isDefault;

  CustomTheme({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.surface2Color,
    required this.accentColor,
    required this.accent2Color,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.createdAt,
    this.isDefault = false,
  });

  /// Convenience constructor that accepts [Color] values instead of raw ints.
  /// Used by [ThemeCreatorScreen] so it never has to call `.value` manually.
  factory CustomTheme.fromColors({
    required String id,
    required String name,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color surface2Color,
    required Color accentColor,
    required Color accent2Color,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    DateTime? createdAt,
    bool isDefault = false,
  }) =>
      CustomTheme(
        id:                 id,
        name:               name,
        isDefault:          isDefault,
        createdAt:          createdAt ?? DateTime.now(),
        backgroundColor:    backgroundColor.value,
        surfaceColor:       surfaceColor.value,
        surface2Color:      surface2Color.value,
        accentColor:        accentColor.value,
        accent2Color:       accent2Color.value,
        textPrimaryColor:   textPrimaryColor.value,
        textSecondaryColor: textSecondaryColor.value,
      );

  // ── Color getters ──────────────────────────────────────────────────────────

  Color get bgColor    => Color(backgroundColor);
  Color get surfColor  => Color(surfaceColor);
  Color get surf2Color => Color(surface2Color);
  Color get accentCol  => Color(accentColor);
  Color get accent2Col => Color(accent2Color);
  Color get textPriCol => Color(textPrimaryColor);
  Color get textSecCol => Color(textSecondaryColor);

  // ── Built-in themes ────────────────────────────────────────────────────────
  //
  // These are never persisted to Hive — the provider always reconstructs them
  // from these factory getters so the adapter fields are never called on them.
  // createdAt uses the Unix epoch as a harmless sentinel value.

  /// Default dark theme — deep charcoal with warm amber/coral accents.
  static CustomTheme get darkTheme => CustomTheme(
    id:                 'dark',
    name:               'Dark (Default)',
    isDefault:          true,
    createdAt:          DateTime.fromMillisecondsSinceEpoch(0),
    backgroundColor:    0xFF0C0C14,
    surfaceColor:       0xFF141420,
    surface2Color:      0xFF1C1C2A,
    accentColor:        0xFFFF8C42,
    accent2Color:       0xFFFF5F6D,
    textPrimaryColor:   0xFFF0EFFF,
    textSecondaryColor: 0xFF6E6E8A,
  );

  /// Light theme — warm white surfaces with darkened accent pair for contrast.
  static CustomTheme get lightTheme => CustomTheme(
    id:                 'light',
    name:               'Light',
    isDefault:          true,
    createdAt:          DateTime.fromMillisecondsSinceEpoch(0),
    backgroundColor:    0xFFF7F5F2,   // warm off-white
    surfaceColor:       0xFFFFFFFF,   // card surfaces
    surface2Color:      0xFFEFECE8,   // nested surfaces
    accentColor:        0xFFE07020,   // amber darkened for light bg legibility
    accent2Color:       0xFFD94058,   // coral darkened for light bg legibility
    textPrimaryColor:   0xFF1A1A26,   // near-black with blue tint
    textSecondaryColor: 0xFF7A7A94,   // muted grey with blue undertone
  );

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id':                 id,
    'name':               name,
    'isDefault':          isDefault,
    'createdAt':          createdAt.millisecondsSinceEpoch,
    'backgroundColor':    backgroundColor,
    'surfaceColor':       surfaceColor,
    'surface2Color':      surface2Color,
    'accentColor':        accentColor,
    'accent2Color':       accent2Color,
    'textPrimaryColor':   textPrimaryColor,
    'textSecondaryColor': textSecondaryColor,
  };

  factory CustomTheme.fromMap(Map<String, dynamic> map) => CustomTheme(
    id:                  map['id'] as String,
    name:                map['name'] as String,
    isDefault:           map['isDefault'] as bool? ?? false,
    createdAt:           DateTime.fromMillisecondsSinceEpoch(
                             map['createdAt'] as int? ?? 0),
    backgroundColor:     map['backgroundColor'] as int,
    surfaceColor:        map['surfaceColor'] as int,
    surface2Color:       map['surface2Color'] as int,
    accentColor:         map['accentColor'] as int,
    accent2Color:        map['accent2Color'] as int,
    textPrimaryColor:    map['textPrimaryColor'] as int,
    textSecondaryColor:  map['textSecondaryColor'] as int,
  );

  CustomTheme copyWith({
    String? id,
    String? name,
    bool? isDefault,
    DateTime? createdAt,
    int? backgroundColor,
    int? surfaceColor,
    int? surface2Color,
    int? accentColor,
    int? accent2Color,
    int? textPrimaryColor,
    int? textSecondaryColor,
  }) =>
      CustomTheme(
        id:                 id                 ?? this.id,
        name:               name               ?? this.name,
        isDefault:          isDefault          ?? this.isDefault,
        createdAt:          createdAt          ?? this.createdAt,
        backgroundColor:    backgroundColor    ?? this.backgroundColor,
        surfaceColor:       surfaceColor        ?? this.surfaceColor,
        surface2Color:      surface2Color       ?? this.surface2Color,
        accentColor:        accentColor         ?? this.accentColor,
        accent2Color:       accent2Color        ?? this.accent2Color,
        textPrimaryColor:   textPrimaryColor    ?? this.textPrimaryColor,
        textSecondaryColor: textSecondaryColor  ?? this.textSecondaryColor,
      );
}