import 'package:flutter/material.dart';

/// Counts case-insensitive occurrences of [query] inside [text].
int countQueryOccurrences(String text, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return 0;
  final lowerText = text.toLowerCase();
  final lowerQuery = trimmed.toLowerCase();
  if (lowerQuery.isEmpty) return 0;

  var count = 0;
  var start = 0;
  while (start < lowerText.length) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) break;
    count++;
    start = index + lowerQuery.length;
  }
  return count;
}

/// Builds [TextSpan]s that highlight every case-insensitive occurrence of [query].
List<TextSpan> buildSearchHighlightSpans({
  required String text,
  required String query,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
  TextStyle? activeHighlightStyle,
  int? activeOccurrenceIndex,
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = trimmed.toLowerCase();
  if (lowerQuery.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final spans = <TextSpan>[];
  var start = 0;
  var occurrence = 0;

  while (start < text.length) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }
    final end = index + lowerQuery.length;
    final isActive =
        activeOccurrenceIndex != null && occurrence == activeOccurrenceIndex;
    spans.add(
      TextSpan(
        text: text.substring(index, end),
        style: isActive && activeHighlightStyle != null
            ? activeHighlightStyle
            : highlightStyle,
      ),
    );
    occurrence++;
    start = end;
  }

  return spans;
}

/// Reader text with inline highlights for the current find query.
class HighlightedSearchText extends StatelessWidget {
  const HighlightedSearchText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.highlightColor,
    this.activeHighlightColor,
    this.activeOccurrenceIndex,
  });

  final String text;
  final String query;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? highlightColor;
  final Color? activeHighlightColor;
  final int? activeOccurrenceIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style.color ?? theme.colorScheme.onSurface;
    final fill = highlightColor ??
        theme.colorScheme.tertiaryContainer.withValues(alpha: 0.92);
    final activeFill = activeHighlightColor ??
        theme.colorScheme.primaryContainer.withValues(alpha: 0.98);

    final highlightStyle = style.copyWith(
      backgroundColor: fill,
      color: base,
      fontWeight: FontWeight.w600,
    );
    final activeStyle = style.copyWith(
      backgroundColor: activeFill,
      color: base,
      fontWeight: FontWeight.w700,
    );

    return Text.rich(
      TextSpan(
        children: buildSearchHighlightSpans(
          text: text,
          query: query,
          baseStyle: style,
          highlightStyle: highlightStyle,
          activeHighlightStyle: activeStyle,
          activeOccurrenceIndex: activeOccurrenceIndex,
        ),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
