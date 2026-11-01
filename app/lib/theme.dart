import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary = Color(0xFF0F4C3A); // deep green
const kPurple = Color(0xFF1E6B52); // lighter green (gradient end)
const kGold = Color(0xFFC9A24B);
const kBg = Color(0xFFF7F5EF);
const kGreen = Color(0xFF16A34A);
const kRed = Color(0xFFE5484D);
const kAmber = Color(0xFFF59E0B);
const kBlue = Color(0xFF3B82F6);
const kInk = Color(0xFF16231D);
const kGrey = Color(0xFF6B7A72);
const kLine = Color(0xFFE6E2D6);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary, brightness: Brightness.light).copyWith(primary: kPrimary);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    textTheme: GoogleFonts.interTextTheme().apply(bodyColor: kInk, displayColor: kInk),
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: kInk,
      titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: kInk),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border(kLine),
      enabledBorder: border(kLine),
      focusedBorder: border(kPrimary, 1.6),
      errorBorder: border(kRed),
      focusedErrorBorder: border(kRed, 1.6),
      labelStyle: GoogleFonts.inter(color: kGrey, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPrimary)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kPrimary.withAlpha(26),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500)),
    ),
  );
}
