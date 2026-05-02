import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_book.dart';
import '../../providers/admin_providers.dart';
import '../../providers/api_client.dart';
import '../../utils/api_error_message.dart';
import '../../utils/rich_text_codec.dart' show documentFromStoredSummary, plainTextFromStoredSummary;

/// Create (`bookId == null`) or edit existing metadata (`bookId` set).
class AdminBookEditScreen extends ConsumerStatefulWidget {
  const AdminBookEditScreen({super.key, this.bookId, this.initialBook});

  final String? bookId;
  final AdminBook? initialBook;

  bool get isNew => bookId == null;

  @override
  ConsumerState<AdminBookEditScreen> createState() =>
      _AdminBookEditScreenState();
}

class _AdminBookEditScreenState extends ConsumerState<AdminBookEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _author = TextEditingController();
  final _language = TextEditingController(text: 'am');
  final _scriptTags = TextEditingController();
  final _tagSlugs = TextEditingController();
  List<AdminDraftChapter> _chaptersDraft = const [];
  String _visibility = 'hidden';
  bool _busy = false;
  String? _error;
  bool _loaded = false;
  bool _loadRequested = false;
  bool _dirty = false;
  Uint8List? _pendingCoverBytes;
  String? _pendingCoverMime;
  String? _serverCoverGetUrl;
  bool _clearCoverOnSave = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onTitleChanged);
    _primeFromBook(widget.initialBook);
    if (widget.isNew) _loaded = true;
  }

  void _onTitleChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _primeFromBook(AdminBook? b) {
    if (b == null) return;
    _title.text = b.title;
    _subtitle.text = b.subtitle ?? '';
    _author.text = b.authorCompiler ?? '';
    _language.text = b.primaryLanguage;
    _scriptTags.text = b.scriptTags.join(', ');
    _chaptersDraft = b.chaptersDraft;
    _visibility = b.catalogVisibility;
    _serverCoverGetUrl = b.coverGetUrl;
    _pendingCoverBytes = null;
    _pendingCoverMime = null;
    _clearCoverOnSave = false;
    _loaded = true;
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.isNew &&
        !_loaded &&
        widget.initialBook == null &&
        !_loadRequested) {
      _loadRequested = true;
      _loadById();
    }
  }

  Future<void> _loadById() async {
    final id = widget.bookId;
    if (id == null) return;
    setState(() => _error = null);
    try {
      final b = await fetchAdminBookByDio(ref.read(apiDioProvider), id);
      if (!mounted) return;
      if (b != null) {
        setState(() {
          _primeFromBook(b);
          _loaded = true;
        });
      } else {
        setState(() {
          _error = AppLocalizations.of(context).bookNotFound;
          _loaded = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _title.removeListener(_onTitleChanged);
    _title.dispose();
    _subtitle.dispose();
    _author.dispose();
    _language.dispose();
    _scriptTags.dispose();
    _tagSlugs.dispose();
    super.dispose();
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingCoverBytes = bytes;
      _pendingCoverMime = _mimeFromPath(x.path);
      _clearCoverOnSave = false;
      _dirty = true;
    });
  }

  void _clearCover() {
    setState(() {
      _pendingCoverBytes = null;
      _pendingCoverMime = null;
      _clearCoverOnSave = true;
      _dirty = true;
    });
  }

  Future<void> _uploadCoverForBook(Dio api, String bookId) async {
    if (_pendingCoverBytes != null && _pendingCoverBytes!.isNotEmpty) {
      final mime = _pendingCoverMime ?? 'image/jpeg';
      final pres = await api.post<Map<String, dynamic>>(
        'admin/books/$bookId/cover/presign',
        data: {'content_type': mime},
      );
      final data = pres.data;
      if (data == null) throw StateError('Empty presign response');
      final putUrl = data['put_url'] as String?;
      final objectKey = data['object_key'] as String?;
      if (putUrl == null || objectKey == null) {
        throw StateError('Invalid presign response');
      }
      final plain = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      await plain.put<dynamic>(
        putUrl,
        data: _pendingCoverBytes,
        options: Options(headers: {'Content-Type': mime}),
      );
      await api.patch<Map<String, dynamic>>(
        'admin/books/$bookId',
        data: {'cover_object_key': objectKey},
      );
      return;
    }
    if (_clearCoverOnSave) {
      await api.patch<Map<String, dynamic>>(
        'admin/books/$bookId',
        data: {'cover_object_key': ''},
      );
    }
  }

  List<String> _splitTags(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _upsertChapter({int? index}) async {
    final editing = index != null ? _chaptersDraft[index] : null;
    final titleController = TextEditingController(text: editing?.title ?? '');
    final keyController = TextEditingController(text: editing?.chapterKey ?? '');
    final result = await showDialog<AdminDraftChapter>(
      context: context,
      builder: (ctx) {
        final d = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(index == null ? d.addChapterTitle : d.editChapterTitle),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: d.chapterTitleLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  decoration: InputDecoration(
                    labelText: d.chapterKeyFieldLabel,
                    hintText: d.chapterKeyHintExample,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(d.cancel),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final chapterKey = keyController.text.trim().isEmpty
                    ? _slugifyChapter(title.isEmpty ? 'chapter' : title)
                    : keyController.text.trim();
                Navigator.of(ctx).pop(
                  AdminDraftChapter(
                    chapterKey: chapterKey,
                    title: title.isEmpty ? d.untitledChapter : title,
                    pages: editing?.pages ?? const [],
                  ),
                );
              },
              child: Text(d.save),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _chaptersDraft = [..._chaptersDraft, result];
      } else {
        final next = [..._chaptersDraft];
        next[index] = result;
        _chaptersDraft = next;
      }
      _dirty = true;
    });
  }

  String _slugifyChapter(String value) {
    final lower = value.toLowerCase();
    final sb = StringBuffer();
    for (final ch in lower.runes) {
      final c = String.fromCharCode(ch);
      final isAlphaNum = RegExp(r'[a-z0-9]').hasMatch(c);
      if (isAlphaNum) {
        sb.write(c);
      } else if (c == ' ' || c == '-' || c == '_') {
        sb.write('-');
      }
    }
    final collapsed = sb.toString().replaceAll(RegExp(r'-+'), '-');
    return collapsed.replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _upsertPage(int chapterIndex, {int? pageIndex}) async {
    final chapter = _chaptersDraft[chapterIndex];
    final editing = pageIndex != null ? chapter.pages[pageIndex] : null;
    final initialPageNumber = editing?.pageNumber ?? (chapter.pages.length + 1);
    final result = await Navigator.of(context, rootNavigator: true)
        .push<AdminDraftPage>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _DraftPageEditorDialog(
          isNewPage: pageIndex == null,
          initialPageNumber: initialPageNumber,
          initialTitle: editing?.title ?? '',
          initialBody: editing?.body ?? '',
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      final chapters = [..._chaptersDraft];
      final pages = [...chapters[chapterIndex].pages];
      if (pageIndex == null) {
        pages.add(result);
      } else {
        pages[pageIndex] = result;
      }
      chapters[chapterIndex] = AdminDraftChapter(
        chapterKey: chapters[chapterIndex].chapterKey,
        title: chapters[chapterIndex].title,
        pages: pages,
      );
      _chaptersDraft = chapters;
      _dirty = true;
    });
  }

  void _moveChapter(int index, int step) {
    final target = index + step;
    if (target < 0 || target >= _chaptersDraft.length) return;
    setState(() {
      final next = [..._chaptersDraft];
      final item = next.removeAt(index);
      next.insert(target, item);
      _chaptersDraft = next;
      _dirty = true;
    });
  }

  void _movePage(int chapterIndex, int pageIndex, int step) {
    final pages = _chaptersDraft[chapterIndex].pages;
    final target = pageIndex + step;
    if (target < 0 || target >= pages.length) return;
    setState(() {
      final chapters = [..._chaptersDraft];
      final nextPages = [...chapters[chapterIndex].pages];
      final item = nextPages.removeAt(pageIndex);
      nextPages.insert(target, item);
      chapters[chapterIndex] = AdminDraftChapter(
        chapterKey: chapters[chapterIndex].chapterKey,
        title: chapters[chapterIndex].title,
        pages: nextPages,
      );
      _chaptersDraft = chapters;
      _dirty = true;
    });
  }

  String? _validateChaptersDraft(AppLocalizations l10n) {
    final seenKeys = <String>{};
    for (final chapter in _chaptersDraft) {
      final key = chapter.chapterKey.trim();
      if (key.isEmpty) return l10n.eachChapterNeedsKey;
      if (!seenKeys.add(key)) return l10n.duplicateChapterKey(key);
      final seenPages = <int>{};
      for (final page in chapter.pages) {
        if (page.pageNumber < 1) {
          return l10n.pageNumberMustBePositive(chapter.title);
        }
        if (!seenPages.add(page.pageNumber)) {
          return l10n.duplicatePageNumber(page.pageNumber, chapter.title);
        }
      }
    }
    return null;
  }

  Future<void> _validateDraftOnServer() async {
    final l10n = AppLocalizations.of(context)!;
    final bookId = widget.bookId;
    if (bookId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createBookFirstValidate)),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiDioProvider);
      final res = await dio.get<Map<String, dynamic>>('admin/books/$bookId/validate-draft');
      if (!mounted) return;
      final warnings = (res.data?['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      final stats = res.data?['stats'] as Map<String, dynamic>? ?? const {};
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final d = AppLocalizations.of(ctx)!;
          final ch = (stats['chapters'] as num?)?.toInt() ?? 0;
          final pg = (stats['pages'] as num?)?.toInt() ?? 0;
          final em = (stats['empty_pages'] as num?)?.toInt() ?? 0;
          return AlertDialog(
            title: Text(d.draftValidationTitle),
            content: SizedBox(
              width: 520,
              child: warnings.isEmpty
                  ? Text(d.draftValidationNoWarnings(ch, pg, em))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.draftValidationStatsLine(ch, pg, em)),
                        const SizedBox(height: 10),
                        Text(d.warningsHeading),
                        const SizedBox(height: 6),
                        ...warnings.map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• $w'),
                            )),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(d.close),
              ),
            ],
          );
        },
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageFromDioResponse(e.response?.data) ??
            e.message ??
            AppLocalizations.of(context).validationFailed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final chaptersError = _validateChaptersDraft(l10n);
    if (chaptersError != null) {
      setState(() => _error = chaptersError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiDioProvider);
      final scriptTags = _splitTags(_scriptTags.text);
      final chaptersDraftPayload =
          _chaptersDraft.map((e) => e.toJson()).toList();
      if (widget.isNew) {
        final tagSlugs = _splitTags(_tagSlugs.text);
        final res = await dio.post<Map<String, dynamic>>(
          'admin/books',
          data: {
            'title': _title.text.trim(),
            'subtitle': _subtitle.text.trim(),
            'summary': '',
            'author_compiler': _author.text.trim(),
            'primary_language':
                _language.text.trim().isEmpty ? 'am' : _language.text.trim(),
            'script_tags': scriptTags,
            'chapters_draft': chaptersDraftPayload,
            'tag_slugs': tagSlugs,
          },
        );
        final newId = res.data?['id'] as String?;
        if (newId != null) {
          await _uploadCoverForBook(dio, newId);
        }
      } else {
        final bookId = widget.bookId!;
        await dio.patch<Map<String, dynamic>>(
          'admin/books/$bookId',
          data: {
            'title': _title.text.trim(),
            'subtitle': _subtitle.text.trim(),
            'author_compiler': _author.text.trim(),
            'primary_language':
                _language.text.trim().isEmpty ? 'am' : _language.text.trim(),
            'script_tags': scriptTags,
            'chapters_draft': chaptersDraftPayload,
            'catalog_visibility': _visibility,
          },
        );
        await _uploadCoverForBook(dio, bookId);
      }
      ref.invalidate(adminBooksProvider);
      if (!mounted) return;
      setState(() => _dirty = false);
      context.pop();
    } on DioException catch (e) {
      setState(() {
        _error = messageFromDioResponse(e.response?.data) ??
            e.message ??
            l10n.saveFailed;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNew = widget.isNew;
    final trimmedTitle = _title.text.trim();
    final appBarTitle = isNew
        ? (trimmedTitle.isEmpty ? l10n.newBookAppBar : trimmedTitle)
        : (trimmedTitle.isEmpty ? l10n.editBookAppBar : trimmedTitle);
    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty || _busy) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final d = AppLocalizations.of(ctx)!;
            return AlertDialog(
              title: Text(d.discardUnsavedTitle),
              content: Text(d.discardUnsavedBodyEditor),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(d.stay),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(d.discard),
                ),
              ],
            );
          },
        );
        if (leave == true) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          appBarTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: (!isNew && !_loaded)
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.metadataSection,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(labelText: l10n.titleLabelRequired),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return l10n.titleRequired;
                    return null;
                  },
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subtitle,
                  decoration: InputDecoration(labelText: l10n.subtitleLabel),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.thumbnailCover,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 96,
                        height: 128,
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        child: _pendingCoverBytes != null
                            ? Image.memory(
                                _pendingCoverBytes!,
                                fit: BoxFit.cover,
                              )
                            : (!_clearCoverOnSave &&
                                    _serverCoverGetUrl != null &&
                                    _serverCoverGetUrl!.isNotEmpty)
                                ? Image.network(
                                    _serverCoverGetUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_outlined, size: 36),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickCoverImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(l10n.chooseImage),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: (_pendingCoverBytes != null ||
                                    (!_clearCoverOnSave &&
                                        (_serverCoverGetUrl != null &&
                                            _serverCoverGetUrl!.isNotEmpty)))
                                ? _clearCover
                                : null,
                            child: Text(l10n.removeCover),
                          ),
                          Text(
                            l10n.coverFormatHelp,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _author,
                  decoration: InputDecoration(labelText: l10n.authorCompilerLabel),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _language,
                  decoration: InputDecoration(
                    labelText: l10n.primaryLanguageCodeLabel,
                    hintText: 'am',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return l10n.languageCodeRequired;
                    }
                    return null;
                  },
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scriptTags,
                  decoration: InputDecoration(
                    labelText: l10n.scriptTagsLabel,
                    hintText: l10n.commaSeparated,
                  ),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.chaptersPagesSection,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (!isNew)
                      TextButton.icon(
                        onPressed: _busy ? null : _validateDraftOnServer,
                        icon: const Icon(Icons.rule_folder_outlined),
                        label: Text(l10n.validateDraft),
                      ),
                    TextButton.icon(
                      onPressed: () => _upsertChapter(),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addChapter),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_chaptersDraft.isEmpty)
                  Text(
                    l10n.noChaptersYetHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  ..._chaptersDraft.asMap().entries.map((entry) {
                    final cIndex = entry.key;
                    final chapter = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ExpansionTile(
                        // Avoid a wide Row in `trailing`: ListTile often gives it
                        // zero width → zero-size IconButtons → hit-test / mouse_tracker
                        // errors on desktop/web.
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              chapter.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.chapterKeyPageCount(
                                chapter.chapterKey,
                                chapter.pages.length,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: l10n.moveUpTooltip,
                                    onPressed: cIndex == 0
                                        ? null
                                        : () => _moveChapter(cIndex, -1),
                                    icon: const Icon(Icons.arrow_upward_rounded),
                                  ),
                                  IconButton(
                                    tooltip: l10n.moveDownTooltip,
                                    onPressed: cIndex ==
                                            _chaptersDraft.length - 1
                                        ? null
                                        : () => _moveChapter(cIndex, 1),
                                    icon:
                                        const Icon(Icons.arrow_downward_rounded),
                                  ),
                                  IconButton(
                                    tooltip: l10n.addPageTooltip,
                                    onPressed: () => _upsertPage(cIndex),
                                    icon: const Icon(Icons.note_add_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.editChapterTooltip,
                                    onPressed: () =>
                                        _upsertChapter(index: cIndex),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.deleteChapterTooltip,
                                    onPressed: () {
                                      setState(() {
                                        final next = [..._chaptersDraft]
                                          ..removeAt(cIndex);
                                        _chaptersDraft = next;
                                        _dirty = true;
                                      });
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        children: [
                          if (chapter.pages.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(l10n.noPagesYet),
                              ),
                            ),
                          ...chapter.pages.asMap().entries.map((pageEntry) {
                            final pIndex = pageEntry.key;
                            final page = pageEntry.value;
                            return ListTile(
                              title: Text(
                                l10n.pageListTitle(page.pageNumber, page.title),
                              ),
                              isThreeLine: true,
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    plainTextFromStoredSummary(page.body),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: l10n.moveUpTooltip,
                                          onPressed: pIndex == 0
                                              ? null
                                              : () => _movePage(
                                                    cIndex,
                                                    pIndex,
                                                    -1,
                                                  ),
                                          icon: const Icon(
                                            Icons.arrow_upward_rounded,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: l10n.moveDownTooltip,
                                          onPressed: pIndex ==
                                                  chapter.pages.length - 1
                                              ? null
                                              : () => _movePage(
                                                    cIndex,
                                                    pIndex,
                                                    1,
                                                  ),
                                          icon: const Icon(
                                            Icons.arrow_downward_rounded,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: l10n.editPageTooltip,
                                          onPressed: () => _upsertPage(
                                            cIndex,
                                            pageIndex: pIndex,
                                          ),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: l10n.deletePageTooltip,
                                          onPressed: () {
                                            setState(() {
                                              final chapters = [
                                                ..._chaptersDraft
                                              ];
                                              final pages = [
                                                ...chapters[cIndex].pages
                                              ]..removeAt(pIndex);
                                              chapters[cIndex] =
                                                  AdminDraftChapter(
                                                chapterKey: chapters[cIndex]
                                                    .chapterKey,
                                                title:
                                                    chapters[cIndex].title,
                                                pages: pages,
                                              );
                                              _chaptersDraft = chapters;
                                              _dirty = true;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                if (isNew) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tagSlugs,
                    decoration: InputDecoration(
                      labelText: l10n.tagSlugsCreateOnlyLabel,
                      hintText: l10n.tagSlugsHint,
                    ),
                    onChanged: (_) => _markDirty(),
                  ),
                ],
                if (!isNew) ...[
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.catalogVisibilityLabel,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _visibility,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'hidden',
                            child: Text(l10n.visibilityHidden),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text(l10n.visibilityPublished),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _visibility = v);
                            _markDirty();
                          }
                        },
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy || (!_loaded && !isNew) ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isNew ? l10n.create : l10n.saveChanges),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

class _DraftPageEditorDialog extends StatefulWidget {
  const _DraftPageEditorDialog({
    required this.isNewPage,
    required this.initialPageNumber,
    required this.initialTitle,
    required this.initialBody,
  });

  final bool isNewPage;
  final int initialPageNumber;
  final String initialTitle;
  final String initialBody;

  @override
  State<_DraftPageEditorDialog> createState() => _DraftPageEditorDialogState();
}

class _DraftPageEditorDialogState extends State<_DraftPageEditorDialog> {
  late final TextEditingController _pageNumber;
  late final TextEditingController _title;
  late final QuillController _bodyQuill;
  /// Full Quill toolbar lives in the bottom sheet; collapsed by default for typing space.
  bool _toolbarExpanded = false;

  @override
  void initState() {
    super.initState();
    _pageNumber = TextEditingController(text: '${widget.initialPageNumber}');
    _title = TextEditingController(text: widget.initialTitle);
    _bodyQuill = QuillController.basic();
    final richDoc = documentFromStoredSummary(widget.initialBody);
    if (richDoc != null) {
      _bodyQuill.document = richDoc;
    } else {
      final normalized =
          widget.initialBody.replaceAll('\uFFFC', '').trimRight();
      final next = normalized.isEmpty ? '\n' : '$normalized\n';
      final len = _bodyQuill.document.length;
      _bodyQuill.replaceText(
        0,
        len - 1,
        next,
        TextSelection.collapsed(offset: next.length - 1),
      );
    }
  }

  @override
  void dispose() {
    _pageNumber.dispose();
    _title.dispose();
    _bodyQuill.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    final l10n = AppLocalizations.of(context)!;
    final pageNumber = int.tryParse(_pageNumber.text.trim()) ?? 1;
    final n = pageNumber < 1 ? 1 : pageNumber;
    final t = _title.text.trim();
    final body = jsonEncode(_bodyQuill.document.toDelta().toJson());
    Navigator.of(context).pop(
      AdminDraftPage(
        pageNumber: n,
        title: t.isEmpty ? l10n.pageTitleFallback(n) : t,
        body: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          widget.isNewPage ? l10n.addPageTooltip : l10n.editPageTitle,
        ),
        actions: [
          IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _pageNumber,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: l10n.pageNumberFieldLabel),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _title,
                      decoration:
                          InputDecoration(labelText: l10n.pageTitleFieldLabel),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.pageContentHeading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              sliver: SliverFillRemaining(
                hasScrollBody: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: QuillEditor.basic(
                      controller: _bodyQuill,
                      config: QuillEditorConfig(
                        placeholder: l10n.pageEditorPlaceholder,
                        expands: false,
                        scrollable: true,
                        padding: const EdgeInsets.all(12),
                        embedBuilders: const [],
                        unknownEmbedBuilder:
                            const _UnsupportedEmbedBuilder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          elevation: 10,
          color: theme.colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.55),
                child: InkWell(
                  onTap: () =>
                      setState(() => _toolbarExpanded = !_toolbarExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _toolbarExpanded
                                ? l10n.pageEditorFormattingHide
                                : l10n.pageEditorFormattingToggle,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Icon(
                          _toolbarExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _toolbarExpanded
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: QuillSimpleToolbar(
                          controller: _bodyQuill,
                          config: const QuillSimpleToolbarConfig(
                            multiRowsDisplay: true,
                            embedButtons: [],
                            showUndo: true,
                            showRedo: true,
                            showBoldButton: true,
                            showItalicButton: true,
                            showUnderLineButton: true,
                            showStrikeThrough: true,
                            showHeaderStyle: false,
                            showListBullets: true,
                            showListNumbers: true,
                            showQuote: true,
                            showLink: true,
                            showCodeBlock: true,
                            showAlignmentButtons: true,
                            showSubscript: false,
                            showSuperscript: false,
                            showSearchButton: false,
                            showFontFamily: false,
                            showFontSize: false,
                            showDirection: false,
                            showInlineCode: true,
                            showIndent: true,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveAndPop,
                    child: Text(l10n.save),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsupportedEmbedBuilder extends EmbedBuilder {
  const _UnsupportedEmbedBuilder();

  @override
  String get key => 'unsupported';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 16),
          const SizedBox(width: 8),
          Text(l10n.unsupportedEmbeddedContent),
        ],
      ),
    );
  }
}
