import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/rich_text_codec.dart';

class StoredRichTextView extends StatelessWidget {
  const StoredRichTextView({
    super.key,
    required this.raw,
    this.fallbackStyle,
  });

  final String raw;
  final TextStyle? fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final doc = documentFromStoredSummary(raw);
    if (doc == null) {
      return Text(
        plainTextFromStoredSummary(raw),
        style: fallbackStyle,
      );
    }
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      config: const QuillControllerConfig(),
    );
    return QuillEditor.basic(
      controller: controller,
      config: const QuillEditorConfig(
        padding: EdgeInsets.zero,
        showCursor: false,
        expands: false,
        scrollable: false,
        embedBuilders: [],
        unknownEmbedBuilder: _UnknownEmbedBuilder(),
      ),
    );
  }
}

class _UnknownEmbedBuilder extends EmbedBuilder {
  const _UnknownEmbedBuilder();

  @override
  String get key => 'unknown';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return const SizedBox.shrink();
  }
}
