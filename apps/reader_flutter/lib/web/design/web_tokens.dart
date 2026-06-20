import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../layout/app_layout_scope.dart';

/// Web-specific layout and surface tokens.
class WebTokens {
  WebTokens._();

  static const double maxContentWidth = 1200;
  static const double readerColumnWidth = 720;
  static const double sidebarWidth = 260;
  static const double readerTocWidth = 280;
  static const double navHeight = 56;
  static const double compactBreakpoint = 720;
  static const double expandedBreakpoint = 1100;

  static const double gridSpacing = 20;
  static const double gridMainSpacing = 24;

  static const Color canvasBg = Color(0xFFF4F2EC);
  static const Color surfaceBg = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE4DDD2);
  static const Color sidebarSelectedBg = Color(0xFFF3EEFF);
  static const Color accentGold = Color(0xFFC9A227);
  static const Color mutedLabel = Color(0xFF7A7268);

  static double pageHorizontal(AppLayoutTier tier) {
    switch (tier) {
      case AppLayoutTier.compact:
        return AppLayout.pageHorizontal;
      case AppLayoutTier.medium:
        return 36;
      case AppLayoutTier.expanded:
        return 48;
    }
  }

  static EdgeInsets pagePadding(AppLayoutTier tier) {
    final h = pageHorizontal(tier);
    return EdgeInsets.fromLTRB(h, 28, h, 40);
  }

  static BoxDecoration panelDecoration({bool hover = false}) {
    return BoxDecoration(
      color: surfaceBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
      boxShadow: hover
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  static BoxDecoration sidebarDecoration() {
    return BoxDecoration(
      color: surfaceBg,
      border: Border(right: BorderSide(color: borderColor)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(2, 0),
        ),
      ],
    );
  }

  static TextStyle sectionLabelStyle = const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: mutedLabel,
  );
}
