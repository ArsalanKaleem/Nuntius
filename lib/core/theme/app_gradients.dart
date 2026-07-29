import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gradients used by Wrapped cards and share images.
///
/// Each Wrapped card pulls a gradient by index so a run of cards reads as one
/// designed sequence rather than eight unrelated screens.
abstract final class AppGradients {
  static const forest = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF075E54), Color(0xFF128C7E)],
  );

  static const mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF128C7E), Color(0xFF25D366)],
  );

  static const midnight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF101414), Color(0xFF1B3A38)],
  );

  static const violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A2FB8), Color(0xFF7C4DFF)],
  );

  static const dusk = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3A38), Color(0xFF7C4DFF)],
  );

  static const ocean = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C4A6E), Color(0xFF42A5F5)],
  );

  static const ember = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8A3B12), Color(0xFFF39C12)],
  );

  static const blush = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8E2A5B), Color(0xFFFF6B9D)],
  );

  static const sequence = <LinearGradient>[
    forest,
    mint,
    violet,
    ocean,
    midnight,
    ember,
    dusk,
    blush,
  ];

  static LinearGradient byIndex(int index) =>
      sequence[index % sequence.length];

  /// Soft radial wash used behind the home screen and dashboard header.
  static RadialGradient ambient(Color tint) => RadialGradient(
        center: const Alignment(-0.6, -0.9),
        radius: 1.4,
        colors: [tint.withOpacity(0.28), AppColors.backgroundDark],
      );
}
