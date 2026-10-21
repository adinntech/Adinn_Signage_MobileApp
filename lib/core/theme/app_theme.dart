import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();
  static const navy = Color(0xFF102449);
  static const royal = Color(0xFF2563EB);
  static const softBlue = Color(0xFF5B8DEF);
  static const softBlueBg = Color(0xFFE6EEFC);
  static const teal = Color(0xFF0F9D8A);
  static const orange = Color(0xFFF08C00);
  static const vendor = Color(0xFF9333EA);
  static const error = Color(0xFFC62828);
  static const background = Color(0xFFF7F8FB);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.softBlue,
    secondaryContainer: AppColors.softBlueBg,
    tertiary: AppColors.teal,
    error: AppColors.error,
    surface: Colors.white,
  );
  const radius = BorderRadius.all(Radius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Color(0xFFE3E7EF)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.softBlueBg,
    ),
  );
}
