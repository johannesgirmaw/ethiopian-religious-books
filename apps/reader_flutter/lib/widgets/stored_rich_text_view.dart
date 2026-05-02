import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/rich_text_codec.dart';

class StoredRichTextView extends StatelessWidget {
  const StoredRichTextView({
    super.key,
    required this.raw,
    this.fallbackStyle,
    /// When set, merged into Quill [DefaultStyles] so read-only views match surrounding typography.
    this.paragraphStyle,
  });

  final String raw;
  final TextStyle? fallbackStyle;
  final TextStyle? paragraphStyle;

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
    final customStyles = paragraphStyle == null
        ? null
        : DefaultStyles.getInstance(context).merge(
            DefaultStyles(
              paragraph: DefaultTextBlockStyle(
                paragraphStyle!,
                const HorizontalSpacing(0, 0),
                VerticalSpacing.zero,
                VerticalSpacing.zero,
                null,
              ),
              lists: DefaultListBlockStyle(
                paragraphStyle!,
                const HorizontalSpacing(0, 0),
                const VerticalSpacing(6, 0),
                const VerticalSpacing(0, 6),
                null,
                null,
              ),
              quote: DefaultTextBlockStyle(
                paragraphStyle!,
                const HorizontalSpacing(0, 0),
                VerticalSpacing.zero,
                VerticalSpacing.zero,
                null,
              ),
              code: DefaultTextBlockStyle(
                paragraphStyle!,
                const HorizontalSpacing(0, 0),
                VerticalSpacing.zero,
                VerticalSpacing.zero,
                null,
              ),
            ),
          );
    return QuillEditor.basic(
      controller: controller,
      config: QuillEditorConfig(
        padding: EdgeInsets.zero,
        showCursor: false,
        expands: false,
        scrollable: false,
        embedBuilders: const [],
        unknownEmbedBuilder: const _UnknownEmbedBuilder(),
        customStyles: customStyles,
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
