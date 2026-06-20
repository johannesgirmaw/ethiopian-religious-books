import 'package:flutter/material.dart';

/// Horizontal metric strip for web detail pages.
class WebMetricRow extends StatelessWidget {
  const WebMetricRow({
    super.key,
    required this.children,
    this.spacing = 14,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
