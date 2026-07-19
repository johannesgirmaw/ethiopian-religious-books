import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';

/// Web-style page title block (replaces mobile greeting cards).
class WebPageHeader extends StatelessWidget {
  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final hasActions = actions != null && actions!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCopy(title: title, subtitle: subtitle),
        if (hasActions) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: actions!),
        ],
        if (bottom != null) ...[const SizedBox(height: 22), bottom!],
      ],
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [AppColors.referencePrimary, Color(0xFFF5A623)],
            ),
          ),
        ),
      ],
    );
  }
}
