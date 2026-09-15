import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';

/// Perspective book stack for the desktop auth brand pane.
class DesktopAuthBookStack extends StatefulWidget {
  const DesktopAuthBookStack({super.key});

  @override
  State<DesktopAuthBookStack> createState() => _DesktopAuthBookStackState();
}

class _DesktopAuthBookStackState extends State<DesktopAuthBookStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  Offset _pointer = Offset.zero;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pointer = Offset.zero;
      }),
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final local = box.globalToLocal(event.position);
        setState(() {
          _pointer = Offset(
            (local.dx / box.size.width) - 0.5,
            (local.dy / box.size.height) - 0.5,
          );
        });
      },
      child: AnimatedBuilder(
        animation: _idle,
        builder: (context, _) {
          final idle = (Curves.easeInOut.transform(_idle.value) - 0.5) * 0.08;
          final rx = _hovering ? -_pointer.dy * 0.16 : 0.07;
          final ry = _hovering ? _pointer.dx * 0.22 : -0.20 + idle;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(rx)
              ..rotateY(ry),
            child: const SizedBox(
              height: 268,
              width: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _AuthVolume(
                    offset: Offset(-70, 18),
                    yaw: -0.34,
                    color: AppColors.primaryMid,
                    deep: AppColors.primaryDeep,
                  ),
                  _AuthVolume(
                    offset: Offset(74, 16),
                    yaw: 0.30,
                    color: AppColors.primary,
                    deep: AppColors.primaryDeep,
                  ),
                  _AuthVolume(
                    offset: Offset(0, -4),
                    yaw: -0.05,
                    color: AppColors.primaryMid,
                    deep: AppColors.primary,
                    front: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthVolume extends StatelessWidget {
  const _AuthVolume({
    required this.offset,
    required this.yaw,
    required this.color,
    required this.deep,
    this.front = false,
  });

  final Offset offset;
  final double yaw;
  final Color color;
  final Color deep;
  final bool front;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(yaw),
        child: Container(
          width: front ? 132 : 120,
          height: front ? 186 : 168,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              bottomLeft: Radius.circular(3),
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, deep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDeep.withValues(
                  alpha: front ? 0.30 : 0.20,
                ),
                blurRadius: front ? 28 : 20,
                offset: const Offset(12, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 6,
                      width: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
