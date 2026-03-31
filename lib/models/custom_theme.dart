// lib/models/custom_theme.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'custom_theme.g.dart';

@HiveType(typeId: 2)
class CustomTheme extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int backgroundColor;

  @HiveField(3)
  int surfaceColor;

  @HiveField(4)
  int surface2Color;

  @HiveField(5)
  int accentColor;

  @HiveField(6)
  int accent2Color;

  @HiveField(7)
  int textPrimaryColor;

  @HiveField(8)
  int textSecondaryColor;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  bool isDefault;

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

  // Convert to Color objects
  Color get bgColor => Color(backgroundColor);
  Color get surfColor => Color(surfaceColor);
  Color get surf2Color => Color(surface2Color);
  Color get accentCol => Color(accentColor);
  Color get accent2Col => Color(accent2Color);
  Color get textPriCol => Color(textPrimaryColor);
  Color get textSecCol => Color(textSecondaryColor);

  // Create from Color objects
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
    bool isDefault = false,
  }) {
    return CustomTheme(
      id: id,
      name: name,
      backgroundColor: backgroundColor.value,
      surfaceColor: surfaceColor.value,
      surface2Color: surface2Color.value,
      accentColor: accentColor.value,
      accent2Color: accent2Color.value,
      textPrimaryColor: textPrimaryColor.value,
      textSecondaryColor: textSecondaryColor.value,
      createdAt: DateTime.now(),
      isDefault: isDefault,
    );
  }

  // Default themes
  static CustomTheme get darkTheme => CustomTheme.fromColors(
        id: 'dark',
        name: 'Dark',
        backgroundColor: const Color(0xFF0C0C14),
        surfaceColor: const Color(0xFF141420),
        surface2Color: const Color(0xFF1C1C2A),
        accentColor: const Color(0xFFFF8C42),
        accent2Color: const Color(0xFFFF5F6D),
        textPrimaryColor: const Color(0xFFF0EFFF),
        textSecondaryColor: const Color(0xFF6E6E8A),
        isDefault: true,
      );

  static CustomTheme get lightTheme => CustomTheme.fromColors(
        id: 'light',
        name: 'Light',
        backgroundColor: const Color(0xFFF5F5F7),
        surfaceColor: const Color(0xFFFFFFFF),
        surface2Color: const Color(0xFFF0F0F2),
        accentColor: const Color(0xFFFF8C42),
        accent2Color: const Color(0xFFFF5F6D),
        textPrimaryColor: const Color(0xFF1C1C1E),
        textSecondaryColor: const Color(0xFF8E8E93),
        isDefault: true,
      );

  CustomTheme copyWith({
    String? name,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? surface2Color,
    Color? accentColor,
    Color? accent2Color,
    Color? textPrimaryColor,
    Color? textSecondaryColor,
  }) {
    return CustomTheme(
      id: id,
      name: name ?? this.name,
      backgroundColor: backgroundColor?.value ?? this.backgroundColor,
      surfaceColor: surfaceColor?.value ?? this.surfaceColor,
      surface2Color: surface2Color?.value ?? this.surface2Color,
      accentColor: accentColor?.value ?? this.accentColor,
      accent2Color: accent2Color?.value ?? this.accent2Color,
      textPrimaryColor: textPrimaryColor?.value ?? this.textPrimaryColor,
      textSecondaryColor: textSecondaryColor?.value ?? this.textSecondaryColor,
      createdAt: createdAt,
      isDefault: isDefault,
    );
  }
}
