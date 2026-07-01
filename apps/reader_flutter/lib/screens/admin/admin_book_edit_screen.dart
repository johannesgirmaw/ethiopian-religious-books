import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/primitives/shell_primitives.dart';
import '../../models/admin_book.dart';
import '../../providers/admin_providers.dart';
import '../../providers/api_client.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/session_notifier.dart';
import '../../utils/api_error_message.dart';
import '../../utils/catalog_language_label.dart';
import '../../utils/form_draft_controller.dart';
import '../../utils/form_draft_keys.dart';
import '../../providers/bible_providers.dart';
import '../../providers/number_system_provider.dart';
import '../../utils/geez_numerals.dart';
import 'bible_content_editor_screen.dart';
import '../../utils/rich_text_codec.dart' show documentFromStoredSummary, plainTextFromStoredSummary;

/// Set true when cover presign + object storage are enabled for publishers.
const bool kAdminCoverUploadEnabled = true;

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
  final _summary = TextEditingController();
  final _author = TextEditingController();
  final _language = TextEditingController(text: 'am');
  final _publishedYear = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _commissionPercent = TextEditingController();
  String _currency = 'USD';
  List<String> _scriptTagsList = [];
  List<String> _selectedTags = [];
  List<AdminDraftChapter> _chaptersDraft = const [];
  String _visibility = 'hidden';
  String? _genre;
  bool _isBible = false;
  // What the backend has persisted — content management needs the book saved as
  // a Bible book first (an unsaved toggle isn't a Bible book server-side yet).
  bool _persistedIsBible = false;
  String? _testament; // 'old' | 'new'
  bool _isPremium = false;
  bool _isFeatured = false;
  String? _createdById;
  bool _busy = false;
  String? _error;
  bool _loaded = false;
  bool _loadRequested = false;
  bool _dirty = false;
  Uint8List? _pendingCoverBytes;
  String? _pendingCoverMime;
  String? _serverCoverGetUrl;
  bool _clearCoverOnSave = false;
  late final FormDraftController _bookDraft;

  String? _draftUserId() =>
      ref.read(sessionNotifierProvider).valueOrNull?.user?.id;

  String _bookDraftKey() => FormDraftKeys.scope(
        userId: _draftUserId(),
        formKey: FormDraftKeys.adminBook(bookId: widget.bookId),
      );

  @override
  void initState() {
    super.initState();
    _bookDraft = FormDraftController(
      draftKey: _bookDraftKey(),
      capture: _captureBookDraft,
      restore: _applyBookDraft,
      isEmpty: _isBookDraftEmpty,
    );
    _title.addListener(_onTitleChanged);
    _primeFromBook(widget.initialBook);
    if (widget.isNew) {
      _loaded = true;
      _restoreBookDraftIfPresent();
    }
  }

  Future<void> _restoreBookDraftIfPresent() async {
    final restored = await _bookDraft.restoreIfPresent();
    if (!mounted) return;
    if (restored) {
      setState(() => _dirty = true);
      showFormDraftRestoredSnackBar(context);
    }
  }

  Map<String, dynamic> _captureBookDraft() {
    final coverBytes = _pendingCoverBytes;
    return {
      'title': _title.text,
      'subtitle': _subtitle.text,
      'summary': _summary.text,
      'author': _author.text,
      'language': _language.text,
      'publishedYear': _publishedYear.text,
      'price': _price.text,
      'salePrice': _salePrice.text,
      'commissionPercent': _commissionPercent.text,
      'currency': _currency,
      'scriptTags': _scriptTagsList,
      'selectedTags': _selectedTags,
      'chaptersDraft': _chaptersDraft.map((e) => e.toJson()).toList(),
      'genre': _genre,
      'isPremium': _isPremium,
      'isFeatured': _isFeatured,
      if (coverBytes != null &&
          coverBytes.isNotEmpty &&
          coverBytes.length <= 2 * 1024 * 1024)
        'coverBytesB64': base64Encode(coverBytes),
      'coverMime': _pendingCoverMime,
      'clearCoverOnSave': _clearCoverOnSave,
    };
  }

  void _applyBookDraft(Map<String, dynamic> data) {
    _title.text = data['title'] as String? ?? '';
    _subtitle.text = data['subtitle'] as String? ?? '';
    _summary.text = data['summary'] as String? ?? '';
    _author.text = data['author'] as String? ?? '';
    _language.text = data['language'] as String? ?? 'am';
    _publishedYear.text = data['publishedYear'] as String? ?? '';
    _price.text = data['price'] as String? ?? '';
    _salePrice.text = data['salePrice'] as String? ?? '';
    _commissionPercent.text = data['commissionPercent'] as String? ?? '';
    _currency = data['currency'] as String? ?? 'USD';
    _scriptTagsList = [
      for (final tag in (data['scriptTags'] as List? ?? const []))
        tag.toString(),
    ];
    _selectedTags = [
      for (final tag in (data['selectedTags'] as List? ?? const []))
        tag.toString(),
    ];
    final chaptersRaw = data['chaptersDraft'];
    if (chaptersRaw is List) {
      _chaptersDraft = _withConsecutivePageNumbers(
        chaptersRaw
            .whereType<Map>()
            .map((e) => AdminDraftChapter.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    _genre = data['genre'] as String?;
    _isPremium = data['isPremium'] as bool? ?? false;
    _isFeatured = data['isFeatured'] as bool? ?? false;
    _clearCoverOnSave = data['clearCoverOnSave'] as bool? ?? false;
    final coverB64 = data['coverBytesB64'] as String?;
    if (coverB64 != null && coverB64.isNotEmpty) {
      try {
        _pendingCoverBytes = base64Decode(coverB64);
        _pendingCoverMime = data['coverMime'] as String? ?? 'image/jpeg';
      } catch (_) {
        _pendingCoverBytes = null;
        _pendingCoverMime = null;
      }
    }
  }

  bool _isBookDraftEmpty(Map<String, dynamic> data) {
    final title = (data['title'] as String? ?? '').trim();
    final subtitle = (data['subtitle'] as String? ?? '').trim();
    final summary = (data['summary'] as String? ?? '').trim();
    final author = (data['author'] as String? ?? '').trim();
    final chapters = data['chaptersDraft'];
    final hasChapters = chapters is List && chapters.isNotEmpty;
    final hasCover = data['coverBytesB64'] is String &&
        (data['coverBytesB64'] as String).isNotEmpty;
    return title.isEmpty &&
        subtitle.isEmpty &&
        summary.isEmpty &&
        author.isEmpty &&
        !hasChapters &&
        !hasCover;
  }

  void _onTitleChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _primeFromBook(AdminBook? b) {
    if (b == null) return;
    _title.text = b.title;
    _subtitle.text = b.subtitle ?? '';
    _summary.text = plainTextFromStoredSummary(b.summary);
    _author.text = b.authorCompiler ?? '';
    _language.text = b.primaryLanguage;
    _scriptTagsList = [...b.scriptTags];
    _selectedTags = [...b.tagSlugs];
    _publishedYear.text = b.publishedYear?.toString() ?? '';
    _genre = b.genre;
    _isBible = b.isBible;
    _persistedIsBible = b.isBible;
    _testament = (b.testamentType?.isNotEmpty ?? false) ? b.testamentType : null;
    _isPremium = b.isPremium;
    _isFeatured = b.isFeatured;
    _currency = b.currency.isNotEmpty ? b.currency : 'USD';
    _price.text = b.price > 0 ? _trimNum(b.price) : '';
    _salePrice.text = b.salePrice != null ? _trimNum(b.salePrice!) : '';
    _commissionPercent.text =
        b.commissionPercent != null ? _trimNum(b.commissionPercent!) : '';
    _chaptersDraft = _withConsecutivePageNumbers(b.chaptersDraft);
    _visibility = b.catalogVisibility;
    _createdById = b.createdById;
    _serverCoverGetUrl = b.coverGetUrl;
    _pendingCoverBytes = null;
    _pendingCoverMime = null;
    _clearCoverOnSave = false;
    _loaded = true;
  }

  void _markDirty() {
    _bookDraft.onChanged();
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
        await _restoreBookDraftIfPresent();
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
    _summary.dispose();
    _author.dispose();
    _language.dispose();
    _publishedYear.dispose();
    _price.dispose();
    _salePrice.dispose();
    _commissionPercent.dispose();
    _bookDraft.dispose();
    super.dispose();
  }

  /// Formats a price/percent for an input field without a trailing `.0`.
  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
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
      _markDirty();
    });
  }

  void _clearCover() {
    setState(() {
      _pendingCoverBytes = null;
      _pendingCoverMime = null;
      _clearCoverOnSave = true;
      _markDirty();
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

  Future<void> _upsertChapter({int? index}) async {
    final editing = index != null ? _chaptersDraft[index] : null;
    final result = await showDialog<AdminDraftChapter>(
      context: context,
      builder: (ctx) => _ChapterEditorDialog(
        draftKey: FormDraftKeys.scope(
          userId: _draftUserId(),
          formKey: FormDraftKeys.adminBookChapter(
            bookId: widget.bookId,
            chapterKey: editing?.chapterKey,
            chapterIndex: index,
            isNew: index == null,
          ),
        ),
        isNew: index == null,
        initialChapter: editing,
      ),
    );
    if (result == null) return;
    if (index == null) {
      _setChaptersDraft([..._chaptersDraft, result]);
    } else {
      final next = [..._chaptersDraft];
      next[index] = result;
      _setChaptersDraft(next);
    }
  }

  List<AdminDraftChapter> _withConsecutivePageNumbers(
    List<AdminDraftChapter> chapters,
  ) {
    var nextPageNumber = 1;
    return [
      for (final chapter in chapters)
        AdminDraftChapter(
          chapterKey: chapter.chapterKey,
          title: chapter.title,
          pages: [
            for (final page in chapter.pages)
              AdminDraftPage(
                pageNumber: nextPageNumber++,
                title: page.title,
                body: page.body,
              ),
          ],
        ),
    ];
  }

  void _setChaptersDraft(
    List<AdminDraftChapter> chapters, {
    bool markDirty = true,
  }) {
    setState(() {
      _chaptersDraft = _withConsecutivePageNumbers(chapters);
      if (markDirty) _dirty = true;
    });
    if (markDirty) _bookDraft.onChanged();
  }

  void _applyChaptersFromResponse(Map<String, dynamic>? data) {
    if (data == null) return;
    final raw = data['chapters_draft'];
    if (raw is! List) return;
    _chaptersDraft = _withConsecutivePageNumbers(
      raw
          .whereType<Map>()
          .map((e) => AdminDraftChapter.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<void> _upsertPage(int chapterIndex, {int? pageIndex}) async {
    final chapter = _chaptersDraft[chapterIndex];
    final editing = pageIndex != null ? chapter.pages[pageIndex] : null;
    final result = await Navigator.of(context, rootNavigator: true)
        .push<AdminDraftPage>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _DraftPageEditorDialog(
          isNewPage: pageIndex == null,
          initialTitle: editing?.title ?? '',
          initialBody: editing?.body ?? '',
          draftKey: FormDraftKeys.scope(
            userId: _draftUserId(),
            formKey: FormDraftKeys.adminBookPage(
              bookId: widget.bookId,
              chapterIndex: chapterIndex,
              pageIndex: pageIndex,
              isNew: pageIndex == null,
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
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
    _setChaptersDraft(chapters);
  }

  void _moveChapter(int index, int step) {
    final target = index + step;
    if (target < 0 || target >= _chaptersDraft.length) return;
    final next = [..._chaptersDraft];
    final item = next.removeAt(index);
    next.insert(target, item);
    _setChaptersDraft(next);
  }

  void _movePage(int chapterIndex, int pageIndex, int step) {
    final pages = _chaptersDraft[chapterIndex].pages;
    final target = pageIndex + step;
    if (target < 0 || target >= pages.length) return;
    final chapters = [..._chaptersDraft];
    final nextPages = [...chapters[chapterIndex].pages];
    final item = nextPages.removeAt(pageIndex);
    nextPages.insert(target, item);
    chapters[chapterIndex] = AdminDraftChapter(
      chapterKey: chapters[chapterIndex].chapterKey,
      title: chapters[chapterIndex].title,
      pages: nextPages,
    );
    _setChaptersDraft(chapters);
  }

  String? _validateChaptersDraft(AppLocalizations l10n) {
    for (final chapter in _chaptersDraft) {
      if (chapter.title.trim().isEmpty) {
        return l10n.titleRequired;
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
      final scriptTags = _scriptTagsList;
      final chaptersDraftPayload =
          _chaptersDraft.map((e) => e.toDraftPayload()).toList();
      if (widget.isNew) {
        final res = await dio.post<Map<String, dynamic>>(
          'admin/books',
          data: {
            'title': _title.text.trim(),
            'subtitle': _subtitle.text.trim(),
            'summary': _summary.text.trim(),
            'author_compiler': _author.text.trim(),
            'primary_language':
                _language.text.trim().isEmpty ? 'am' : _language.text.trim(),
            'script_tags': scriptTags,
            if (_genre != null) 'genre': _genre,
            'is_bible': _isBible,
            'testament_type': _isBible ? (_testament ?? '') : '',
            if (_publishedYear.text.trim().isNotEmpty)
              'published_year': int.tryParse(_publishedYear.text.trim()),
            'is_premium': _isPremium,
            'is_featured': _isFeatured,
            'currency': _currency,
            'price': double.tryParse(_price.text.trim()) ?? 0,
            'sale_price': _salePrice.text.trim().isEmpty
                ? null
                : double.tryParse(_salePrice.text.trim()),
            'commission_percent': _commissionPercent.text.trim().isEmpty
                ? null
                : double.tryParse(_commissionPercent.text.trim()),
            'chapters_draft': chaptersDraftPayload,
            'tag_slugs': _selectedTags,
          },
        );
        _applyChaptersFromResponse(res.data);
        final newId = res.data?['id'] as String?;
        if (newId != null && kAdminCoverUploadEnabled) {
          await _uploadCoverForBook(dio, newId);
        }
      } else {
        final bookId = widget.bookId!;
        final res = await dio.patch<Map<String, dynamic>>(
          'admin/books/$bookId',
          data: {
            'title': _title.text.trim(),
            'subtitle': _subtitle.text.trim(),
            'summary': _summary.text.trim(),
            'author_compiler': _author.text.trim(),
            'primary_language':
                _language.text.trim().isEmpty ? 'am' : _language.text.trim(),
            'script_tags': scriptTags,
            'genre': _genre ?? '',
            'is_bible': _isBible,
            'testament_type': _isBible ? (_testament ?? '') : '',
            'published_year': _publishedYear.text.trim().isEmpty
                ? null
                : int.tryParse(_publishedYear.text.trim()),
            'is_premium': _isPremium,
            'is_featured': _isFeatured,
            'currency': _currency,
            'price': double.tryParse(_price.text.trim()) ?? 0,
            'sale_price': _salePrice.text.trim().isEmpty
                ? null
                : double.tryParse(_salePrice.text.trim()),
            'commission_percent': _commissionPercent.text.trim().isEmpty
                ? null
                : double.tryParse(_commissionPercent.text.trim()),
            'chapters_draft': chaptersDraftPayload,
            'tag_slugs': _selectedTags,
          },
        );
        _applyChaptersFromResponse(res.data);
        if (kAdminCoverUploadEnabled) {
          await _uploadCoverForBook(dio, bookId);
        }
      }
      ref.invalidate(adminBooksProvider);
      // Refresh reader-facing data so new covers / metadata show without a
      // manual reload.
      ref.invalidate(catalogProvider);
      final editedId = widget.bookId;
      if (editedId != null) {
        ref.invalidate(bookDetailProvider(editedId));
        // The book type is now persisted — enable/refresh content management.
        ref.invalidate(adminBibleBookIndexProvider(editedId));
      }
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _persistedIsBible = _isBible;
      });
      await _bookDraft.clear();
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

  static const _languageCodes = ['am', 'gez', 'en', 'ti', 'om'];

  Widget _buildLanguageDropdown(AppLocalizations l10n) {
    final current = _language.text.trim().isEmpty ? 'am' : _language.text.trim();
    final codes = [
      ..._languageCodes,
      if (!_languageCodes.contains(current)) current,
    ];
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.primaryLanguageCodeLabel),
      items: [
        for (final c in codes)
          DropdownMenuItem<String>(
            value: c,
            child: Text('${catalogLanguageFilterLabel(c, l10n)} ($c)'),
          ),
      ],
      onChanged: (v) {
        setState(() => _language.text = v ?? 'am');
        _markDirty();
      },
    );
  }

  Widget _buildYearDropdown(AppLocalizations l10n) {
    final currentYear = DateTime.now().year;
    final selected = int.tryParse(_publishedYear.text.trim());
    final years = [for (var y = currentYear; y >= 1900; y--) y];
    if (selected != null && !years.contains(selected)) years.insert(0, selected);
    return DropdownButtonFormField<int?>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.adminPublishedYearLabel),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(l10n.adminGenreNone)),
        for (final y in years)
          DropdownMenuItem<int?>(value: y, child: Text('$y')),
      ],
      onChanged: (v) {
        setState(() => _publishedYear.text = v?.toString() ?? '');
        _markDirty();
      },
    );
  }

  static const _currencyCodes = ['USD', 'ETB', 'EUR', 'GBP'];

  Widget _buildCurrencyDropdown(AppLocalizations l10n) {
    final codes = [
      ..._currencyCodes,
      if (!_currencyCodes.contains(_currency)) _currency,
    ];
    return DropdownButtonFormField<String>(
      initialValue: _currency,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.adminCurrencyLabel),
      items: [
        for (final c in codes)
          DropdownMenuItem<String>(value: c, child: Text(c)),
      ],
      onChanged: (v) {
        setState(() => _currency = v ?? 'USD');
        _markDirty();
      },
    );
  }

  void _openBibleContent() {
    final id = widget.bookId;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BibleContentEditorScreen(
          bookId: id,
          bookTitle: _title.text.trim(),
        ),
      ),
    );
  }

  Widget _buildBibleControls(
      AppLocalizations l10n, bool isNew, bool twoPane) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.adminIsBibleLabel),
          subtitle: Text(l10n.adminIsBibleSubtitle),
          value: _isBible,
          onChanged: (v) {
            setState(() {
              _isBible = v;
              if (!v) _testament = null;
            });
            _markDirty();
          },
        ),
        if (_isBible) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _testament,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.adminTestamentLabel),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.adminGenreNone),
              ),
              DropdownMenuItem<String?>(
                value: 'old',
                child: Text(l10n.bibleOldTestament),
              ),
              DropdownMenuItem<String?>(
                value: 'new',
                child: Text(l10n.bibleNewTestament),
              ),
            ],
            onChanged: (v) {
              setState(() => _testament = v);
              _markDirty();
            },
          ),
          // In two-pane the right pane manages content; in single column show
          // a button that opens the full-screen editor.
          if (!twoPane) ...[
            const SizedBox(height: 12),
            if (isNew || !_persistedIsBible)
              Text(
                l10n.adminBibleSaveFirst,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _openBibleContent,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(l10n.adminManageBibleContent),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildGenreDropdown(AppLocalizations l10n) {
    final genres =
        ref.watch(genresProvider).valueOrNull ?? const <GenreOption>[];
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    final slugs = genres.map((g) => g.slug).toSet();
    final extra =
        (_genre != null && _genre!.isNotEmpty && !slugs.contains(_genre))
            ? [_genre!]
            : const <String>[];
    return DropdownButtonFormField<String?>(
      initialValue: _genre,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.adminGenreLabel),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(l10n.adminGenreNone),
        ),
        for (final g in genres)
          DropdownMenuItem<String?>(
            value: g.slug,
            child: Text(
              isAm && (g.labelAm?.isNotEmpty ?? false) ? g.labelAm! : g.label,
            ),
          ),
        for (final s in extra)
          DropdownMenuItem<String?>(value: s, child: Text(s)),
      ],
      onChanged: (v) {
        setState(() => _genre = v);
        _markDirty();
      },
    );
  }

  Widget _contentHint(IconData icon, String message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48,
                color: AppColors.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );

  /// Right-pane content: the Bible workspace for Bible books, else the
  /// page-based chapters editor.
  Widget _rightContentPane(
      BuildContext context, AppLocalizations l10n, bool isNew) {
    if (_isBible) {
      if (isNew || widget.bookId == null || !_persistedIsBible) {
        return _contentHint(Icons.menu_book_outlined, l10n.adminBibleSaveFirst);
      }
      return BibleContentWorkspace(bookId: widget.bookId!);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        AppSectionHeader(title: l10n.chaptersPagesSection),
        const SizedBox(height: 12),
        ..._pagesSectionChildren(context, l10n, isNew),
      ],
    );
  }

  List<Widget> _pagesSectionChildren(
      BuildContext context, AppLocalizations l10n, bool isNew) {
    return [
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppPanel(
                        padding: EdgeInsets.zero,
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
                              l10n.pageCount(chapter.pages.length),
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
                                      final next = [..._chaptersDraft]
                                        ..removeAt(cIndex);
                                      _setChaptersDraft(next);
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
                                l10n.pageListTitle(
                                  page.pageNumber,
                                  page.title.trim().isEmpty
                                      ? l10n.pageTitleFallback(page.pageNumber)
                                      : page.title,
                                ),
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
                                            final chapters = [..._chaptersDraft];
                                            final pages = [
                                              ...chapters[cIndex].pages
                                            ]..removeAt(pIndex);
                                            chapters[cIndex] = AdminDraftChapter(
                                              chapterKey:
                                                  chapters[cIndex].chapterKey,
                                              title: chapters[cIndex].title,
                                              pages: pages,
                                            );
                                            _setChaptersDraft(chapters);
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
                      ),
                    );
                  }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNew = widget.isNew;
    final currentUserId =
        ref.watch(sessionNotifierProvider).valueOrNull?.user?.id;
    final isCreator = isNew ||
        (currentUserId != null &&
            _createdById != null &&
            _createdById == currentUserId);
    final trimmedTitle = _title.text.trim();
    final appBarTitle = isNew
        ? (trimmedTitle.isEmpty ? l10n.newBookAppBar : trimmedTitle)
        : (trimmedTitle.isEmpty ? l10n.editBookAppBar : trimmedTitle);
    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty || _busy) return;
        final leave = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final d = AppLocalizations.of(ctx)!;
            return AlertDialog(
              title: Text(d.discardUnsavedTitle),
              content: Text(d.discardUnsavedBodyEditor),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('stay'),
                  child: Text(d.stay),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('discard_draft'),
                  child: Text(d.formDraftDiscardAction),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop('save_draft'),
                  child: Text(d.formDraftLeaveAndSave),
                ),
              ],
            );
          },
        );
        if (leave == 'save_draft') {
          await _bookDraft.persistNow();
          if (!context.mounted) return;
          showFormDraftSavedSnackBar(context);
          Navigator.of(context).pop();
        } else if (leave == 'discard_draft') {
          await _bookDraft.clear();
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.referencePageBg,
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
          : (!isNew && _visibility == 'published')
              ? AppStateView(
                  title: l10n.adminPublishedBookLockedTitle,
                  message: l10n.adminPublishedBookLockedMessage,
                  icon: Icons.lock_outline_rounded,
                  actionLabel: l10n.goBack,
                  onAction: () => context.pop(),
                )
              : (!isNew && !isCreator)
                  ? AppStateView(
                      title: l10n.adminNotBookCreatorTitle,
                      message: l10n.adminNotBookCreatorMessage,
                      icon: Icons.lock_outline_rounded,
                      actionLabel: l10n.goBack,
                      onAction: () => context.pop(),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        // Two-pane on desktop: details left, content right. Treat
                        // unbounded width (which the shell can hand us) as wide;
                        // the two-pane branch bounds the size explicitly.
                        final twoPane = !constraints.maxWidth.isFinite ||
                            constraints.maxWidth >= 1040;
                        Widget pair(Widget a, Widget b) => (wide && !twoPane)
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: a),
                                  const SizedBox(width: 16),
                                  Expanded(child: b),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [a, const SizedBox(height: 12), b],
                              );
                        final formContent = Form(
                          key: _formKey,
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 32 : 16,
                              vertical: 24,
                            ),
                            children: [
                              Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 880),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                AppSectionHeader(title: l10n.metadataSection),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _summary,
                  decoration: InputDecoration(
                    labelText: l10n.adminSummaryLabel,
                    alignLabelWithHint: true,
                  ),
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 16),
                if (kAdminCoverUploadEnabled) ...[
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
                          color:
                              Theme.of(context).colorScheme.surfaceContainerHigh,
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
                ],
                pair(
                  TextField(
                    controller: _author,
                    decoration:
                        InputDecoration(labelText: l10n.authorCompilerLabel),
                    onChanged: (_) => _markDirty(),
                  ),
                  _buildLanguageDropdown(l10n),
                ),
                const SizedBox(height: 12),
                _ChipsField(
                  label: l10n.scriptTagsLabel,
                  values: _scriptTagsList,
                  onChanged: (v) {
                    setState(() => _scriptTagsList = v);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 18),
                AppSectionHeader(title: l10n.adminGenreLabel),
                const SizedBox(height: 12),
                pair(
                  _buildGenreDropdown(l10n),
                  _buildYearDropdown(l10n),
                ),
                const SizedBox(height: 8),
                _buildBibleControls(l10n, isNew, twoPane),
                const SizedBox(height: 12),
                _ChipsField(
                  label: l10n.tagsLabel,
                  values: _selectedTags,
                  suggestions:
                      ref.watch(tagsProvider).valueOrNull?.map((t) => t.slug).toList() ??
                          const [],
                  onChanged: (v) {
                    setState(() => _selectedTags = v);
                    _markDirty();
                  },
                ),
                const SizedBox(height: 8),
                pair(
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.adminIsPremiumLabel),
                    subtitle: Text(l10n.adminIsPremiumSubtitle),
                    value: _isPremium,
                    onChanged: (v) {
                      setState(() => _isPremium = v);
                      _markDirty();
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.adminIsFeaturedLabel),
                    subtitle: Text(l10n.adminIsFeaturedSubtitle),
                    value: _isFeatured,
                    onChanged: (v) {
                      setState(() => _isFeatured = v);
                      _markDirty();
                    },
                  ),
                ),
                const SizedBox(height: 18),
                AppSectionHeader(title: l10n.adminPricingSection),
                const SizedBox(height: 12),
                pair(
                  _buildCurrencyDropdown(l10n),
                  TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.adminPriceLabel,
                      prefixText: '$_currency ',
                    ),
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                const SizedBox(height: 12),
                pair(
                  TextField(
                    controller: _salePrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: l10n.adminSalePriceLabel),
                    onChanged: (_) => _markDirty(),
                  ),
                  TextField(
                    controller: _commissionPercent,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.adminCommissionPercentLabel,
                      helperText: l10n.adminCommissionHelp,
                      suffixText: '%',
                    ),
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                if (!twoPane && !_isBible) ...[
                const SizedBox(height: 18),
                  ..._pagesSectionChildren(context, l10n, isNew),
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
                            ],
                          ),
                        );
                        if (twoPane) {
                          // The shell can hand this screen fully unconstrained
                          // constraints; Row/Expanded/ListView need BOTH axes
                          // bounded, so fall back to the real screen size.
                          final screen = MediaQuery.sizeOf(context);
                          var w = constraints.maxWidth.isFinite
                              ? constraints.maxWidth
                              : screen.width;
                          var h = constraints.maxHeight.isFinite
                              ? constraints.maxHeight
                              : screen.height;
                          // Last resort: the shell can report an infinite size
                          // via BOTH constraints and MediaQuery. A finite value
                          // is mandatory for Row/Expanded to lay out.
                          if (!w.isFinite || w <= 0) w = 1400;
                          if (!h.isFinite || h <= 0) h = 900;
                          return SizedBox(
                            width: w,
                            height: h,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 4, child: formContent),
                                const VerticalDivider(
                                    width: 1, color: AppColors.border),
                                Expanded(
                                  flex: 5,
                                  child:
                                      _rightContentPane(context, l10n, isNew),
                                ),
                              ],
                            ),
                          );
                        }
                        return formContent;
                      },
                    ),
      ),
    );
  }
}

/// Editable list of string values rendered as deletable chips, with a text
/// field to add new ones and optional tap-to-add suggestions.
class _ChipsField extends StatefulWidget {
  const _ChipsField({
    required this.label,
    required this.values,
    required this.onChanged,
    this.suggestions = const [],
  });

  final String label;
  final List<String> values;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ChipsField> createState() => _ChipsFieldState();
}

class _ChipsFieldState extends State<_ChipsField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final v = raw.trim();
    _ctrl.clear();
    if (v.isEmpty || widget.values.contains(v)) return;
    widget.onChanged([...widget.values, v]);
  }

  void _remove(String v) =>
      widget.onChanged(widget.values.where((e) => e != v).toList());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final available =
        widget.suggestions.where((s) => !widget.values.contains(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final v in widget.values)
                InputChip(label: Text(v), onDeleted: () => _remove(v)),
            ],
          ),
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.adminChipAddHint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _add(_ctrl.text),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
        ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in available.take(20))
                ActionChip(
                  label: Text(s),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _add(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChapterEditorDialog extends StatefulWidget {
  const _ChapterEditorDialog({
    required this.draftKey,
    required this.isNew,
    this.initialChapter,
  });

  final String draftKey;
  final bool isNew;
  final AdminDraftChapter? initialChapter;

  @override
  State<_ChapterEditorDialog> createState() => _ChapterEditorDialogState();
}

class _ChapterEditorDialogState extends State<_ChapterEditorDialog> {
  late final TextEditingController _title;
  late final FormDraftController _draft;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialChapter?.title ?? '');
    _draft = FormDraftController(
      draftKey: widget.draftKey,
      capture: () => {'title': _title.text},
      restore: (data) {
        _title.text = data['title'] as String? ?? '';
      },
      isEmpty: (data) => (data['title'] as String? ?? '').trim().isEmpty,
    );
    _title.addListener(_draft.onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restored = await _draft.restoreIfPresent();
      if (!mounted || !restored) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
    });
  }

  @override
  void dispose() {
    _title.removeListener(_draft.onChanged);
    _title.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    await _draft.persistNow();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    await _draft.clear();
    if (!mounted) return;
    Navigator.of(context).pop(
      AdminDraftChapter(
        chapterKey: widget.initialChapter?.chapterKey ?? '',
        title: title.isEmpty ? l10n.untitledChapter : title,
        pages: widget.initialChapter?.pages ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.isNew ? l10n.addChapterTitle : l10n.editChapterTitle),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _title,
          decoration: InputDecoration(labelText: l10n.chapterTitleLabel),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _DraftPageEditorDialog extends StatefulWidget {
  const _DraftPageEditorDialog({
    required this.isNewPage,
    required this.initialTitle,
    required this.initialBody,
    required this.draftKey,
  });

  final bool isNewPage;
  final String initialTitle;
  final String initialBody;
  final String draftKey;

  @override
  State<_DraftPageEditorDialog> createState() => _DraftPageEditorDialogState();
}

class _DraftPageEditorDialogState extends State<_DraftPageEditorDialog> {
  late final TextEditingController _title;
  late final QuillController _bodyQuill;
  late final FormDraftController _draft;
  /// Full Quill toolbar lives in the bottom sheet; collapsed by default for typing space.
  bool _toolbarExpanded = false;

  /// Converts the Western/Arabic digits in the current selection to Ge'ez
  /// numerals (e.g. "3" → "፫", "16" → "፲፮"). No-op when nothing is selected.
  void _convertSelectionToGeez() {
    final sel = _bodyQuill.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final len = sel.end - sel.start;
    final text = _bodyQuill.document.getPlainText(sel.start, len);
    final converted = text.replaceAllMapped(
      RegExp(r'\d+'),
      (m) => toGeezNumeral(int.parse(m[0]!)),
    );
    if (converted == text) return;
    _bodyQuill.replaceText(
      sel.start,
      len,
      converted,
      TextSelection.collapsed(offset: sel.start + converted.length),
    );
  }

  void _applyBodyFromStored(String body) {
    final richDoc = documentFromStoredSummary(body);
    if (richDoc != null) {
      _bodyQuill.document = richDoc;
      return;
    }
    final normalized = body.replaceAll('\uFFFC', '').trimRight();
    final next = normalized.isEmpty ? '\n' : '$normalized\n';
    final len = _bodyQuill.document.length;
    _bodyQuill.replaceText(
      0,
      len - 1,
      next,
      TextSelection.collapsed(offset: next.length - 1),
    );
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _bodyQuill = QuillController.basic();
    _applyBodyFromStored(widget.initialBody);
    _draft = FormDraftController(
      draftKey: widget.draftKey,
      capture: () => {
        'title': _title.text,
        'body': jsonEncode(_bodyQuill.document.toDelta().toJson()),
      },
      restore: (data) {
        _title.text = data['title'] as String? ?? '';
        _applyBodyFromStored(data['body'] as String? ?? '');
      },
      isEmpty: (data) {
        final title = (data['title'] as String? ?? '').trim();
        final body = (data['body'] as String? ?? '').trim();
        return title.isEmpty && body.isEmpty;
      },
    );
    _title.addListener(_draft.onChanged);
    _bodyQuill.document.changes.listen((_) => _draft.onChanged());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restored = await _draft.restoreIfPresent();
      if (!mounted || !restored) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
    });
  }

  @override
  void dispose() {
    _title.removeListener(_draft.onChanged);
    _title.dispose();
    _bodyQuill.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    await _draft.persistNow();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveAndPop() async {
    final t = _title.text.trim();
    final body = jsonEncode(_bodyQuill.document.toDelta().toJson());
    await _draft.clear();
    if (!mounted) return;
    Navigator.of(context).pop(
      AdminDraftPage(
        pageNumber: 0,
        title: t,
        body: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _cancel();
      },
      child: Scaffold(
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
            onPressed: _cancel,
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
                    child: Consumer(
                      builder: (context, ref, _) {
                        final geez = ref.watch(useGeezNumeralsProvider);
                        return QuillEditor.basic(
                          controller: _bodyQuill,
                          config: QuillEditorConfig(
                            placeholder: l10n.pageEditorPlaceholder,
                            expands: false,
                            scrollable: true,
                            padding: const EdgeInsets.all(12),
                            embedBuilders: const [],
                            unknownEmbedBuilder:
                                const _UnsupportedEmbedBuilder(),
                            // Render ordered-list numbers in Ge'ez when enabled.
                            customLeadingBlockBuilder:
                                geez ? _geezOrderedLeadingBuilder : null,
                          ),
                        );
                      },
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
                          config: QuillSimpleToolbarConfig(
                            multiRowsDisplay: true,
                            embedButtons: const [],
                            customButtons: [
                              QuillToolbarCustomButtonOptions(
                                icon: const Text(
                                  '፩',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                tooltip: l10n.geezConvertTooltip,
                                onPressed: _convertSelectionToGeez,
                              ),
                            ],
                            showUndo: true,
                            showRedo: true,
                            showBoldButton: true,
                            showItalicButton: true,
                            showUnderLineButton: true,
                            showStrikeThrough: true,
                            showHeaderStyle: true,
                            headerStyleType: HeaderStyleType.buttons,
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
                            showFontSize: true,
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
    ),
    );
  }
}

/// Renders ordered-list leading numbers in Ge'ez (፩. ፪. ፫.) instead of Arabic.
/// Returns null for anything else (bullets, checkboxes, code-block line numbers,
/// and nested alpha/roman levels) so their default rendering is kept.
Widget? _geezOrderedLeadingBuilder(Node node, LeadingConfig config) {
  if (config.index == null || config.attribute.value != 'ordered') return null;
  final base = config.getIndexNumberByIndent ?? config.index!.toString();
  final n = int.tryParse(base);
  final label = n != null ? toGeezNumeral(n) : base; // keep alpha/roman levels
  return Container(
    alignment: AlignmentDirectional.centerEnd,
    width: config.width,
    padding: EdgeInsetsDirectional.only(end: config.padding ?? 0),
    child: Text(
      config.withDot ? '$label.' : label,
      style: config.style,
    ),
  );
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
