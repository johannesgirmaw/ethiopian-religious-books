import 'package:flutter/material.dart';

import '../../layout/app_layout_scope.dart';
import '../../design/web_tokens.dart';

/// Constrains reader text to a comfortable column width on web.
Widget webConstrainReaderContent(BuildContext context, Widget child) {
  if (!useWebShell(context)) return child;
  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: WebTokens.readerColumnWidth),
      child: child,
    ),
  );
}

/// Horizontal padding for reader content on web vs mobile.
double webReaderHorizontalPadding(BuildContext context) {
  if (!useWebShell(context)) return 16;
  return 32;
}

/// Top chrome height on web reader.
double webReaderTopInset(BuildContext context, bool showChrome) {
  if (!useWebShell(context)) return showChrome ? 64 : 20;
  return showChrome ? 56 : 24;
}
