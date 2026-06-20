import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../design/desktop_tokens.dart';

/// Grouped content block with a desktop-style section title.
class DesktopSection extends StatelessWidget {
  const DesktopSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(title, style: DesktopTokens.sectionLabelStyle),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Bordered panel used across desktop pages.
class DesktopPanel extends StatelessWidget {
  const DesktopPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesktopTokens.surfaceBg,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: DesktopTokens.panelDecoration(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Empty state card for desktop pages.
class DesktopEmptyState extends StatelessWidget {
  const DesktopEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return DesktopPanel(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.referencePrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.referencePrimary, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            Center(child: action!),
          ],
        ],
      ),
    );
  }
}
