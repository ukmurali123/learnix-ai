import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color accentLight;
  final Color success;
  final Color successLight;
  final Color surfaceBg;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderSubtle;

  // Spacing Scale
  final double space4;
  final double space8;
  final double space12;
  final double space16;
  final double space20;
  final double space24;
  final double space32;

  // Radii
  final double radius16;
  final BorderRadius borderRadius16;

  // Shadows
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> hoverShadow;

  const AppTokens({
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.accentLight,
    required this.success,
    required this.successLight,
    required this.surfaceBg,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderSubtle,
    this.space4 = 4.0,
    this.space8 = 8.0,
    this.space12 = 12.0,
    this.space16 = 16.0,
    this.space20 = 20.0,
    this.space24 = 24.0,
    this.space32 = 32.0,
    this.radius16 = 16.0,
    this.borderRadius16 = const BorderRadius.all(Radius.circular(16)),
    this.cardShadow = const [
      BoxShadow(
        color: Color(0x080F172A),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
    this.hoverShadow = const [
      BoxShadow(
        color: Color(0x140F172A),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
  });

  @override
  AppTokens copyWith({
    Color? primary,
    Color? primaryLight,
    Color? accent,
    Color? accentLight,
    Color? success,
    Color? successLight,
    Color? surfaceBg,
    Color? cardBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? borderSubtle,
  }) {
    return AppTokens(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      success: success ?? this.success,
      successLight: successLight ?? this.successLight,
      surfaceBg: surfaceBg ?? this.surfaceBg,
      cardBg: cardBg ?? this.cardBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      success: Color.lerp(success, other.success, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      surfaceBg: Color.lerp(surfaceBg, other.surfaceBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTheme.defaultTokens;
}

class AppTheme {
  static const AppTokens defaultTokens = AppTokens(
    primary: Color(0xFF2563EB),
    primaryLight: Color(0xFFEFF6FF),
    accent: Color(0xFFF97316),
    accentLight: Color(0xFFFFF7ED),
    success: Color(0xFF16A34A),
    successLight: Color(0xFFF0FDF4),
    surfaceBg: Color(0xFFF8FAFC),
    cardBg: Colors.white,
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    borderSubtle: Color(0xFFE2E8F0),
  );

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: defaultTokens.surfaceBg,
      colorScheme: ColorScheme.light(
        primary: defaultTokens.primary,
        secondary: defaultTokens.accent,
        surface: defaultTokens.cardBg,
        error: const Color(0xFFDC2626),
      ),
      extensions: const [defaultTokens],
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: defaultTokens.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: defaultTokens.textPrimary,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: defaultTokens.textPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: defaultTokens.textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: defaultTokens.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: defaultTokens.borderRadius16,
          side: BorderSide(color: defaultTokens.borderSubtle),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: defaultTokens.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: defaultTokens.space24,
            vertical: defaultTokens.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: defaultTokens.borderRadius16,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: defaultTokens.primary,
          side: BorderSide(color: defaultTokens.primary.withOpacity(0.3), width: 1.5),
          padding: EdgeInsets.symmetric(
            horizontal: defaultTokens.space24,
            vertical: defaultTokens.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: defaultTokens.borderRadius16,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
