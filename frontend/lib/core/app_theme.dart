import 'package:flutter/material.dart';

class MemoraColors {
  static const bg = Color(0xFF071426);
  static const panel = Color(0xFF10243B);
  static const panel2 = Color(0xFF18324F);
  static const gold = Color(0xFF82C5FF);
  static const goldDeep = Color(0xFF3887F6);
  static const cyan = Color(0xFFA9E2FF);
  static const blue = Color(0xFF9BC8FF);
  static const violet = Color(0xFFB8D5FF);
  static const muted = Color(0xFFB9C9DB);
  static const line = Color(0x36D6E8FF);
  static const success = Color(0xFF78E0C1);
  static const danger = Color(0xFFFF899D);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MemoraColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: MemoraColors.gold,
          secondary: MemoraColors.cyan,
          surface: MemoraColors.panel,
        ),
        fontFamily: 'Arial',
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: MemoraColors.bg,
            backgroundColor: MemoraColors.gold,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        cardTheme: CardThemeData(
          color: MemoraColors.panel.withValues(alpha: .72),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: MemoraColors.line),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: MemoraColors.panel2,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .07),
          hintStyle: const TextStyle(color: MemoraColors.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: MemoraColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: MemoraColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: MemoraColors.gold),
          ),
        ),
      );
}
