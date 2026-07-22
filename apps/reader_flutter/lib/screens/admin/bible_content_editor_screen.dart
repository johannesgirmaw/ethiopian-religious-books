import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bible_models.dart';
import '../../providers/bible_providers.dart';
import '../../providers/nav_visibility_providers.dart';
import '../../providers/number_system_provider.dart';
import '../../utils/api_error_message.dart';
import '../../utils/geez_numerals.dart';
import '../../widgets/app_state_view.dart';

String _errorText(Object e) {
  if (e is DioException) {
    return messageFromDioResponse(e.response?.data) ?? e.message ?? '$e';
  }
  return '$e';
}

/// Standalone Bible content editor (pushed as its own screen, e.g. from the
/// mobile book editor). Wraps [BibleContentWorkspace] in a Scaffold.
class BibleContentEditorScreen extends StatelessWidget {
  const BibleContentEditorScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  final String bookId;
  final String bookTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(bookTitle.isEmpty ? l10n.adminBibleContentTitle : bookTitle),
      ),
      body: BibleContentWorkspace(bookId: bookId),
    );
  }
}

/// Embeddable chapter/section/verse manager — responsive to its own width:
/// a master–detail workspace when wide, a chapter list that pushes a full-screen
/// editor when narrow. Used inline in the desktop book editor's right pane and
/// inside [BibleContentEditorScreen].
class BibleContentWorkspace extends ConsumerStatefulWidget {
  const BibleContentWorkspace({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BibleContentWorkspace> createState() =>
      _BibleContentWorkspaceState();
}

class _BibleContentWorkspaceState extends ConsumerState<BibleContentWorkspace> {
  int _nextChapter(BibleBookIndex index) => index.chapters.isEmpty
      ? 1
      : index.chapters.map((c) => c.chapter).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> _pushEditor(int chapter, {required bool isNew}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ChapterEditorScreen(
          bookId: widget.bookId,
          chapter: chapter,
          isNew: isNew,
        ),
      ),
    );
    if (saved == true) ref.invalidate(adminBibleBookIndexProvider(widget.bookId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final indexAsync = ref.watch(adminBibleBookIndexProvider(widget.bookId));
    return indexAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppStateView(
        title: l10n.adminBibleContentTitle,
        message: _errorText(e),
        icon: Icons.menu_book_outlined,
        actionLabel: l10n.retry,
        onAction: () =>
            ref.invalidate(adminBibleBookIndexProvider(widget.bookId)),
      ),
      data: (index) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.bibleChapters,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  // The app's FilledButton theme is full-width (Size.fromHeight);
                  // override so this in-row button sizes to its content and
                  // never demands infinite width.
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => _pushEditor(_nextChapter(index), isNew: true),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.adminAddChapter),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: index.chapters.isEmpty
                ? Center(child: Text(l10n.adminNoChaptersYet))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: index.chapters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final ch = index.chapters[i];
                      return _ChapterTile(
                        info: ch,
                        onTap: () => _pushEditor(ch.chapter, isNew: false),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.info, required this.onTap});

  final BibleChapterInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            '${info.chapter}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDeep,
            ),
          ),
        ),
        title: Text(l10n.adminChapterLabel(info.chapter)),
        subtitle: Text(l10n.adminVersesCount(info.verseCount)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen wrapper (narrow)
// ---------------------------------------------------------------------------
class _ChapterEditorScreen extends ConsumerWidget {
  const _ChapterEditorScreen({
    required this.bookId,
    required this.chapter,
    required this.isNew,
  });

  final String bookId;
  final int chapter;
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.adminChapterLabel(chapter))),
      body: _ChapterEditorBody(
        bookId: bookId,
        chapter: chapter,
        isNew: isNew,
        onSaved: () => Navigator.of(context).pop(true),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The section/verse editor body (shared by pane + full-screen)
// ---------------------------------------------------------------------------
class _SectionDraft {
  _SectionDraft({String title = ''})
      : titleCtrl = TextEditingController(text: title);
  final TextEditingController titleCtrl;
  final List<_VerseDraft> verses = [];

  void dispose() {
    titleCtrl.dispose();
    for (final v in verses) {
      v.dispose();
    }
  }
}

class _VerseDraft {
  _VerseDraft({int? number, String text = ''})
      : numberCtrl = TextEditingController(text: number?.toString() ?? ''),
        textCtrl = TextEditingController(text: text);
  final TextEditingController numberCtrl;
  final TextEditingController textCtrl;

  void dispose() {
    numberCtrl.dispose();
    textCtrl.dispose();
  }
}

class _ChapterEditorBody extends ConsumerStatefulWidget {
  const _ChapterEditorBody({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.isNew,
    required this.onSaved,
    this.onDirtyChanged,
  });

  final String bookId;
  final int chapter;
  final bool isNew;
  final VoidCallback onSaved;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<_ChapterEditorBody> createState() => _ChapterEditorBodyState();
}

class _ChapterEditorBodyState extends ConsumerState<_ChapterEditorBody> {
  final List<_SectionDraft> _sections = [];
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _markDirty() {
    if (!_dirty) {
      _dirty = true;
      widget.onDirtyChanged?.call(true);
    }
  }

  Future<void> _init() async {
    if (widget.isNew) {
      _sections.add(_SectionDraft()..verses.add(_VerseDraft(number: 1)));
      setState(() => _loaded = true);
      return;
    }
    try {
      final chapter = await ref.read(
        adminBibleChapterProvider((bookId: widget.bookId, chapter: widget.chapter))
            .future,
      );
      _populate(chapter);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _populate(BibleChapter chapter) {
    final byOrdinal = <int, _SectionDraft>{};
    for (final s in chapter.sections) {
      byOrdinal[s.ordinal] = _SectionDraft(title: s.title);
    }
    _SectionDraft fallback() =>
        byOrdinal.putIfAbsent(-1, () => _SectionDraft());
    for (final v in chapter.verses) {
      final draft = v.sectionOrdinal != null
          ? (byOrdinal[v.sectionOrdinal!] ??= _SectionDraft())
          : fallback();
      draft.verses.add(_VerseDraft(number: v.verse, text: v.text));
    }
    final ordered = byOrdinal.keys.toList()..sort();
    for (final k in ordered) {
      _sections.add(byOrdinal[k]!);
    }
    if (_sections.isEmpty) {
      _sections.add(_SectionDraft()..verses.add(_VerseDraft(number: 1)));
    }
  }

  @override
  void dispose() {
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  int get _verseCount =>
      _sections.fold(0, (sum, s) => sum + s.verses.length);

  int _nextVerseNumber() {
    var max = 0;
    for (final s in _sections) {
      for (final v in s.verses) {
        final n = int.tryParse(v.numberCtrl.text) ?? 0;
        if (n > max) max = n;
      }
    }
    return max + 1;
  }

  void _addSection() {
    setState(() =>
        _sections.add(_SectionDraft()..verses.add(_VerseDraft(number: _nextVerseNumber()))));
    _markDirty();
  }

  void _removeSection(int i) {
    setState(() => _sections.removeAt(i).dispose());
    _markDirty();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final sections = <Map<String, dynamic>>[];
    for (final s in _sections) {
      final verses = <Map<String, dynamic>>[];
      for (final v in s.verses) {
        final number = int.tryParse(v.numberCtrl.text.trim());
        if (number == null || number <= 0) continue;
        verses.add({'verse': number, 'text': v.textCtrl.text.trim()});
      }
      if (verses.isEmpty) continue;
      sections.add({'title': s.titleCtrl.text.trim(), 'verses': verses});
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(bibleRepositoryProvider)
          .saveChapter(widget.bookId, widget.chapter, sections);
      ref.invalidate(
        adminBibleChapterProvider((bookId: widget.bookId, chapter: widget.chapter)),
      );
      // Chapters just landed — re-check whether the Bible nav entry can show.
      ref.invalidate(hasBibleContentProvider);
      _dirty = false;
      widget.onDirtyChanged?.call(false);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminChapterSaved)));
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final geez = ref.watch(useGeezNumeralsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorHeader(
          title: l10n.adminChapterLabel(widget.chapter),
          verseCount: _verseCount,
          dirty: _dirty,
          saving: _saving,
          onSave: _save,
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: AppColors.errorSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.errorText)),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _sections.length; i++)
                        _SectionCard(
                          key: ObjectKey(_sections[i]),
                          index: i,
                          section: _sections[i],
                          geez: geez,
                          canRemove: _sections.length > 1,
                          onRemove: () => _removeSection(i),
                          onAddVerse: () {
                            setState(() => _sections[i]
                                .verses
                                .add(_VerseDraft(number: _nextVerseNumber())));
                            _markDirty();
                          },
                          onChanged: () {
                            setState(() {});
                            _markDirty();
                          },
                        ),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _addSection,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.adminAddSection),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.title,
    required this.verseCount,
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final String title;
  final int verseCount;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (dirty) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dirty
                      ? l10n.adminUnsavedChanges
                      : l10n.adminVersesCount(verseCount),
                  style: TextStyle(
                    fontSize: 12,
                    color: dirty ? AppColors.accent : AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            // In-row button: override the full-width theme so it sizes to
            // content (a non-flex Row child is measured with unbounded width).
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.index,
    required this.section,
    required this.geez,
    required this.canRemove,
    required this.onRemove,
    required this.onAddVerse,
    required this.onChanged,
  });

  final int index;
  final _SectionDraft section;
  final bool geez;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onAddVerse;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.listRow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Container(
            color: AppColors.surfaceSoft.withValues(alpha: 0.5),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    l10n.adminSectionLabel(index + 1),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: section.titleCtrl,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDeep,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: l10n.adminSectionTitle,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.errorText),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Verses
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Column(
              children: [
                for (var i = 0; i < section.verses.length; i++)
                  _VerseRow(
                    verse: section.verses[i],
                    geez: geez,
                    canRemove: section.verses.length > 1,
                    onRemove: () {
                      section.verses.removeAt(i).dispose();
                      onChanged();
                    },
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: TextButton.icon(
                onPressed: onAddVerse,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.adminAddVerse),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({
    required this.verse,
    required this.geez,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _VerseDraft verse;
  final bool geez;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final n = int.tryParse(verse.numberCtrl.text);
    final geezHint = geez && n != null && n > 0 ? toGeezNumeral(n) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: TextField(
              controller: verse.numberCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.adminVerseNumberLabel,
                helperText: geezHint,
                helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                helperMaxLines: 1,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: verse.textCtrl,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(height: 1.5, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.adminVerseTextLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(10),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textTertiary,
            onPressed: canRemove ? onRemove : null,
          ),
        ],
      ),
    );
  }
}
