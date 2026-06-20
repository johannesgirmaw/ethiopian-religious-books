import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';

enum DesktopLayoutTier { compact, medium, expanded }

/// Desktop-specific layout and surface tokens (macOS, Linux, Windows).
class DesktopTokens {
  DesktopTokens._();

  static const double minWindowWidth = 900;
  static const double minWindowHeight = 600;
  static const double sidebarWidth = 220;
  static const double contentMaxWidth = 1400;
  static const double titleBarHeight = 48;
  static const double toolbarHeight = 52;
  static const double compactBreakpoint = 900;
  static const double expandedBreakpoint = 1200;

  static const double gridSpacing = 16;
  static const double gridMainSpacing = 20;

  static const Color canvasBg = AppColors.referencePageBg;
  static const Color surfaceBg = Color(0xFFFFFFFF);
  static const Color sidebarBg = Color(0xFFF6F4F0);
  static const Color borderColor = Color(0xFFE0DAD0);
  static const Color sidebarSelectedBg = Color(0xFFEDE8F8);
  static const Color hoverBg = Color(0xFFF0EBE3);
  static const Color mutedLabel = Color(0xFF7A7268);
  static const Color accentGold = Color(0xFFC9A227);

  static DesktopLayoutTier tierForWidth(double width) {
    if (width >= expandedBreakpoint) return DesktopLayoutTier.expanded;
    if (width >= compactBreakpoint) return DesktopLayoutTier.medium;
    return DesktopLayoutTier.compact;
  }

  static EdgeInsets pagePadding(DesktopLayoutTier tier) {
    final h = switch (tier) {
      DesktopLayoutTier.compact => 20.0,
      DesktopLayoutTier.medium => 28.0,
      DesktopLayoutTier.expanded => 32.0,
    };
    return EdgeInsets.fromLTRB(h, 20, h, 28);
  }

  static BoxDecoration panelDecoration({bool hover = false}) {
    return BoxDecoration(
      color: surfaceBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor),
      boxShadow: hover
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration sidebarDecoration() {
    return BoxDecoration(
      color: sidebarBg,
      border: Border(right: BorderSide(color: borderColor)),
    );
  }

  static TextStyle sectionLabelStyle = const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: mutedLabel,
  );

  static TextStyle toolbarTitleStyle = const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle toolbarSubtitleStyle = const TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.4,
  );
}
