import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Paper and chrome colors for the PDF reader (not the catalog shell).
class PdfReaderTheme {
  const PdfReaderTheme({
    required this.mode,
    required this.canvas,
    required this.toolbarBg,
    required this.toolbarFg,
    required this.toolbarMuted,
    required this.border,
    required this.fieldFill,
  });

  final String mode;
  final Color canvas;
  final Color toolbarBg;
  final Color toolbarFg;
  final Color toolbarMuted;
  final Color border;
  final Color fieldFill;

  bool get isDark => mode == 'dark';
  bool get isSepia => mode == 'sepia';

  static PdfReaderTheme forMode(String mode) {
    switch (mode) {
      case 'dark':
        return const PdfReaderTheme(
          mode: 'dark',
          canvas: Color(0xFF0F141B),
          toolbarBg: Color(0xFF1A222D),
          toolbarFg: Color(0xFFE6EDF7),
          toolbarMuted: Color(0xFF93A1B5),
          border: Color(0xFF2A3441),
          fieldFill: Color(0xFF151C25),
        );
      case 'sepia':
        return const PdfReaderTheme(
          mode: 'sepia',
          canvas: Color(0xFFF4ECD8),
          toolbarBg: Color(0xFFE8DCC4),
          toolbarFg: Color(0xFF5C4A32),
          toolbarMuted: Color(0xFF8A7355),
          border: Color(0xFFD4C4A8),
          fieldFill: Color(0xFFFAF6EB),
        );
      default:
        return const PdfReaderTheme(
          mode: 'light',
          canvas: AppColors.surfaceStrong,
          toolbarBg: AppColors.surfaceCard,
          toolbarFg: AppColors.textPrimary,
          toolbarMuted: AppColors.textSecondary,
          border: AppColors.border,
          fieldFill: AppColors.surfaceCard,
        );
    }
  }
}
