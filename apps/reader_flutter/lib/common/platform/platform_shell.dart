import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../../web/layout/app_layout_scope.dart';

/// True on iOS and Android native builds.
bool get isMobilePlatform {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return true;
    default:
      return false;
  }
}

/// True on macOS, Linux, and Windows native builds.
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return true;
    default:
      return false;
  }
}

/// Mobile UI: native iOS/Android, or web below the compact breakpoint.
bool useMobileShell(BuildContext context) {
  if (isMobilePlatform) return true;
  if (kIsWeb) return !useWebShell(context);
  return false;
}

/// Native desktop UI (macOS, Linux, Windows). Never true on web.
bool useDesktopShell(BuildContext context) => isDesktopPlatform;

/// Wide split auth layout: fixed brand panel + animated form column.
bool useWideAuthSplit(BuildContext context) {
  if (useDesktopShell(context)) return true;
  if (kIsWeb && useWebShell(context)) {
    return AppLayoutScope.tierOf(context) == AppLayoutTier.expanded;
  }
  return false;
}
