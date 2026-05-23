import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Shared shell-surface decorations (v2 kit card recipes).
class AppDecorations {
  AppDecorations._();

  static BoxDecoration panel({Color? color}) => BoxDecoration(
        color: color ?? AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.panel,
      );

  static BoxDecoration listRow({Color? color}) => BoxDecoration(
        color: color ?? AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.listRow,
      );

  static BoxDecoration greetingCard() => BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.greeting),
        gradient: AppGradients.greetingMesh,
        boxShadow: AppShadows.greeting,
      );
}
