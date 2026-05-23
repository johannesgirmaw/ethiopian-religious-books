import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import 'reference_menu_button.dart';

/// Premium gradient page header with embedded search — Library / Browse screen.
class PageHeaderBox extends StatefulWidget {
  const PageHeaderBox({
    super.key,
    required this.title,
    required this.categoryLabel,
    required this.bookLabel,
    this.searchHint,
    this.onSearchChanged,
    this.initialQuery = '',
  });

  final String title;
  final String categoryLabel;
  final String bookLabel;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final String initialQuery;

  @override
  State<PageHeaderBox> createState() => _PageHeaderBoxState();
}

class _PageHeaderBoxState extends State<PageHeaderBox> {
  late final TextEditingController _searchCtrl;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = widget.onSearchChanged != null;

    return Stack(
      children: [
        // Gradient panel — rounded bottom corners
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppGradients.hero,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.xxl),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, hasSearch ? 80 : 24),
              child: Column(
                children: [
                  // Title row — centred between menu-button gap and right pad
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                _StatPill(
                                  icon: Icons.category_outlined,
                                  label: widget.categoryLabel,
                                ),
                                const SizedBox(width: 10),
                                _StatPill(
                                  icon: Icons.library_books_outlined,
                                  label: widget.bookLabel,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Menu button
        Positioned(
          top: ReferenceMenuLayout.top(context),
          left: ReferenceMenuLayout.left,
          child: const ReferenceMenuButton(),
        ),

        // Floating search bar — overlaps the gradient bottom edge
        if (hasSearch)
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: _SearchBar(
              controller: _searchCtrl,
              hint: widget.searchHint ?? 'Search…',
              focused: _focused,
              onFocusChanged: (v) => setState(() => _focused = v),
              onChanged: widget.onSearchChanged!,
            ),
          ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.focused,
    required this.onFocusChanged,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool focused;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.elevated,
        border: Border.all(
          color:
              focused ? AppColors.primary : AppColors.border,
          width: focused ? 1.8 : 1.0,
        ),
      ),
      child: Focus(
        onFocusChange: onFocusChanged,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: focused
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  size: 22,
                ),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
            );
          },
        ),
      ),
    );
  }
}
