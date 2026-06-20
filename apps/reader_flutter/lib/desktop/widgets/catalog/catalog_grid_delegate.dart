import 'package:flutter/material.dart';

import '../../layout/desktop_layout_scope.dart';
import '../../design/desktop_tokens.dart';

/// Responsive grid delegate for the desktop catalog.
SliverGridDelegate desktopCatalogGridDelegate(BuildContext context) {
  final tier = DesktopLayoutScope.tierOf(context);
  final crossAxisCount = switch (tier) {
    DesktopLayoutTier.compact => 3,
    DesktopLayoutTier.medium => 4,
    DesktopLayoutTier.expanded => 6,
  };

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: DesktopTokens.gridSpacing,
    mainAxisSpacing: DesktopTokens.gridMainSpacing,
    childAspectRatio: 0.52,
  );
}
