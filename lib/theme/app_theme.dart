import 'package:flutter/material.dart';

/// 홈 화면(증권 터미널 스타일) 전용 색상 토큰.
/// 기존 ColorScheme(퍼플 테마)은 앱 전역에 그대로 유지하고,
/// 이 확장은 main.dart 및 시세 위젯들에서만 국소적으로 사용한다.
class MarketColors extends ThemeExtension<MarketColors> {
  final Color bg;
  final Color surface;
  final Color surfaceHover;
  final Color line;
  final Color ink;
  final Color muted;
  final Color accent; // 다크: 네온 그린 글로우 / 라이트: 딥 에메랄드(플랫)
  final Color accentDim; // 글로우/은은한 배경용 저투명도 accent
  final Color up; // 상승 — 빨강 (고정)
  final Color down; // 하락 — 파랑 (고정)
  final Color track; // 게이지 등 트랙(배경 호) 색

  const MarketColors({
    required this.bg,
    required this.surface,
    required this.surfaceHover,
    required this.line,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentDim,
    required this.up,
    required this.down,
    required this.track,
  });

  static const dark = MarketColors(
    bg: Color(0xFF050706),
    surface: Color(0xFF0B0F0C),
    surfaceHover: Color(0xFF0F1C15),
    line: Color(0xFF182620),
    ink: Color(0xFFEEF4EF),
    muted: Color(0xFF6C7A71),
    accent: Color(0xFF39FF8C),
    accentDim: Color(0x4739FF8C),
    up: Color(0xFFFF4550),
    down: Color(0xFF3B82F6),
    track: Color(0xFF152019),
  );

  static const light = MarketColors(
    bg: Color(0xFFF3F5F1),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFFFFFFF),
    line: Color(0xFFDFE3DA),
    ink: Color(0xFF10140F),
    muted: Color(0xFF6A7268),
    accent: Color(0xFF0F7A4C),
    accentDim: Color(0x240F7A4C),
    up: Color(0xFFD1373F),
    down: Color(0xFF2F6FDE),
    track: Color(0xFFE5E9E0),
  );

  @override
  MarketColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHover,
    Color? line,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? accentDim,
    Color? up,
    Color? down,
    Color? track,
  }) {
    return MarketColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      up: up ?? this.up,
      down: down ?? this.down,
      track: track ?? this.track,
    );
  }

  @override
  MarketColors lerp(ThemeExtension<MarketColors>? other, double t) {
    if (other is! MarketColors) return this;
    return MarketColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      up: Color.lerp(up, other.up, t)!,
      down: Color.lerp(down, other.down, t)!,
      track: Color.lerp(track, other.track, t)!,
    );
  }
}

class AppTheme {
  // Light Theme Colors — 종이톤 배경 + 딥 에메랄드 (증권 터미널 라이트)
  static const Color _lightPrimary = Color(0xFF0F7A4C);
  static const Color _lightSecondary = Color(0xFF0C6B43);
  static const Color _lightBackground = Color(0xFFF3F5F1);
  static const Color _lightSurface = Colors.white;
  static const Color _lightError = Color(0xFFB00020);
  static const Color _lightOnPrimary = Colors.white;
  static const Color _lightOnSecondary = Colors.white;
  static const Color _lightOnBackground = Color(0xFF10140F);
  static const Color _lightOnSurface = Color(0xFF10140F);
  static const Color _lightOnError = Colors.white;
  static const Color _lightOutline = Color(0xFFDFE3DA);

  // Dark Theme Colors — 근흑색 배경 + 네온 그린 (증권 터미널 다크)
  static const Color _darkPrimary = Color(0xFF39FF8C);
  static const Color _darkSecondary = Color(0xFF2FE07A);
  static const Color _darkBackground = Color(0xFF050706);
  static const Color _darkSurface = Color(0xFF0B0F0C);
  static const Color _darkError = Color(0xFFCF6679);
  static const Color _darkOnPrimary = Colors.black;
  static const Color _darkOnSecondary = Colors.black;
  static const Color _darkOnBackground = Color(0xFFEEF4EF);
  static const Color _darkOnSurface = Color(0xFFEEF4EF);
  static const Color _darkOnError = Colors.black;
  static const Color _darkOutline = Color(0xFF182620);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: _lightPrimary,
        onPrimary: _lightOnPrimary,
        secondary: _lightSecondary,
        onSecondary: _lightOnSecondary,
        error: _lightError,
        onError: _lightOnError,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        outline: _lightOutline,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        foregroundColor: _lightOnBackground,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: _lightOutline),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightSurface,
          foregroundColor: _lightOnSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: const BorderSide(color: _lightPrimary),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightPrimary,
          side: const BorderSide(color: _lightPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'NotoSansKR',
            bodyColor: _lightOnBackground,
            displayColor: _lightOnBackground,
          ),
      extensions: const [MarketColors.light],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: _darkPrimary,
        onPrimary: _darkOnPrimary,
        secondary: _darkSecondary,
        onSecondary: _darkOnSecondary,
        error: _darkError,
        onError: _darkOnError,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        outline: _darkOutline,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkOnBackground,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: _darkOutline),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkSurface,
          foregroundColor: _darkOnSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: const BorderSide(color: _darkPrimary),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimary,
          side: const BorderSide(color: _darkPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'NotoSansKR',
            bodyColor: _darkOnBackground,
            displayColor: _darkOnBackground,
          ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _darkPrimary,
        inactiveTrackColor: _darkPrimary.withValues(alpha: 0.3),
        thumbColor: _darkSecondary,
      ),
      extensions: const [MarketColors.dark],
    );
  }
}
