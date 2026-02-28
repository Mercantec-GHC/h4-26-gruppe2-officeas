import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

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
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  scaffoldBackgroundColor: AppColors.background,
  cardColor: AppColors.card,
  textTheme: _appTextTheme(Brightness.light),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 2,
    titleTextStyle: TextStyle(
      fontFamily: 'Arial',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.primary,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
  useMaterial3: true,
);

final appDarkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF1E1E1E),
  textTheme: _appTextTheme(Brightness.dark),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    foregroundColor: Colors.white,
    elevation: 2,
    titleTextStyle: TextStyle(
      fontFamily: 'Arial',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
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
  useMaterial3: true,
);
