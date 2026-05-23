import 'dart:ui';

import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

/// Geometry for the triple-bubble nav bar (shared by clip, paint, and hit targets).
class _BubbleNavGeometry {
  _BubbleNavGeometry._();

  static double radius(Size size) => size.height * 0.44;

  static double pad(Size size) => 6.0;

  /// Circle centers for each tab — must match [_tripleBubblePath].
  static List<Offset> tabCenters(Size size, int tabCount) {
    final h = size.height;
    final r = radius(size);
    final cy = h / 2;
    final p = pad(size);
    final w = size.width;

    if (tabCount <= 1) {
      return [Offset(w / 2, cy)];
    }
    if (tabCount == 2) {
      return [
        Offset(p + r, cy),
        Offset(w - p - r, cy),
      ];
    }
    final span = (w - 2 * p) / 2;
    return [
      Offset(p + r, cy),
      Offset(p + span, cy),
      Offset(w - p - r, cy),
    ];
  }

  static Path bubblePath(Size size, int tabCount) {
    final centers = tabCenters(size, tabCount);
    final r = radius(size);
    Path path = Path()
      ..addOval(Rect.fromCircle(center: centers.first, radius: r));
    for (var i = 1; i < centers.length; i++) {
      final next = Path()
        ..addOval(Rect.fromCircle(center: centers[i], radius: r));
      path = Path.combine(PathOperation.union, path, next);
    }
    return path;
  }
}

/// A floating, glassmorphic triple-bubble bottom navigation bar.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<LiquidNavItem> items;

  static const double barHeight = 80;
  static const double bottomInset = 110;
  static const double _hitSize = 56;

  @override
  Widget build(BuildContext context) {
    assert(items.length >= 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final barWidth = (width - 48).clamp(260.0, 340.0);
    final barSize = Size(barWidth, barHeight);
    final centers = _BubbleNavGeometry.tabCenters(barSize, items.length);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Center(
        child: SizedBox(
          width: barWidth,
          height: barHeight + 10,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 8,
                child: SizedBox(
                  width: barWidth,
                  height: barHeight,
                  child: ClipPath(
                    clipper: _TripleBubbleClipper(tabCount: items.length),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                          child: const SizedBox.expand(),
                        ),
                        CustomPaint(
                          painter: _LiquidGlassNavPainter(
                            isDark: isDark,
                            tabCount: items.length,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedPositioned(
                                duration: AppMotion.medium,
                                curve: Curves.easeOutCubic,
                                left: centers[selectedIndex].dx -
                                    _SelectionOrb.size / 2,
                                top: centers[selectedIndex].dy -
                                    _SelectionOrb.size / 2,
                                width: _SelectionOrb.size,
                                height: _SelectionOrb.size,
                                child: _SelectionOrb(isDark: isDark),
                              ),
                              ...List.generate(items.length, (index) {
                                final center = centers[index];
                                final item = items[index];
                                final selected = index == selectedIndex;
                                return Positioned(
                                  left: center.dx - _hitSize / 2,
                                  top: center.dy - _hitSize / 2,
                                  width: _hitSize,
                                  height: _hitSize,
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => onSelected(index),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              selected
                                                  ? item.selectedIcon
                                                  : item.icon,
                                              size: 24,
                                              color: _iconColor(
                                                isDark: isDark,
                                                selected: selected,
                                              ),
                                            ),
                                            if (item.label != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item.label!,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: _iconColor(
                                                    isDark: isDark,
                                                    selected: selected,
                                                  ),
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _iconColor({required bool isDark, required bool selected}) {
    if (selected) {
      return isDark ? Colors.white : AppColors.referencePrimary;
    }
    return isDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.textSecondary.withValues(alpha: 0.85);
  }
}

class LiquidNavItem {
  const LiquidNavItem({
    required this.icon,
    required this.selectedIcon,
    this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String? label;
}

class _SelectionOrb extends StatelessWidget {
  const _SelectionOrb({required this.isDark});

  final bool isDark;

  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.14),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF8F5FF)],
              ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B3B8C)
                .withValues(alpha: isDark ? 0.20 : 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _TripleBubbleClipper extends CustomClipper<Path> {
  _TripleBubbleClipper({required this.tabCount});

  final int tabCount;

  @override
  Path getClip(Size size) => _BubbleNavGeometry.bubblePath(size, tabCount);

  @override
  bool shouldReclip(covariant _TripleBubbleClipper oldClipper) {
    return oldClipper.tabCount != tabCount;
  }
}

class _LiquidGlassNavPainter extends CustomPainter {
  const _LiquidGlassNavPainter({
    required this.isDark,
    required this.tabCount,
  });

  final bool isDark;
  final int tabCount;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _BubbleNavGeometry.bubblePath(size, tabCount);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
              ]
            : [
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.28),
              ],
      ).createShader(Offset.zero & size);
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
      12,
      true,
    );

    canvas.drawPath(path, fill);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.45 : 0.85),
          Colors.white.withValues(alpha: isDark ? 0.08 : 0.25),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, rim);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassNavPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.tabCount != tabCount;
  }
}
