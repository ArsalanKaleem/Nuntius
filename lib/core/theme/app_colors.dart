import 'package:flutter/material.dart';

/// Single source of truth for every colour in Nuntius.
///
/// The palette is WhatsApp-adjacent on purpose — people should feel at home —
/// but the deep ink background and the purple/blue accents give the app its own
/// identity so it never reads as a clone.
abstract final class AppColors {
  // Brand greens
  static const primaryDark = Color(0xFF075E54);
  static const secondary = Color(0xFF128C7E);
  static const accent = Color(0xFF25D366);
  static const lightGreen = Color(0xFFDCF8C6);
  static const neutralBackground = Color(0xFFECE5DD);

  // Dark surfaces
  static const backgroundDark = Color(0xFF101414);
  static const cardDark = Color(0xFF182222);
  static const surfaceDark = Color(0xFF1F2B2B);

  // Light surfaces
  static const backgroundLight = Color(0xFFF7F5F1);
  static const cardLight = Color(0xFFFFFFFF);

  // Neutrals
  static const white = Color(0xFFFFFFFF);
  static const grey = Color(0xFFB6B6B6);
  static const greyDark = Color(0xFF6B7676);

  // Semantic
  static const danger = Color(0xFFE74C3C);
  static const warning = Color(0xFFF39C12);
  static const purple = Color(0xFF7C4DFF);
  static const blue = Color(0xFF42A5F5);

  /// Deterministic colour for a participant, so the same person keeps the same
  /// colour across charts, cards and the PDF report.
  static const participantPalette = <Color>[
    accent,
    purple,
    blue,
    warning,
    Color(0xFFFF6B9D),
    Color(0xFF00BFA5),
    Color(0xFFFFD166),
    Color(0xFF9C6ADE),
  ];

  static Color forParticipant(int index) =>
      participantPalette[index % participantPalette.length];
}
