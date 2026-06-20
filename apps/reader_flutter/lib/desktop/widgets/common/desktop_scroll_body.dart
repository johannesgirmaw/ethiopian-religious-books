import 'package:flutter/material.dart';

/// Scrollable desktop page body that always fills the content area.
class DesktopScrollBody extends StatelessWidget {
  const DesktopScrollBody({
    super.key,
    required this.padding,
    required this.children,
    this.onRefresh,
  });

  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget scrollView = LayoutBuilder(
      builder: (context, constraints) {
        final insets = padding.resolve(Directionality.of(context));
        final minHeight = (constraints.maxHeight - insets.vertical)
            .clamp(0.0, double.infinity);
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );

    if (onRefresh != null) {
      scrollView = RefreshIndicator(
        onRefresh: onRefresh!,
        child: scrollView,
      );
    }

    return scrollView;
  }
}
