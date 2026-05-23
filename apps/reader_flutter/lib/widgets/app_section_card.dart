import 'package:flutter/material.dart';

import '../design/app_decorations.dart';
import '../design/app_tokens.dart';
import 'primitives/shell_primitives.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AppPanel(padding: padding, child: child);
  }
}

/// @deprecated Use [AppPanel] directly.
class LegacyAppSectionCard extends StatelessWidget {
  const LegacyAppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: AppDecorations.panel(),
      child: child,
    );
  }
}
