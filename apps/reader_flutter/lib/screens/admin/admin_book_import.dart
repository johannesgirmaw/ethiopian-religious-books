import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/admin_providers.dart';
import '../../providers/api_client.dart';
import '../../utils/api_error_message.dart';
import 'import_mode_picker.dart';

/// The user's chosen detection strategy from the import dialog.
class _ImportChoice {
  _ImportChoice(this.mode, this.pattern, this.marker);
  final String mode;
  final String? pattern;
  final String? marker;
}

/// Lets the admin pick a Word (.docx) file, choose how it should be split into
/// chapters (with a live preview of each strategy), imports it into a new draft
/// book, then opens the editor to review before publishing. Shared by the
/// mobile/web/desktop admin book screens.
Future<void> importBookFromDocxFlow({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final dio = ref.read(apiDioProvider);

  void snack(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));

  // 1) Pick the file.
  FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'doc'],
      withData: true, // required so bytes are available on web
    );
  } catch (_) {
    snack(l10n.importDocxFailed);
    return;
  }
  if (picked == null || picked.files.isEmpty) return; // cancelled

  final file = picked.files.first;

  // 2) Legacy .doc guard — reject before uploading.
  if (file.name.toLowerCase().endsWith('.doc') &&
      !file.name.toLowerCase().endsWith('.docx')) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final d = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(d.importLegacyDocTitle),
          content: Text(d.importLegacyDocMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(d.ok),
            ),
          ],
        );
      },
    );
    return;
  }

  final bytes = file.bytes;
  if (bytes == null) {
    snack(l10n.importDocxFailed);
    return;
  }

  // 3) Scan (dry-run) to detect structure across strategies.
  if (!context.mounted) return;
  _showBlockingProgress(context, l10n.importScanning);
  ImportPreview preview;
  try {
    preview = await previewBookImportDocx(
      dio,
      bytes: bytes,
      filename: file.name,
    );
  } on DioException catch (e) {
    if (rootNavigator.canPop()) rootNavigator.pop();
    snack(messageFromDioResponse(e.response?.data) ??
        e.message ??
        l10n.importDocxFailed);
    return;
  } catch (_) {
    if (rootNavigator.canPop()) rootNavigator.pop();
    snack(l10n.importDocxFailed);
    return;
  }
  if (rootNavigator.canPop()) rootNavigator.pop(); // dismiss scanning

  // 4) Let the admin choose a strategy.
  if (!context.mounted) return;
  final choice = await showDialog<_ImportChoice>(
    context: context,
    builder: (ctx) => ImportDocxDialog(
      dio: dio,
      bytes: bytes,
      filename: file.name,
      initial: preview,
    ),
  );
  if (choice == null) return; // cancelled

  // 5) Import with the chosen strategy, then open the editor.
  if (!context.mounted) return;
  _showBlockingProgress(context, l10n.importDocxInProgress);
  try {
    final book = await importBookFromDocx(
      dio,
      bytes: bytes,
      filename: file.name,
      mode: choice.mode,
      pattern: choice.pattern,
      marker: choice.marker,
    );
    ref.invalidate(adminBooksProvider);
    if (rootNavigator.canPop()) rootNavigator.pop();
    snack(l10n.importDocxSuccess);
    router.push('/admin/books/${book.id}/edit', extra: book);
  } on DioException catch (e) {
    if (rootNavigator.canPop()) rootNavigator.pop();
    snack(messageFromDioResponse(e.response?.data) ??
        e.message ??
        l10n.importDocxFailed);
  } catch (_) {
    if (rootNavigator.canPop()) rootNavigator.pop();
    snack(l10n.importDocxFailed);
  }
}

void _showBlockingProgress(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

/// Dialog to compare detection strategies and pick one before importing.
class ImportDocxDialog extends StatefulWidget {
  const ImportDocxDialog({
    super.key,
    required this.dio,
    required this.bytes,
    required this.filename,
    required this.initial,
  });

  final Dio dio;
  final List<int> bytes;
  final String filename;
  final ImportPreview initial;

  @override
  State<ImportDocxDialog> createState() => ImportDocxDialogState();
}

class ImportDocxDialogState extends State<ImportDocxDialog> {
  late ImportPreview _preview;
  late String _mode;
  final TextEditingController _patternCtrl = TextEditingController();
  final TextEditingController _markerCtrl = TextEditingController();
  bool _rescanning = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.initial;
    _mode = 'auto';
  }

  @override
  void dispose() {
    _patternCtrl.dispose();
    _markerCtrl.dispose();
    super.dispose();
  }

  Future<void> _rescan() async {
    setState(() => _rescanning = true);
    try {
      final updated = await previewBookImportDocx(
        widget.dio,
        bytes: widget.bytes,
        filename: widget.filename,
        pattern: _patternCtrl.text,
        marker: _markerCtrl.text,
      );
      if (mounted) setState(() => _preview = updated);
    } catch (_) {
      // Keep the previous preview; the import call will surface any real error.
    } finally {
      if (mounted) setState(() => _rescanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = _preview.forMode(_mode);
    final titles = selected?.titles ?? const <String>[];

    return AlertDialog(
      title: Text(l10n.importChooseStructure),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ImportModePicker(
                modes: _preview.modes,
                selectedMode: _mode,
                onSelect: (m) => setState(() => _mode = m),
              ),
              if (_mode == 'patterns') ...[
                const SizedBox(height: 8),
                _CustomField(
                  controller: _patternCtrl,
                  label: l10n.importCustomPatternLabel,
                  hint: r'^(chapter|ምዕራፍ)\s*\d+',
                  onApply: _rescanning ? null : _rescan,
                  applyLabel: l10n.importRescan,
                ),
              ],
              if (_mode == 'marker') ...[
                const SizedBox(height: 8),
                _CustomField(
                  controller: _markerCtrl,
                  label: l10n.importCustomMarkerLabel,
                  hint: '### / <<<CHAPTER: ...>>>',
                  onApply: _rescanning ? null : _rescan,
                  applyLabel: l10n.importRescan,
                ),
              ],
              const SizedBox(height: 12),
              Text(l10n.importDetectedChaptersTitle,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              if (_rescanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DetectedChaptersList(titles: titles),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (selected == null || selected.chapters == 0)
              ? null
              : () => Navigator.pop(
                    context,
                    _ImportChoice(
                      _mode,
                      _patternCtrl.text.trim().isEmpty
                          ? null
                          : _patternCtrl.text.trim(),
                      _markerCtrl.text.trim().isEmpty
                          ? null
                          : _markerCtrl.text.trim(),
                    ),
                  ),
          child: Text(l10n.importAction),
        ),
      ],
    );
  }
}

class _CustomField extends StatelessWidget {
  const _CustomField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onApply,
    required this.applyLabel,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback? onApply;
  final String applyLabel;

  @override
  Widget build(BuildContext context) {
    // Laid out vertically (no Row/Expanded): AlertDialog wraps its content in an
    // IntrinsicWidth, and a full-width-themed button (the app theme uses
    // minimumSize: Size.fromHeight(50) → infinite min width) as a non-flex child
    // of a Row demands infinite width during intrinsic measurement and fails to
    // lay out. The button also overrides minimumSize to Size.zero for the same
    // reason. See test/admin/two_pane_unconstrained_test.dart for the pattern.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            isDense: true,
          ),
          onSubmitted: (_) => onApply?.call(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: onApply,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(applyLabel),
          ),
        ),
      ],
    );
  }
}
