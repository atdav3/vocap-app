import 'package:flutter/material.dart';

/// Design system inspired by uupm.cc (UI/UX Pro Max)
/// Modern Dark Slate / Clean SaaS Light, Bento Card aesthetics,
/// vibrant indigo-cyan tech accents, and responsive layout guidelines.
class AppTheme {
  // Brand accents
  static const primaryIndigo = Color(0xFF6366F1);
  static const primaryCyan = Color(0xFF06B6D4);
  static const accentEmerald = Color(0xFF10B981);
  static const accentAmber = Color(0xFFF59E0B);
  static const accentRose = Color(0xFFF43F5E);
  static const accentPurple = Color(0xFF8B5CF6);

  // Backward compatibility aliases
  static const blue = primaryIndigo;
  static const ink = Color(0xFF18233B);

  // Dark palette (uupm.cc signature)
  static const darkBg = Color(0xFF090D16);
  static const darkSurface = Color(0xFF111827);
  static const darkSurfaceHigh = Color(0xFF1A2338);
  static const darkBorder = Color(0xFF24324D);
  static const darkText = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFF94A3B8);

  // Light palette
  static const lightBg = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFF1F5F9);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? darkBg : lightBg;
    final surface = isDark ? darkSurface : lightSurface;
    final border = isDark ? darkBorder : lightBorder;
    final text = isDark ? darkText : lightText;
    final muted = isDark ? darkMuted : lightMuted;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryIndigo,
      brightness: brightness,
      surface: surface,
      onSurface: text,
      primary: primaryIndigo,
      secondary: primaryCyan,
      tertiary: accentEmerald,
      error: accentRose,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryIndigo, width: 1.8),
        ),
        hintStyle: TextStyle(color: muted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF0C101C) : Colors.white,
        selectedIconTheme: const IconThemeData(color: primaryIndigo),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: const TextStyle(
          color: primaryIndigo,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: muted,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        indicatorColor: primaryIndigo.withValues(alpha: 0.12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryIndigo.withValues(alpha: 0.12),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryIndigo,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            );
          }
          return TextStyle(
            color: muted,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          );
        }),
      ),
    );
  }
}
