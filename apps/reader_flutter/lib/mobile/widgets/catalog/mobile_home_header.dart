import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';

/// Top bar: avatar + name/email, a "favourites" heart button, and a
/// notification bell with an unread badge — matching the reference home.
class MobileHomeTopBar extends StatelessWidget {
  const MobileHomeTopBar({
    super.key,
    required this.name,
    this.email,
    this.verified = false,
    this.notificationCount = 0,
    this.onBible,
    this.onFavourites,
    this.onNotifications,
    this.onSearch,
    this.searchActive = false,
  });

  final String name;
  final String? email;
  final bool verified;
  final int notificationCount;
  final VoidCallback? onBible;
  final VoidCallback? onFavourites;
  final VoidCallback? onNotifications;
  final VoidCallback? onSearch;
  final bool searchActive;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: AppGradients.heroVertical,
            shape: BoxShape.circle,
            boxShadow: AppShadows.listRow,
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 11),
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
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
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          icon: Icons.search_rounded,
          onTap: onSearch,
          highlighted: searchActive,
        ),
        // No [onBible] means the Bible has no content — drop the shortcut.
        if (onBible != null) ...[
          const SizedBox(width: 8),
          _CircleIconButton(
            icon: Icons.menu_book_outlined,
            onTap: onBible,
          ),
        ],
        const SizedBox(width: 8),
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
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surfaceCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: highlighted ? AppColors.primary : AppColors.line,
              ),
              boxShadow: AppShadows.listRow,
            ),
            child: Icon(
              icon,
              size: 20,
              color: highlighted ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.surfaceCard, width: 1.5),
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
    );
  }
}

/// Rounded search field with a trailing filter button (reference home/search).
class MobileSearchBar extends StatefulWidget {
  const MobileSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onFilterTap,
    this.readOnly = false,
    this.onTap,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  State<MobileSearchBar> createState() => _MobileSearchBarState();
}

class _MobileSearchBarState extends State<MobileSearchBar> {
  final _focusNode = FocusNode();
  TextEditingController? _fallbackController;
  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_fallbackController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _fallbackController?.dispose();
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
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  size: 21,
                  color: _focused ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    readOnly: widget.readOnly,
                    onTap: widget.onTap,
                    cursorColor: AppColors.primary,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 14.5,
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                // Clear button — appears only when there is text.
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
        const SizedBox(width: 10),
        GestureDetector(
          onTap: widget.onFilterTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppGradients.heroVertical,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.floatingBtn,
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
