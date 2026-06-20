import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';

class CatalogBrowseHeader extends StatefulWidget {
  const CatalogBrowseHeader({
    super.key,
    required this.categoryLabel,
    required this.bookLabel,
    required this.searchHint,
    required this.onSearchChanged,
    this.initialQuery = '',
  });

  final String categoryLabel;
  final String bookLabel;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final String initialQuery;

  @override
  State<CatalogBrowseHeader> createState() => _CatalogBrowseHeaderState();
}

class _CatalogBrowseHeaderState extends State<CatalogBrowseHeader> {
  late final TextEditingController _searchCtrl;

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

  void _clearSearch() {
    _searchCtrl.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pageHorizontal,
        4,
        AppLayout.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.category_outlined,
                label: widget.categoryLabel,
              ),
              _MetaChip(
                icon: Icons.library_books_outlined,
                label: widget.bookLabel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, value, _) {
              return TextField(
                controller: _searchCtrl,
                onChanged: widget.onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  hintText: widget.searchHint,
                  hintStyle: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: AppColors.referencePrimary.withValues(alpha: 0.7),
                  ),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          tooltip: l10n.clearSearchTooltip,
                          onPressed: _clearSearch,
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: _searchBorder(),
                  enabledBorder: _searchBorder(),
                  focusedBorder: _searchBorder(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _searchBorder() {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    borderSide: BorderSide(color: AppColors.line),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.referencePrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
