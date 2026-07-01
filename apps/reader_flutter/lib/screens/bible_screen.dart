import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_page_scaffold.dart';
import '../widgets/bible/bible_books_body.dart';

/// Bible book picker — route adapter. Branches web → desktop → mobile per the
/// platform rule; all three share [BibleBooksBody].
class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useWebShell(context)) {
      return const WebPageScaffold(body: BibleBooksBody());
    }
    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: BibleBooksBody());
    }
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bibleTitle)),
      body: const SafeArea(child: BibleBooksBody()),
    );
  }
}
