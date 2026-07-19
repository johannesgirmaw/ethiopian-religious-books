import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';

/// Locale-appropriate label for a genre option.
String genreOptionLabel(BuildContext context, GenreOption g) {
  final isAm = Localizations.localeOf(context).languageCode == 'am';
  if (isAm && (g.labelAm?.isNotEmpty ?? false)) return g.labelAm!;
  return g.label.isNotEmpty ? g.label : g.slug;
}

/// Greeting top bar: avatar + name/email (+ verified), favourites heart and a
/// notification bell with an unread badge. Shared by web & desktop home.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.name,
    this.email,
    this.verified = false,
    this.notificationCount = 0,
    this.onFavourites,
    this.onNotifications,
    this.avatarSize = 46,
    this.searchHint,
    this.searchController,
    this.onSearchChanged,
    this.onSearchFilterTap,
    this.searchWidth = 360,
  });

  final String name;
  final String? email;
  final bool verified;
  final int notificationCount;
  final VoidCallback? onFavourites;
  final VoidCallback? onNotifications;
  final double avatarSize;
  final String? searchHint;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchFilterTap;
  final double searchWidth;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch =
        searchHint != null &&
        searchHint!.isNotEmpty &&
        searchController != null &&
        onSearchChanged != null;
    return Row(
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            gradient: AppGradients.heroVertical,
            shape: BoxShape.circle,
            boxShadow: AppShadows.listRow,
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: avatarSize * 0.36,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
              if (email != null && email!.isNotEmpty)
                Text(
                  email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (hasSearch) ...[
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: searchWidth, minWidth: 220),
            child: _TopRightSearchField(
              hint: searchHint!,
              controller: searchController!,
              onChanged: onSearchChanged!,
              onFilterTap: onSearchFilterTap,
            ),
          ),
          const SizedBox(width: 10),
        ],
        _CircleIconButton(
          icon: Icons.favorite_border_rounded,
          onTap: onFavourites,
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
          badgeCount: notificationCount,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
                boxShadow: AppShadows.listRow,
              ),
              child: Icon(icon, size: 21, color: AppColors.textSecondary),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.surfaceCard,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopRightSearchField extends StatelessWidget {
  const _TopRightSearchField({
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.onFilterTap,
  });

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.listRow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 19,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: AppLocalizations.of(context).clearSearchTooltip,
                );
              }
              return IconButton(
                onPressed: onFilterTap,
                icon: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: AppLocalizations.of(context).filterTooltip,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Rounded search field with a trailing filter button (focus highlight + clear).
class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onFilterTap,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final _focusNode = FocusNode();
  TextEditingController? _fallback;
  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_fallback ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    _fallback?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: AppMotion.short,
            curve: Curves.easeOut,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _focused ? AppColors.primary : AppColors.line,
                width: _focused ? 1.5 : 1,
              ),
              boxShadow: AppShadows.listRow,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: _focused ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    cursorColor: AppColors.primary,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: widget.hint,
                      hintStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () {
                        _controller.clear();
                        widget.onChanged?.call('');
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: widget.onFilterTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppGradients.heroVertical,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.floatingBtn,
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal genre pills (dynamic genres). Null selection = "All".
class HomeGenreChips extends StatelessWidget {
  const HomeGenreChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<GenreOption> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Pill(
              label: l10n.homeAllGenre,
              active: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final g = options[i - 1];
          return _Pill(
            label: genreOptionLabel(context, g),
            active: selected == g.slug,
            onTap: () => onSelected(g.slug),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.line,
            ),
            boxShadow: active ? AppShadows.floatingBtn : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Underlined filter tabs for the search-results view.
class HomeFilterTabs extends StatelessWidget {
  const HomeFilterTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<GenreOption> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Tab(
              label: l10n.catalogAllResults,
              active: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final g = options[i - 1];
          return _Tab(
            label: genreOptionLabel(context, g),
            active: selected == g.slug,
            onTap: () => onSelected(g.slug),
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: AppMotion.short,
              height: 3,
              width: active ? 24 : 0,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title with an optional "View all" action.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onAction != null)
          GestureDetector(
            onTap: onAction,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                actionLabel ?? '',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
