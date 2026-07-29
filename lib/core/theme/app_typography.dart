import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Manrope everywhere.
///
/// It is geometric enough to feel friendly next to the WhatsApp greens, but its
/// tall x-height and tight apertures keep four- and five-digit statistics
/// legible at display sizes — which is most of what this app shows.
abstract final class AppTypography {
  /// Tabular figures so counters do not jitter while they animate.
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static TextTheme textTheme(Color onSurface, Color muted) {
    final base = GoogleFonts.manropeTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 64,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -2.5,
        color: onSurface,
        fontFeatures: _tabular,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -1.8,
        color: onSurface,
        fontFeatures: _tabular,
      ),
      displaySmall: GoogleFonts.manrope(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.0,
        color: onSurface,
        fontFeatures: _tabular,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: muted,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: onSurface,
      ),
      /// Eyebrow / caption style: uppercase, tracked out, used to label every
      /// statistic. It is the one typographic device repeated across the app.
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: muted,
      ),
    );
  }

  /// Huge numeral used on Wrapped cards. Always drawn on a gradient.
  static TextStyle wrappedNumeral(double size) => GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 0.95,
        letterSpacing: -size * 0.05,
        color: Colors.white,
        fontFeatures: _tabular,
      );
}
