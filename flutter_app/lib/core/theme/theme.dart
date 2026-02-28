import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

final _lightScheme = ColorScheme.fromSeed(seedColor: AppColors.primary);
final _darkScheme = ColorScheme.fromSeed(
  seedColor: AppColors.primary,
  brightness: Brightness.dark,
);

TextTheme _appTextTheme(Brightness brightness) {
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
  ).textTheme.apply(fontFamily: 'Arial');

  return base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: AppTextStyles.headline.fontFamily,
      fontSize: AppTextStyles.headline.fontSize,
      fontWeight: AppTextStyles.headline.fontWeight,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontFamily: AppTextStyles.title.fontFamily,
      fontSize: AppTextStyles.title.fontSize,
      fontWeight: AppTextStyles.title.fontWeight,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontFamily: AppTextStyles.body.fontFamily,
      fontSize: AppTextStyles.body.fontSize,
      fontWeight: AppTextStyles.body.fontWeight,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontFamily: AppTextStyles.caption.fontFamily,
      fontSize: AppTextStyles.caption.fontSize,
      fontWeight: AppTextStyles.caption.fontWeight,
    ),
  );
}

final appTheme = ThemeData(
  colorScheme: _lightScheme,
  scaffoldBackgroundColor: AppColors.background,
  cardColor: AppColors.card,
  textTheme: _appTextTheme(Brightness.light),
  appBarTheme: AppBarTheme(
    backgroundColor: _lightScheme.primary,
    foregroundColor: _lightScheme.onPrimary,
    elevation: 2,
    titleTextStyle: TextStyle(
      fontFamily: 'Arial',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: _lightScheme.onPrimary,
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.primary,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _lightScheme.primary,
      foregroundColor: _lightScheme.onPrimary,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _lightScheme.primary,
      side: BorderSide(color: _lightScheme.outline),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _lightScheme.primary,
    foregroundColor: _lightScheme.onPrimary,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _lightScheme.surfaceContainerHighest,
    disabledColor: _lightScheme.surfaceContainer,
    selectedColor: _lightScheme.primaryContainer,
    secondarySelectedColor: _lightScheme.primaryContainer,
    checkmarkColor: _lightScheme.onPrimaryContainer,
    labelStyle: TextStyle(color: _lightScheme.onSurface),
    secondaryLabelStyle: TextStyle(color: _lightScheme.onPrimaryContainer),
    side: BorderSide(color: _lightScheme.outlineVariant),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  useMaterial3: true,
);

final appDarkTheme = ThemeData(
  colorScheme: _darkScheme,
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF1E1E1E),
  textTheme: _appTextTheme(Brightness.dark),
  appBarTheme: AppBarTheme(
    backgroundColor: _darkScheme.surface,
    foregroundColor: _darkScheme.onSurface,
    elevation: 2,
    titleTextStyle: TextStyle(
      fontFamily: 'Arial',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: _darkScheme.onSurface,
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF1E1E1E),
    border: OutlineInputBorder(),
  ),
  dividerColor: const Color(0xFF2A2A2A),
  listTileTheme: const ListTileThemeData(
    iconColor: Colors.white70,
    textColor: Colors.white,
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.primary,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _darkScheme.primary,
      foregroundColor: _darkScheme.onPrimary,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _darkScheme.primary,
      side: BorderSide(color: _darkScheme.outline),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _darkScheme.primary,
    foregroundColor: _darkScheme.onPrimary,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _darkScheme.surfaceContainerHighest,
    disabledColor: _darkScheme.surfaceContainer,
    selectedColor: _darkScheme.primaryContainer,
    secondarySelectedColor: _darkScheme.primaryContainer,
    checkmarkColor: _darkScheme.onPrimaryContainer,
    labelStyle: TextStyle(color: _darkScheme.onSurface),
    secondaryLabelStyle: TextStyle(color: _darkScheme.onPrimaryContainer),
    side: BorderSide(color: _darkScheme.outlineVariant),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  useMaterial3: true,
);
