import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/form_draft_controller.dart';

class QuickNoteSheet extends StatefulWidget {
  const QuickNoteSheet({super.key, required this.draftKey});

  final String draftKey;

  @override
  State<QuickNoteSheet> createState() => _QuickNoteSheetState();
}

class _QuickNoteSheetState extends State<QuickNoteSheet> {
  late final TextEditingController _controller;
  late final FormDraftController _draft;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _draft = FormDraftController(
      draftKey: widget.draftKey,
      capture: () => {'body': _controller.text},
      restore: (data) {
        _controller.text = data['body'] as String? ?? '';
      },
      isEmpty: (data) => (data['body'] as String? ?? '').trim().isEmpty,
    );
    _controller.addListener(_draft.onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restored = await _draft.restoreIfPresent();
      if (!mounted || !restored) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
    });
  }

  @override
  void dispose() {
    unawaited(_draft.persistNow());
    _controller.removeListener(_draft.onChanged);
    _controller.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      await _draft.persistNow();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    await _draft.clear();
    if (!mounted) return;
    Navigator.of(context).pop(body);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.quickNoteLabel,
                hintText: l10n.quickNoteHint,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _save,
                child: Text(l10n.saveNote),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
