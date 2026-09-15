import 'dart:async';
import 'dart:html' as html;

StreamSubscription<html.Event>? _contextMenuSub;
StreamSubscription<html.Event>? _copySub;
StreamSubscription<html.Event>? _cutSub;

/// Blocks copy and right-click on the page while a protected reader is open.
void enableWebContentGuards(bool enabled) {
  if (enabled) {
    _contextMenuSub ??= html.document.onContextMenu.listen(_preventDefault);
    _copySub ??= html.document.onCopy.listen(_preventDefault);
    _cutSub ??= html.document.onCut.listen(_preventDefault);
    html.document.body?.style.setProperty('user-select', 'none');
    html.document.body?.style.setProperty('-webkit-user-select', 'none');
    return;
  }

  _contextMenuSub?.cancel();
  _copySub?.cancel();
  _cutSub?.cancel();
  _contextMenuSub = null;
  _copySub = null;
  _cutSub = null;
  html.document.body?.style.removeProperty('user-select');
  html.document.body?.style.removeProperty('-webkit-user-select');
}

void _preventDefault(html.Event event) {
  event.preventDefault();
}
