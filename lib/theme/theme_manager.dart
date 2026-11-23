import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Poori app ka ek hi palette (light ya dark) — Hanna Bakery "Cocoa & Champagne".
/// Saari screens/widgets `ThemeManager.palette` se rang leti hain (Step 2 migration poori).
/// `AppColors` mein ab sirf `fade()` / `fadeDark()` helpers bache hain.
@immutable
class AppPalette {
  final Color bg, cardWhite, navy, teal, red, textDark, textMuted, border, amber, fieldFill;
  // AppColors se migrate hue extra rang. `navyInk` = navy jab text/icon/border ke tor par use ho (dark mode mein saaf dikhe);
  // `navy` sirf header/button jaisi surfaces ke liye.
  final Color navyInk, navyLight, tealDark, redDark, blue, orange, purple;
  final Color headerSubtitleColor, headerBadgeOverlay, savedHighlightBg;

  // Flat-minimal design system: har category ka soft "chip" background + matching icon/text rang.
  final Color flatPurpleBg, flatPurpleFg, flatCoralBg, flatCoralFg, flatBlueBg, flatBlueFg;
  final Color flatPinkBg, flatPinkFg, flatTealBg, flatTealFg, flatAmberBg, flatAmberFg;

  const AppPalette({
    required this.bg, required this.cardWhite, required this.navy, required this.teal, required this.red,
    required this.textDark, required this.textMuted, required this.border, required this.amber,
    required this.fieldFill, required this.headerSubtitleColor, required this.headerBadgeOverlay,
    required this.savedHighlightBg,
    required this.navyInk, required this.navyLight, required this.tealDark, required this.redDark,
    required this.blue, required this.orange, required this.purple,
    required this.flatPurpleBg, required this.flatPurpleFg, required this.flatCoralBg, required this.flatCoralFg,
    required this.flatBlueBg, required this.flatBlueFg, required this.flatPinkBg, required this.flatPinkFg,
    required this.flatTealBg, required this.flatTealFg, required this.flatAmberBg, required this.flatAmberFg,
  });
}

class ThemeManager {
  ThemeManager._();

  static const _keyDarkMode = 'dark_mode';

  // Hanna Bakery POS — "Cocoa & Champagne" executive palette (Hanna Fitness jaisa premium, bakery ka apna rang):
  // espresso / chocolate surfaces + champagne-caramel gold accent, cream (light) ya matte cocoa-black (dark).
  // NOTE: purane naam (navy / teal) wahi rakhe taake 70+ screens bina tabdeeli naya rang lein:
  //   navy  = header / button surface (espresso)      teal = main accent (caramel gold)
  //   navyInk = navy jab text / icon ho (light: chocolate, dark: champagne)
  static const light = AppPalette(
    bg: Color(0xFFF6F0E7), cardWhite: Color(0xFFFFFDF8), navy: Color(0xFF2A1A12), teal: Color(0xFFB5852A),
    red: Color(0xFFC8463D), textDark: Color(0xFF22160F), textMuted: Color(0xFF8A7A6B), border: Color(0xFFEADFCF),
    amber: Color(0xFFC97A12), fieldFill: Color(0xFFFAF4EB), headerSubtitleColor: Color(0xFFD8C3A1),
    headerBadgeOverlay: Color(0x26FFFFFF), savedHighlightBg: Color(0xFFF6ECD9),
    navyInk: Color(0xFF3B2416), navyLight: Color(0xFF4A3123), tealDark: Color(0xFF96691C), redDark: Color(0xFFA8362F),
    blue: Color(0xFF2F6FB0), orange: Color(0xFFD98A1C), purple: Color(0xFF7A4F9E),
    flatPurpleBg: Color(0xFFEFE6F3), flatPurpleFg: Color(0xFF6A3F8C), // plum
    flatCoralBg: Color(0xFFF8E4DA), flatCoralFg: Color(0xFFA6461F), // terracotta
    flatBlueBg: Color(0xFFE3ECF3), flatBlueFg: Color(0xFF2B5D86), // slate
    flatPinkBg: Color(0xFFF9E3E6), flatPinkFg: Color(0xFF9E3550), // raspberry (cake)
    flatTealBg: Color(0xFFE2F0E4), flatTealFg: Color(0xFF2E7A4B), // pistachio (positive)
    flatAmberBg: Color(0xFFF7EAD2), flatAmberFg: Color(0xFF9A6512), // caramel
  );

  static const dark = AppPalette(
    bg: Color(0xFF0F0B09), cardWhite: Color(0xFF1A1411), navy: Color(0xFF2A1A12), teal: Color(0xFFD9AE5F),
    red: Color(0xFFF07A70), textDark: Color(0xFFF4ECE2), textMuted: Color(0xFFA59886), border: Color(0xFF2F2620),
    amber: Color(0xFFF0A94A), fieldFill: Color(0xFF211915), headerSubtitleColor: Color(0xFFD8C3A1),
    headerBadgeOverlay: Color(0x26FFFFFF), savedHighlightBg: Color(0xFF2E2414),
    navyInk: Color(0xFFE6C688), navyLight: Color(0xFF4A3426), tealDark: Color(0xFFB8913F), redDark: Color(0xFFD9574F),
    blue: Color(0xFF7FB0E6), orange: Color(0xFFF2B45C), purple: Color(0xFFC3A0E0),
    flatPurpleBg: Color(0xFF33243F), flatPurpleFg: Color(0xFFD9C2EC),
    flatCoralBg: Color(0xFF43251A), flatCoralFg: Color(0xFFF2C0A6),
    flatBlueBg: Color(0xFF1C2B38), flatBlueFg: Color(0xFFB9D3EA),
    flatPinkBg: Color(0xFF431F2A), flatPinkFg: Color(0xFFF3BFCC),
    flatTealBg: Color(0xFF1C3325), flatTealFg: Color(0xFFA8DEB8),
    flatAmberBg: Color(0xFF3E2C12), flatAmberFg: Color(0xFFF2CF8A),
  );

  /// Premium gradient (hero header / desktop top bar): espresso -> cocoa.
  static const heroTop = Color(0xFF1E130D);
  static const heroBottom = Color(0xFF3D2817);

  /// Champagne gold (accent / pills) aur us par likhne ka rang.
  static const gold = Color(0xFFD4A24C);
  static const goldSoft = Color(0xFFF1DDB4);
  static const onGold = Color(0xFF1A120C);
  static const cream = Color(0xFFF7F0E3);

  /// MaterialApp is par listen karta hai — toggle par poori app dobara banti hai.
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(true); // Fitness jaisa: dark default

  static AppPalette get palette => isDark.value ? dark : light;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    isDark.value = p.getBool(_keyDarkMode) ?? true;
  }

  static Future<void> setDarkMode(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyDarkMode, enabled);
    isDark.value = enabled;
  }

  /// Current setting ulat kar naya value wapas deta hai.
  static Future<bool> toggleDarkMode() async {
    final v = !isDark.value;
    await setDarkMode(v);
    return v;
  }
}
