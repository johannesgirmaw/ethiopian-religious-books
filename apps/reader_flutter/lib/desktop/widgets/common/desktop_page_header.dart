import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../design/desktop_tokens.dart';

/// Compact desktop page header — toolbar style, not mobile hero banner.
class DesktopPageHeader extends StatelessWidget {
  const DesktopPageHeader({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DesktopTokens.toolbarTitleStyle),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: DesktopTokens.toolbarSubtitleStyle),
                  ],
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: 16),
              Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ],
          ],
        ),
        if (bottom != null) ...[
          const SizedBox(height: 16),
          bottom!,
        ],
      ],
    );
  }
}

/// Inline search field sized for desktop toolbars.
class DesktopSearchField extends StatelessWidget {
  const DesktopSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.width = 280,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: DesktopTokens.surfaceBg,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: DesktopTokens.surfaceBg,
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: DesktopTokens.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: DesktopTokens.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: AppColors.referencePrimary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
