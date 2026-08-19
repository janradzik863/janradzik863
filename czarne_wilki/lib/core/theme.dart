import 'package:flutter/material.dart';

/// Paleta i motyw aplikacji Czarne Wilki.
/// Biało-czerwono-czarna stylistyka narodowa (husarsko-wilcza),
/// spójna z logotypem projektu.
class CwColors {
  CwColors._();

  /// Karmazyn flagowy — kolor wiodący.
  static const Color crimson = Color(0xFFDC143C);

  /// Ciemniejszy odcień do gradientów i stanów wciśniętych.
  static const Color crimsonDark = Color(0xFFA20A2A);

  /// Czerń husarska — tła, nagłówki.
  static const Color black = Color(0xFF0E0E12);

  /// Powierzchnie kart.
  static const Color surface = Color(0xFF17171D);

  /// Jaśniejsza powierzchnia (elementy na kartach).
  static const Color surfaceAlt = Color(0xFF1F1F27);

  /// Biel — tekst, kontrast, górne pasy.
  static const Color white = Color(0xFFF7F5F2);

  /// Złamana biel na teksty drugorzędowe.
  static const Color whiteDim = Color(0xFFB9B4AD);

  /// Akcent „online”.
  static const Color online = Color(0xFF3DCB6F);

  /// Akcent „offline / lokalnie”.
  static const Color offline = Color(0xFFE0A63D);
}

ThemeData buildCwTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: CwColors.crimson,
      onPrimary: CwColors.white,
      secondary: CwColors.white,
      onSecondary: CwColors.black,
      surface: CwColors.surface,
      onSurface: CwColors.white,
      error: CwColors.crimsonDark,
      onError: CwColors.white,
    ),
    scaffoldBackgroundColor: CwColors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: CwColors.black,
      foregroundColor: CwColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: CwColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
    cardTheme: const CardThemeData(
      color: CwColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: Color(0x1FFFFFFF)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CwColors.crimson,
        foregroundColor: CwColors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CwColors.white,
        side: const BorderSide(color: CwColors.crimson),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CwColors.surfaceAlt,
      hintStyle: const TextStyle(color: CwColors.whiteDim),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CwColors.crimson, width: 1.6),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: CwColors.black,
      indicatorColor: CwColors.crimson,
    ),
    dividerTheme: const DividerThemeData(color: Color(0x14FFFFFF)),
  );
  return base;
}

/// Pasek w barwach narodowych — subtelny element identyfikacji pod nagłówkami.
class CwFlagStrip extends StatelessWidget {
  const CwFlagStrip({super.key, this.height = 3});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const Row(
        children: [
          Expanded(child: ColoredBox(color: CwColors.white)),
          Expanded(child: ColoredBox(color: CwColors.crimson)),
        ],
      ),
    );
  }
}

/// Logotyp projektu — centralny punkt ekranu startowego i nagłówków.
/// Wyświetla plik assets/logo/cwp_logo.jpeg w oryginalnej, nieprzetworzonej
/// formie (wyłącznie dopasowanie rozmiaru do kontenera, bez filtrów).
class CwLogo extends StatelessWidget {
  const CwLogo({super.key, this.width = 220});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        'assets/logo/cwp_logo.jpeg',
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _FallbackLogo(width: width),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        color: CwColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CwColors.crimson, width: 2),
      ),
      child: const Center(
        child: Text(
          'CW',
          style: TextStyle(
            color: CwColors.white,
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}
