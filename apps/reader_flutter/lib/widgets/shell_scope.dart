import 'package:flutter/material.dart';

class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  static VoidCallback openDrawerOf(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ShellScope not found above this widget');
    return scope!.openDrawer;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) {
    return openDrawer != oldWidget.openDrawer;
  }
}
