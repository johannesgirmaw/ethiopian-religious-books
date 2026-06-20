import 'package:flutter/material.dart';

import '../../design/web_tokens.dart';
import '../../layout/app_layout_scope.dart';

/// Responsive grid delegate for the web catalog.
SliverGridDelegate catalogGridDelegate(BuildContext context) {
  final tier = AppLayoutScope.tierOf(context);
  final crossAxisCount = switch (tier) {
    AppLayoutTier.compact => 2,
    AppLayoutTier.medium => 3,
    AppLayoutTier.expanded => 5,
  };

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: 20,
    mainAxisSpacing: 20,
    childAspectRatio: 0.52,
  );
}

double webPageHorizontal(BuildContext context) {
  return WebTokens.pageHorizontal(AppLayoutScope.tierOf(context));
}
