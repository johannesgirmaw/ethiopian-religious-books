import 'package:flutter/material.dart';

import '../../design/desktop_tokens.dart';
import '../../layout/desktop_content_frame.dart';

/// Standard page wrapper for desktop shell routes.
class DesktopPageScaffold extends StatelessWidget {
  const DesktopPageScaffold({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesktopTokens.canvasBg,
      child: SizedBox.expand(
        child: DesktopContentFrame(child: body),
      ),
    );
  }
}
