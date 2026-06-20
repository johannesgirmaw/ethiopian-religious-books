import 'package:flutter/material.dart';

import '../../design/app_decorations.dart';
import '../../design/app_tokens.dart';
import '../../design/app_typography.dart';
import 'shared_widgets.dart' show greetingForL10n;

export 'shared_widgets.dart';

// ─── Greeting strip (v2 GreetingStrip) ───────────────────────────────────────

class AppGreetingCard extends StatelessWidget {
  const AppGreetingCard({
    super.key,
    required this.greetingLine,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String greetingLine;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pageHorizontal,
        14,
        AppLayout.pageHorizontal,
        10,
      ),
      child: Container(
        width: double.infinity,
        decoration: AppDecorations.greetingCard(),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greetingLine,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(height: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Deprecated('Use greetingForL10n from shared_widgets.dart')
String greetingForTimeOfDay() => 'Good morning';

// ─── Hero metric (v2 HeroMetric) ─────────────────────────────────────────────

class AppHeroMetric extends StatelessWidget {
  const AppHeroMetric({
    super.key,
    required this.label,
    required this.value,
    this.chip,
    this.footer,
    this.onTap,
  });

  final String label;
  final String value;
  final Widget? chip;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (chip != null) chip!,
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: AppTypography.heroMetricValue),
          if (footer != null) ...[
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: child,
      ),
    );
  }
}

// ─── Stat tile (v2 StatTile) ─────────────────────────────────────────────────

class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.referencePrimary,
    this.hint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        child: Ink(
          decoration: AppDecorations.listRow(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(height: 10),
              Text(value, style: AppTypography.statTileValue),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action rail (v2 ActionRail) ─────────────────────────────────────────────

class AppActionRailItem {
  const AppActionRailItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppColors.referencePrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;
}

class AppActionRail extends StatelessWidget {
  const AppActionRail({super.key, required this.items});

  final List<AppActionRailItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 132,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: AppDecorations.listRow(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: item.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(item.icon, size: 16, color: item.accent),
                    ),
                    const Spacer(),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section header (v2 SectionH) ────────────────────────────────────────────

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.sectionTitle)),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.referencePrimary,
              ),
              child: Text(
                actionLabel ?? 'View all',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Status chip (v2 StatusBadge) ────────────────────────────────────────────

enum AppStatusKind { active, neutral, pending, accent }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.kind = AppStatusKind.neutral,
  });

  final String label;
  final AppStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, dot) = switch (kind) {
      AppStatusKind.active => (
          AppColors.successSurface,
          AppColors.successText,
          AppColors.successBorder,
        ),
      AppStatusKind.pending => (
          const Color(0x1FF59E0B),
          const Color(0xFF92660B),
          const Color(0xFFF59E0B),
        ),
      AppStatusKind.accent => (
          AppColors.referencePrimary.withValues(alpha: 0.10),
          AppColors.referencePrimary,
          AppColors.referencePrimary,
        ),
      AppStatusKind.neutral => (
          AppColors.textPrimary.withValues(alpha: 0.06),
          AppColors.textSecondary,
          AppColors.textTertiary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Book cover thumb (v2 ListItem thumb) ────────────────────────────────────

class AppBookCover extends StatelessWidget {
  const AppBookCover({
    super.key,
    this.size = 58,
    this.icon = Icons.menu_book_rounded,
    this.accent = AppColors.referencePrimary,
    this.borderRadius = 14,
    this.expand = false,
  });

  final double size;
  final IconData icon;
  final Color accent;
  final double borderRadius;
  final bool expand;

  BoxDecoration get _decoration => BoxDecoration(
        borderRadius: expand
            ? null
            : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.04),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (expand) {
      return Container(
        width: double.infinity,
        decoration: _decoration,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 36,
          color: accent.withValues(alpha: 0.85),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: _decoration,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.38,
        color: accent.withValues(alpha: 0.85),
      ),
    );
  }
}

// ─── Panel (v2 PanelV2) ──────────────────────────────────────────────────────

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AppDecorations.panel(),
      child: child,
    );
  }
}

// ─── Segmented control (v2 Segmented) ────────────────────────────────────────

class AppSegmentedOption<T> {
  const AppSegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppSegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final active = o.value == value;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(o.value),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: AppMotion.short,
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.surfaceCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  o.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Library shell header (replaces gradient PageHeaderBox) ──────────────────

class LibraryShellHeader extends StatefulWidget {
  const LibraryShellHeader({
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
  State<LibraryShellHeader> createState() => _LibraryShellHeaderState();
}

class _LibraryShellHeaderState extends State<LibraryShellHeader> {
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.sectionTitle.copyWith(
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
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
                    ],
                  ),
                ),
              ],
            ),
            if (widget.onSearchChanged != null) ...[
              const SizedBox(height: 14),
              _SearchField(
                controller: _searchCtrl,
                hint: widget.searchHint ?? 'Search…',
                focused: _focused,
                onFocusChanged: (v) => setState(() => _focused = v),
                onChanged: widget.onSearchChanged!,
              ),
            ],
          ],
        ),
      ),
    );
  }
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

class _SearchField extends StatelessWidget {
  const _SearchField({
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
      height: 48,
      decoration: AppDecorations.listRow(),
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
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
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
                      ? AppColors.referencePrimary
                      : AppColors.textTertiary,
                  size: 22,
                ),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            );
          },
        ),
      ),
    );
  }
}
