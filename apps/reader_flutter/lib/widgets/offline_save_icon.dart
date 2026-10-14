import 'package:flutter/material.dart';

/// Download icon, or a spinning reload icon while an offline save is running.
class OfflineSaveIcon extends StatelessWidget {
  const OfflineSaveIcon({super.key, required this.saving, this.size = 18});

  final bool saving;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!saving) return Icon(Icons.download_outlined, size: size);
    return _ReloadSpin(size: size);
  }
}

class _ReloadSpin extends StatefulWidget {
  const _ReloadSpin({required this.size});

  final double size;

  @override
  State<_ReloadSpin> createState() => _ReloadSpinState();
}

class _ReloadSpinState extends State<_ReloadSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.autorenew_rounded, size: widget.size),
    );
  }
}
