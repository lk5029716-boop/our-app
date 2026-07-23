import 'dart:ui';
import 'package:flutter/material.dart';

/// Premium ultra-dark glassmorphism palette for SmartMedia.
class SMColors {
  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF121218);
  static const Color surfaceElevated = Color(0xFF1A1A24);
  static const Color indigo = Color(0xFF6366F1);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color muted = Color(0xFF9CA3AF);
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFFD1D5DB);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color badgeBg = Color(0x99000000);
  static const Color enginePulse = Color(0xFF34D399);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ringGradient = LinearGradient(
    colors: [indigo, violet, indigo],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class SMTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: SMColors.background,
      colorScheme: const ColorScheme.dark(
        primary: SMColors.indigo,
        secondary: SMColors.violet,
        surface: SMColors.surface,
        onPrimary: SMColors.textPrimary,
        onSecondary: SMColors.textPrimary,
        onSurface: SMColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: SMColors.textPrimary,
        displayColor: SMColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SMColors.surfaceElevated,
        hintStyle: const TextStyle(color: SMColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }
}

/// Glass panel with backdrop blur for overlays and sticky chrome.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.blurSigma = 12,
    this.opacity = 0.55,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: SMColors.surface.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: SMColors.glassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
