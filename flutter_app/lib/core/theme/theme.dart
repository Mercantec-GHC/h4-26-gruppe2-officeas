import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  scaffoldBackgroundColor: AppColors.background,
  cardColor: AppColors.card,
  textTheme: const TextTheme(
    headlineMedium: AppTextStyles.headline,
    titleMedium: AppTextStyles.title,
    bodyMedium: AppTextStyles.body,
    labelSmall: AppTextStyles.caption,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.primary,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
  useMaterial3: true,
); 