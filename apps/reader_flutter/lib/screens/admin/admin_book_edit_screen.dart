import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/platform/platform_shell.dart';
import '../../config/app_config.dart';
import '../../design/app_tokens.dart';
import '../../desktop/design/desktop_tokens.dart';
import '../../desktop/layout/desktop_content_frame.dart';
import '../../desktop/layout/desktop_layout_scope.dart';
import '../../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/pdf_document_reader.dart';
import '../../widgets/stored_rich_text_view.dart';
import '../../models/admin_book.dart';
import '../../providers/admin_providers.dart';
import '../../providers/api_client.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/session_notifier.dart';
import '../../utils/api_error_message.dart';
import '../../utils/catalog_language_label.dart';
import '../../utils/form_draft_controller.dart';
import '../../utils/form_draft_keys.dart';
import '../../utils/money_format.dart';
import '../../utils/pdf_book_loader.dart';
import '../../providers/bible_providers.dart';
import '../../providers/number_system_provider.dart';
import '../../utils/geez_numerals.dart';
import '../../web/design/web_tokens.dart';
import '../../web/layout/app_layout_scope.dart';
import '../../web/layout/web_content_frame.dart';
import '../../web/widgets/shell/web_overlay_scaffold.dart';
import 'bible_content_editor_screen.dart';
import '../../utils/rich_text_codec.dart'
    show documentFromStoredSummary, plainTextFromStoredSummary;

/// Set true when cover presign + object storage are enabled for publishers.
const bool kAdminCoverUploadEnabled = true;

enum _BookEditSection { details, content, lookInside }

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
  final _priceEtb = TextEditingController();
  final _priceUsd = TextEditingController();
  List<String> _scriptTagsList = [];
  List<AdminDraftChapter> _chaptersDraft = const [];
  String _visibility = 'hidden';
  String _reviewStatus = 'draft';
  BookReviewNote? _latestReviewNote;
  String? _genre;
  bool _isBible = false;
  // What the backend has persisted — content management needs the book saved as
  // a Bible book first (an unsaved toggle isn't a Bible book server-side yet).
  bool _persistedIsBible = false;
  bool _isPdfBook = false;
  AdminPdfDraft? _serverPdfDraft;
  Uint8List? _pendingPdfBytes;
  String? _pendingPdfFilename;
  List<int> _previewPages = [];
  final _previewPageInput = TextEditingController();

  /// In-page section: Book details vs Chapters/PDF/Bible (full-width each).
  _BookEditSection _section = _BookEditSection.details;
  /// Selected chapter in the Chapters & pages workspace.
  int? _selectedChapterIndex;
  /// When set, the sidebar name field renames this chapter; otherwise it adds.
  int? _renamingChapterIndex;
  final _chapterTitleInput = TextEditingController();
  /// Active page tab in the chapter pages pane (always editable).
  int _previewPageIndex = 0;
  final _livePageEditorKey = GlobalKey<_DraftPageEditorState>();

  void _flushLivePageEditor() {
    _livePageEditorKey.currentState?.commitNow();
  }
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

  /// True when the price fields still hold reader-facing (stored) amounts and
  /// need to be converted to the author's pre-fee prices.
  bool _pricesAreListedAmounts = false;

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
      setState(() {
        _dirty = true;
        _pricesAreListedAmounts = false;
      });
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
      'priceEtb': _priceEtb.text,
      'priceUsd': _priceUsd.text,
      'scriptTags': _scriptTagsList,
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
    if (data.containsKey('priceEtb') || data.containsKey('priceUsd')) {
      _priceEtb.text = data['priceEtb'] as String? ?? '';
      _priceUsd.text = data['priceUsd'] as String? ?? '';
    } else {
      final legacy = data['price'] as String? ?? '';
      final currency = (data['currency'] as String? ?? 'USD').toUpperCase();
      _priceEtb.text = currency == 'ETB' ? legacy : '';
      _priceUsd.text = currency == 'USD' ? legacy : '';
    }
    _scriptTagsList = [
      for (final tag in (data['scriptTags'] as List? ?? const []))
        tag.toString(),
    ];
    final chaptersRaw = data['chaptersDraft'];
    if (chaptersRaw is List) {
      _chaptersDraft = _withConsecutivePageNumbers(
        chaptersRaw
            .whereType<Map>()
            .map(
              (e) => AdminDraftChapter.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );
      _selectedChapterIndex = _chaptersDraft.isEmpty ? null : 0;
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
    final hasCover =
        data['coverBytesB64'] is String &&
        (data['coverBytesB64'] as String).isNotEmpty;
    final hasPrice =
        (data['priceEtb'] as String? ?? '').trim().isNotEmpty ||
        (data['priceUsd'] as String? ?? '').trim().isNotEmpty ||
        (data['price'] as String? ?? '').trim().isNotEmpty;
    return title.isEmpty &&
        subtitle.isEmpty &&
        summary.isEmpty &&
        author.isEmpty &&
        !hasChapters &&
        !hasCover &&
        !hasPrice;
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
    _publishedYear.text = b.publishedYear?.toString() ?? '';
    _genre = b.genre;
    _isBible = b.isBible;
    _persistedIsBible = b.isBible;
    _isPdfBook = b.isPdfBook;
    _serverPdfDraft = b.pdfDraft;
    _previewPages = [...(b.pdfDraft?.previewPageNumbers ?? const <int>[])];
    _testament = (b.testamentType?.isNotEmpty ?? false)
        ? b.testamentType
        : null;
    _isPremium = b.isPremium;
    _isFeatured = b.isFeatured;
    final code = b.currency.toUpperCase();
    final etbListed = code == 'ETB' && b.price > 0 ? b.price : b.priceEtb;
    final usdListed = code == 'USD' && b.price > 0 ? b.price : b.priceUsd;
    _priceEtb.text = etbListed > 0 ? _trimNum(etbListed) : '';
    _priceUsd.text = usdListed > 0 ? _trimNum(usdListed) : '';
    _pricesAreListedAmounts = etbListed > 0 || usdListed > 0;
    _chaptersDraft = _withConsecutivePageNumbers(b.chaptersDraft);
    _selectedChapterIndex = _chaptersDraft.isEmpty ? null : 0;
    _visibility = b.catalogVisibility;
    _reviewStatus = b.reviewStatus;
    _latestReviewNote = b.latestReviewNote;
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
    _priceEtb.dispose();
    _priceUsd.dispose();
    _previewPageInput.dispose();
    _chapterTitleInput.dispose();
    _bookDraft.dispose();
    super.dispose();
  }

  void _syncPreviewPagesFromDraft(AdminPdfDraft? draft) {
    _previewPages = [...(draft?.previewPageNumbers ?? const <int>[])];
  }

  void _addPreviewPage() {
    final n = int.tryParse(_previewPageInput.text.trim());
    _previewPageInput.clear();
    if (n == null || n <= 0) return;
    final maxPages = _serverPdfDraft?.pageCount;
    if (maxPages != null && n > maxPages) return;
    if (_previewPages.contains(n)) return;
    if (_previewPages.length >= 10) return;
    setState(() {
      _previewPages = [..._previewPages, n]..sort();
      _markDirty();
    });
  }

  void _suggestFirstFivePreviewPages() {
    final maxPages = _serverPdfDraft?.pageCount ?? 5;
    final count = maxPages < 5 ? maxPages : 5;
    if (count <= 0) return;
    setState(() {
      _previewPages = [for (var i = 1; i <= count; i++) i];
      _markDirty();
    });
  }

  Future<void> _savePreviewPages() async {
    final id = widget.bookId;
    if (id == null || id.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await savePdfPreviewPages(
        ref.read(apiDioProvider),
        bookId: id,
        pageNumbers: _previewPages,
      );
      if (!mounted) return;
      setState(() {
        if (draft != null) {
          _serverPdfDraft = draft;
          _syncPreviewPagesFromDraft(draft);
        }
        _busy = false;
      });
      if (id.isNotEmpty) {
        ref.invalidate(pdfPreviewAccessProvider(id));
        ref.invalidate(pdfPreviewViewerSourceProvider(id));
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pdfPreviewPagesSaved)));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = messageFromDioResponse(e.response?.data) ?? e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  /// Formats a price/percent for an input field without a trailing `.0`.
  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  double _listedPriceFromAuthor(double authorAmount, double commissionPercent) {
    if (authorAmount <= 0) return 0;
    if (commissionPercent <= 0) return authorAmount;
    return double.parse(
      (authorAmount * (1 + commissionPercent / 100)).toStringAsFixed(2),
    );
  }

  double _authorAmountFromListed(double listed, double commissionPercent) {
    if (listed <= 0) return 0;
    if (commissionPercent <= 0) return listed;
    return listed / (1 + commissionPercent / 100);
  }

  void _convertListedPricesIfNeeded(double commissionPercent) {
    if (!_pricesAreListedAmounts) return;
    _pricesAreListedAmounts = false;
    _priceEtb.text = _authorPriceText(_priceEtb.text, commissionPercent);
    _priceUsd.text = _authorPriceText(_priceUsd.text, commissionPercent);
  }

  /// Accepts `1000`, `1000.50`, and thousands commas (`1,000`).
  double? _parsePriceInput(String raw) {
    final text = raw.trim().replaceAll(',', '');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String _authorPriceText(String raw, double commissionPercent) {
    final listed = _parsePriceInput(raw);
    if (listed == null || listed <= 0 || commissionPercent <= 0) return raw;
    return _trimNum(_authorAmountFromListed(listed, commissionPercent));
  }

  double _pricePayload(
    TextEditingController controller,
    double commissionPercent,
  ) {
    if (!_isPremium) return 0;
    final authorAmount = _parsePriceInput(controller.text) ?? 0;
    return _listedPriceFromAuthor(authorAmount, commissionPercent);
  }

  String? _validateOptionalPrice(String? raw, AppLocalizations l10n) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final value = _parsePriceInput(text);
    if (value == null || value < 0) return l10n.adminPriceInvalid;
    return null;
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickCoverImage() async {
    Uint8List? bytes;
    String? name;
    // image_picker has no Windows/Linux implementation; use file_picker there.
    if (isDesktopPlatform) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
      name = result.files.first.name;
    } else {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (x == null) return;
      bytes = await x.readAsBytes();
      name = x.path;
    }
    if (bytes == null || bytes.isEmpty || !mounted) return;
    final mime = _mimeFromPath(name);
    setState(() {
      _pendingCoverBytes = bytes;
      _pendingCoverMime = mime;
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

  Future<void> _uploadPdfForBook(Dio api, String bookId) async {
    final bytes = _pendingPdfBytes;
    if (bytes == null || bytes.isEmpty) return;
    final filename = _pendingPdfFilename ?? 'content.pdf';
    final pres = await api.post<Map<String, dynamic>>(
      'admin/books/$bookId/pdf/presign',
      data: {'content_type': 'application/pdf', 'filename': filename},
    );
    final data = pres.data;
    if (data == null) throw StateError('Empty PDF presign response');
    final putUrl = data['put_url'] as String?;
    final revisionId = data['revision_id'] as String?;
    if (putUrl == null || revisionId == null) {
      throw StateError('Invalid PDF presign response');
    }
    final plain = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    await plain.put<dynamic>(
      putUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': 'application/pdf'}),
    );
    final complete = await api.post<Map<String, dynamic>>(
      'admin/books/$bookId/pdf/complete',
      data: {'revision_id': revisionId, 'filename': filename},
    );
    _pendingPdfBytes = null;
    _pendingPdfFilename = null;
    final draftJson = complete.data?['pdf_draft'];
    if (draftJson is Map) {
      _serverPdfDraft = AdminPdfDraft.fromJson(
        Map<String, dynamic>.from(draftJson),
      );
      _isPdfBook = true;
      _syncPreviewPagesFromDraft(_serverPdfDraft);
    } else {
      // Fall back to a fresh book fetch so the editor shows the uploaded file.
      final refreshed = await fetchAdminBookByDio(api, bookId);
      if (refreshed != null) {
        _serverPdfDraft = refreshed.pdfDraft;
        _isPdfBook = refreshed.isPdfBook;
        _syncPreviewPagesFromDraft(_serverPdfDraft);
      }
    }
    _invalidateAdminPdfPreview(bookId);
  }

  void _invalidateAdminPdfPreview(String bookId) {
    ref.invalidate(pdfBookAccessProvider(bookId));
    ref.invalidate(pdfViewerSourceProvider(bookId));
  }

  Future<void> _removeServerPdf() async {
    final bookId = widget.bookId;
    final l10n = AppLocalizations.of(context);
    if (bookId == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(apiDioProvider);
      await api.delete<Map<String, dynamic>>('admin/books/$bookId/pdf');
      if (!mounted) return;
      setState(() {
        _serverPdfDraft = null;
        _pendingPdfBytes = null;
        _pendingPdfFilename = null;
        _previewPages = [];
        // Keep PDF book type on so the author can pick a replacement file.
        _isPdfBook = true;
      });
      _invalidateAdminPdfPreview(bookId);
      _markDirty();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(l10n.pdfRemoved),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.pdfRemoveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _isPdfBook = true;
      _isBible = false;
      _pendingPdfBytes = bytes;
      _pendingPdfFilename = file.name;
      _markDirty();
    });
  }

  int? _clampedChapterIndex() {
    if (_chaptersDraft.isEmpty) return null;
    final i = _selectedChapterIndex ?? 0;
    if (i < 0) return 0;
    if (i >= _chaptersDraft.length) return _chaptersDraft.length - 1;
    return i;
  }

  void _beginRenameChapter(int index) {
    setState(() {
      _renamingChapterIndex = index;
      _chapterTitleInput.text = _chaptersDraft[index].title;
      _selectedChapterIndex = index;
    });
  }

  void _resetChapterForm() {
    setState(() {
      _renamingChapterIndex = null;
      _chapterTitleInput.clear();
    });
  }

  void _commitChapterInline() {
    final l10n = AppLocalizations.of(context)!;
    final title = _chapterTitleInput.text.trim();
    final resolved = title.isEmpty ? l10n.untitledChapter : title;
    final renameAt = _renamingChapterIndex;
    if (renameAt != null) {
      final next = [..._chaptersDraft];
      final current = next[renameAt];
      next[renameAt] = AdminDraftChapter(
        chapterKey: current.chapterKey,
        title: resolved,
        pages: current.pages,
      );
      _setChaptersDraft(next);
      setState(() {
        _selectedChapterIndex = renameAt;
        _section = _BookEditSection.content;
      });
    } else {
      final next = [
        ..._chaptersDraft,
        AdminDraftChapter(chapterKey: '', title: resolved, pages: const []),
      ];
      _setChaptersDraft(next);
      setState(() {
        _selectedChapterIndex = next.length - 1;
        _section = _BookEditSection.content;
      });
    }
    _resetChapterForm();
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
                localId: page.localId,
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
      if (_chaptersDraft.isEmpty) {
        _selectedChapterIndex = null;
      } else if (_selectedChapterIndex == null) {
        _selectedChapterIndex = 0;
      } else if (_selectedChapterIndex! >= _chaptersDraft.length) {
        _selectedChapterIndex = _chaptersDraft.length - 1;
      }
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
    if (_chaptersDraft.isEmpty) {
      _selectedChapterIndex = null;
    } else if (_selectedChapterIndex == null ||
        _selectedChapterIndex! >= _chaptersDraft.length) {
      _selectedChapterIndex = 0;
    }
  }

  int _clampedPreviewPageIndex(AdminDraftChapter chapter) {
    if (chapter.pages.isEmpty) return 0;
    if (_previewPageIndex < 0) return 0;
    if (_previewPageIndex >= chapter.pages.length) {
      return chapter.pages.length - 1;
    }
    return _previewPageIndex;
  }

  void _patchPageAt(int chapterIndex, int pageIndex, AdminDraftPage page) {
    if (chapterIndex < 0 || chapterIndex >= _chaptersDraft.length) return;
    final chapter = _chaptersDraft[chapterIndex];
    if (pageIndex < 0 || pageIndex >= chapter.pages.length) return;
    final current = chapter.pages[pageIndex];
    if (current.title == page.title && current.body == page.body) return;
    final titleChanged = current.title != page.title;
    final chapters = [..._chaptersDraft];
    final pages = [...chapters[chapterIndex].pages];
    pages[pageIndex] = AdminDraftPage(
      pageNumber: pages[pageIndex].pageNumber,
      title: page.title,
      body: page.body,
      localId: current.localId,
    );
    chapters[chapterIndex] = AdminDraftChapter(
      chapterKey: chapters[chapterIndex].chapterKey,
      title: chapters[chapterIndex].title,
      pages: pages,
    );
    // Avoid setState on body-only edits — rebuilding steals Quill focus into the
    // title field. Refresh the tree only when the tab label (title) changes.
    _chaptersDraft = _withConsecutivePageNumbers(chapters);
    _dirty = true;
    _bookDraft.onChanged();
    if (titleChanged && mounted) setState(() {});
  }

  /// Prefer patching by stable [localId] so dispose/reorder cannot write to the
  /// wrong index after the list has moved.
  void _patchPageByLocalId(
    int chapterIndex,
    String localId,
    AdminDraftPage page,
  ) {
    if (chapterIndex < 0 || chapterIndex >= _chaptersDraft.length) return;
    final pages = _chaptersDraft[chapterIndex].pages;
    final pageIndex = pages.indexWhere((p) => p.localId == localId);
    if (pageIndex < 0) return;
    _patchPageAt(
      chapterIndex,
      pageIndex,
      AdminDraftPage(
        pageNumber: page.pageNumber,
        title: page.title,
        body: page.body,
        localId: localId,
      ),
    );
  }

  void _addBlankPage(int chapterIndex) {
    final chapters = [..._chaptersDraft];
    final pages = [
      ...chapters[chapterIndex].pages,
      AdminDraftPage(pageNumber: 0, title: '', body: ''),
    ];
    chapters[chapterIndex] = AdminDraftChapter(
      chapterKey: chapters[chapterIndex].chapterKey,
      title: chapters[chapterIndex].title,
      pages: pages,
    );
    _setChaptersDraft(chapters);
    setState(() {
      _section = _BookEditSection.content;
      _previewPageIndex = pages.length - 1;
    });
  }

  void _moveChapter(int index, int step) {
    final target = index + step;
    if (target < 0 || target >= _chaptersDraft.length) return;
    _reorderChapters(index, target > index ? target + 1 : target);
  }

  /// [newIndex] uses [ReorderableListView] semantics (may be `length` / after remove).
  void _reorderChapters(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _chaptersDraft.length) return;
    if (newIndex < 0 || newIndex >= _chaptersDraft.length) return;

    final next = [..._chaptersDraft];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);

    final selected = _selectedChapterIndex;
    int? nextSelected = selected;
    if (selected == oldIndex) {
      nextSelected = newIndex;
    } else if (selected != null) {
      if (oldIndex < selected && newIndex >= selected) {
        nextSelected = selected - 1;
      } else if (oldIndex > selected && newIndex <= selected) {
        nextSelected = selected + 1;
      }
    }

    final renaming = _renamingChapterIndex;
    int? nextRenaming = renaming;
    if (renaming == oldIndex) {
      nextRenaming = newIndex;
    } else if (renaming != null) {
      if (oldIndex < renaming && newIndex >= renaming) {
        nextRenaming = renaming - 1;
      } else if (oldIndex > renaming && newIndex <= renaming) {
        nextRenaming = renaming + 1;
      }
    }

    _setChaptersDraft(next);
    setState(() {
      _selectedChapterIndex = nextSelected;
      _renamingChapterIndex = nextRenaming;
    });
  }

  void _reorderPages(int chapterIndex, int oldIndex, int newIndex) {
    final pages = _chaptersDraft[chapterIndex].pages;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= pages.length) return;
    if (newIndex < 0 || newIndex >= pages.length) return;

    // Flush the open editor into the page it's bound to (by localId) before
    // indices move — avoids dispose writing into the wrong slot.
    _flushLivePageEditor();

    final selectedLocalId = pages[_clampedPreviewPageIndex(
      _chaptersDraft[chapterIndex],
    )].localId;

    final chapters = [..._chaptersDraft];
    final nextPages = [...chapters[chapterIndex].pages];
    final item = nextPages.removeAt(oldIndex);
    nextPages.insert(newIndex, item);
    chapters[chapterIndex] = AdminDraftChapter(
      chapterKey: chapters[chapterIndex].chapterKey,
      title: chapters[chapterIndex].title,
      pages: nextPages,
    );

    final preview = nextPages.indexWhere((p) => p.localId == selectedLocalId);
    _setChaptersDraft(chapters);
    setState(() => _previewPageIndex = preview < 0 ? newIndex : preview);
  }

  void _deletePreviewPage(int chapterIndex) {
    final chapter = _chaptersDraft[chapterIndex];
    if (chapter.pages.isEmpty) return;
    _flushLivePageEditor();
    final pIndex = _clampedPreviewPageIndex(chapter);
    final chapters = [..._chaptersDraft];
    final pages = [...chapters[chapterIndex].pages]..removeAt(pIndex);
    chapters[chapterIndex] = AdminDraftChapter(
      chapterKey: chapters[chapterIndex].chapterKey,
      title: chapters[chapterIndex].title,
      pages: pages,
    );
    _setChaptersDraft(chapters);
    setState(() {
      if (pages.isEmpty) {
        _previewPageIndex = 0;
      } else if (_previewPageIndex >= pages.length) {
        _previewPageIndex = pages.length - 1;
      }
    });
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
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(l10n.createBookFirstValidate),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiDioProvider);
      final res = await dio.get<Map<String, dynamic>>(
        'admin/books/$bookId/validate-draft',
      );
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
                        ...warnings.map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $w'),
                          ),
                        ),
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
        _error =
            messageFromDioResponse(e.response?.data) ??
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
    // Bible books have no page-based chapters (content is verses, managed in the
    // Bible workspace); skip the page-chapter validation for them.
    // PDF books use a binary package instead of chapters.
    if (!_isBible && !_isPdfBook) {
      final chaptersError = _validateChaptersDraft(l10n);
      if (chaptersError != null) {
        setState(() => _error = chaptersError);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiDioProvider);
      final scriptTags = _scriptTagsList;
      final chaptersDraftPayload = _chaptersDraft
          .map((e) => e.toDraftPayload())
          .toList();
      final commissionPercent =
          ref.read(commissionRateProvider).valueOrNull ??
          AppConfig.defaultCommissionPercent;
      final listedEtb = _pricePayload(_priceEtb, commissionPercent);
      final listedUsd = _pricePayload(_priceUsd, commissionPercent);
      final listedPrice = listedUsd > 0 ? listedUsd : listedEtb;
      final listedCurrency = listedUsd > 0
          ? 'USD'
          : (listedEtb > 0 ? 'ETB' : 'USD');
      if (widget.isNew) {
        final res = await dio.post<Map<String, dynamic>>(
          'admin/books',
          data: {
            'title': _title.text.trim(),
            'subtitle': _subtitle.text.trim(),
            'summary': _summary.text.trim(),
            'author_compiler': _author.text.trim(),
            'primary_language': _language.text.trim().isEmpty
                ? 'am'
                : _language.text.trim(),
            'script_tags': scriptTags,
            if (_genre != null) 'genre': _genre,
            'is_bible': _isBible,
            'testament_type': _isBible ? (_testament ?? '') : '',
            if (_publishedYear.text.trim().isNotEmpty)
              'published_year': int.tryParse(_publishedYear.text.trim()),
            'is_premium': _isPremium,
            'is_featured': _isFeatured,
            'currency': listedCurrency,
            'price': listedPrice,
            'price_etb': listedEtb,
            'price_usd': listedUsd,
            'sale_price': null,
            'chapters_draft': chaptersDraftPayload,
          },
        );
        _applyChaptersFromResponse(res.data);
        final newId = res.data?['id'] as String?;
        if (newId != null && kAdminCoverUploadEnabled) {
          await _uploadCoverForBook(dio, newId);
        }
        if (newId != null && _isPdfBook) {
          await _uploadPdfForBook(dio, newId);
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
            'primary_language': _language.text.trim().isEmpty
                ? 'am'
                : _language.text.trim(),
            'script_tags': scriptTags,
            'genre': _genre ?? '',
            'is_bible': _isBible,
            'testament_type': _isBible ? (_testament ?? '') : '',
            'published_year': _publishedYear.text.trim().isEmpty
                ? null
                : int.tryParse(_publishedYear.text.trim()),
            'is_premium': _isPremium,
            'is_featured': _isFeatured,
            'currency': listedCurrency,
            'price': listedPrice,
            'price_etb': listedEtb,
            'price_usd': listedUsd,
            'sale_price': null,
            'chapters_draft': chaptersDraftPayload,
          },
        );
        _applyChaptersFromResponse(res.data);
        if (kAdminCoverUploadEnabled) {
          await _uploadCoverForBook(dio, bookId);
        }
        if (_isPdfBook) {
          await _uploadPdfForBook(dio, bookId);
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
        _error =
            messageFromDioResponse(e.response?.data) ??
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
    final current = _language.text.trim().isEmpty
        ? 'am'
        : _language.text.trim();
    final codes = [
      ..._languageCodes,
      if (!_languageCodes.contains(current)) current,
    ];
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: _inputDecoration(),
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
    if (selected != null && !years.contains(selected))
      years.insert(0, selected);
    return DropdownButtonFormField<int?>(
      initialValue: selected,
      isExpanded: true,
      decoration: _inputDecoration(),
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

  Widget _buildPricingFields(
    AppLocalizations l10n, {
    required bool sideBySide,
  }) {
    final commissionPercent =
        ref.watch(commissionRateProvider).valueOrNull ??
        AppConfig.defaultCommissionPercent;
    final etbAuthor = _parsePriceInput(_priceEtb.text) ?? 0;
    final usdAuthor = _parsePriceInput(_priceUsd.text) ?? 0;
    final etbListed = _listedPriceFromAuthor(etbAuthor, commissionPercent);
    final usdListed = _listedPriceFromAuthor(usdAuthor, commissionPercent);
    final percentLabel = commissionPercent == commissionPercent.roundToDouble()
        ? commissionPercent.toInt().toString()
        : commissionPercent.toString();
    final String description;
    if (etbAuthor > 0 && usdAuthor > 0) {
      description = l10n.adminServiceFeeDualDescription(
        percentLabel,
        formatMoney(etbListed, 'ETB'),
        formatMoney(usdListed, 'USD'),
      );
    } else if (etbAuthor > 0 && commissionPercent > 0) {
      description = l10n.adminServiceFeeDescription(
        percentLabel,
        formatMoney(etbListed, 'ETB'),
      );
    } else if (usdAuthor > 0 && commissionPercent > 0) {
      description = l10n.adminServiceFeeDescription(
        percentLabel,
        formatMoney(usdListed, 'USD'),
      );
    } else {
      description = l10n.adminServiceFeeEmptyDescription(percentLabel);
    }
    final etbField = _labeled(
      l10n.adminPriceEtbLabel,
      TextFormField(
      controller: _priceEtb,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _inputDecoration().copyWith(prefixText: 'Br '),
      validator: (value) => _validateOptionalPrice(value, l10n),
      onChanged: (_) {
        setState(() {});
        _markDirty();
      },
      ),
    );
    final usdField = _labeled(
      l10n.adminPriceUsdLabel,
      TextFormField(
      controller: _priceUsd,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _inputDecoration().copyWith(prefixText: r'$ '),
      validator: (value) => _validateOptionalPrice(value, l10n),
      onChanged: (_) {
        setState(() {});
        _markDirty();
      },
      ),
    );
    final fields = sideBySide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: etbField),
              const SizedBox(width: 16),
              Expanded(child: usdField),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [etbField, const SizedBox(height: 12), usdField],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fields,
        const SizedBox(height: 12),
        Text(
          l10n.adminServiceFeeTitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBibleControls(AppLocalizations l10n, bool isNew) {
    if (!_isBible) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _labeled(
          l10n.adminTestamentLabel,
          DropdownButtonFormField<String?>(
            initialValue: _testament,
            isExpanded: true,
            decoration: _inputDecoration(),
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
        ),
        if (isNew || !_persistedIsBible) ...[
          const SizedBox(height: 8),
              Text(
                l10n.adminBibleSaveFirst,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _BookFormColors.muted,
            ),
          ),
        ],
      ],
    );
  }

  String _contentSectionLabel(AppLocalizations l10n) {
    if (_isBible) return l10n.bookEditSectionBible;
    if (_isPdfBook) return l10n.pdfDocumentSection;
    return l10n.chaptersPagesSection;
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
      decoration: _inputDecoration(),
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

  /// Full-width content section: Bible workspace, PDF upload, or chapters.
  Widget _contentSectionPane(
    BuildContext context,
    AppLocalizations l10n,
    bool isNew, {
    required bool expand,
  }) {
    if (_isBible) {
      if (isNew || widget.bookId == null || !_persistedIsBible) {
        return _BookFormCard(
          title: l10n.bookEditSectionBible,
          subtitle: l10n.adminBibleSaveFirst,
          child: const SizedBox(height: 8),
        );
      }
      final workspace = BibleContentWorkspace(bookId: widget.bookId!);
      return _BookFormCard(
        title: l10n.bookEditSectionBible,
        subtitle: l10n.adminIsBibleSubtitle,
        expandChild: expand,
        child: expand ? workspace : SizedBox(height: 560, child: workspace),
      );
    }
    if (_isPdfBook) {
      // Match chapters pane: no bulky card header — rail already names the section.
      return _BookFormCard(
        expandChild: expand,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: expand
            ? _pdfWorkspace(context, l10n, isNew)
            : SizedBox(
                height: 640,
                child: _pdfWorkspace(context, l10n, isNew),
              ),
      );
    }
    // Chapters list lives in the section rail; main pane is pages only.
    // No card header — the bold chapter title in the pages pane is enough.
    final selected = _clampedChapterIndex();
    final chapter = selected == null ? null : _chaptersDraft[selected];
    final pages = _BookFormCard(
      expandChild: expand,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: expand
          ? _pagesPane(context, l10n, isNew, selected, chapter)
          : SizedBox(
              height: 480,
              child: _pagesPane(context, l10n, isNew, selected, chapter),
            ),
    );
    return pages;
  }

  bool get _chaptersLiveInSectionRail => !_isBible && !_isPdfBook;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _pdfWorkspace(
    BuildContext context,
    AppLocalizations l10n,
    bool isNew,
  ) {
    final pendingName = _pendingPdfFilename;
    final server = _serverPdfDraft;
    // Treat any stored draft with a key as present — "ready" can lag after
    // older uploads that never wrote size_bytes.
    final hasServerPdf =
        server != null && (server.ready || server.revisionId.isNotEmpty);
    final hasPending = pendingName != null;
    final theme = Theme.of(context);

    final statusText = hasPending
        ? pendingName!
        : hasServerPdf
            ? l10n.pdfReadyLabel(
                server.filename,
                _formatBytes(server.sizeBytes),
              )
            : l10n.pdfUploadHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact toolbar — one row like chapter title bars, not a tall stack.
        Row(
          children: [
            Icon(
              hasPending || hasServerPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.upload_file_outlined,
              size: 20,
              color: _BookFormColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (hasPending)
              IconButton(
            tooltip: l10n.pdfRemoveFile,
                visualDensity: VisualDensity.compact,
            onPressed: _busy
                ? null
                : () => setState(() {
                    _pendingPdfBytes = null;
                    _pendingPdfFilename = null;
                    _markDirty();
                  }),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
            onPressed: _busy ? null : _pickPdfFile,
              style: _chapterOutlineButtonStyle(),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(
              (hasServerPdf || hasPending)
                  ? l10n.pdfReplaceFile
                  : l10n.pdfPickFile,
            ),
          ),
            if (hasServerPdf && !isNew) ...[
              const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _busy ? null : _removeServerPdf,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.crimson,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.pdfRemoveFile),
            ),
            ],
        ],
      ),
        if (hasPending) ...[
          const SizedBox(height: 4),
        Text(
            l10n.pdfPendingUpload,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
        const SizedBox(height: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _BookFormColors.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: _AdminPdfPreviewPane(
                bookId: widget.bookId,
                revisionId: server?.revisionId,
                pendingBytes: _pendingPdfBytes,
                pendingName: _pendingPdfFilename,
                hasServerPdf: hasServerPdf,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lookInsideSectionPane(
    BuildContext context,
    AppLocalizations l10n,
    bool isNew, {
    required bool expand,
  }) {
    final server = _serverPdfDraft;
    final hasServerPdf =
        server != null && (server.ready || server.revisionId.isNotEmpty);
    final theme = Theme.of(context);
    final pageCount = server?.pageCount;

    // Compact full-width top strip; PDF preview uses the remaining width.
    final header = SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.preview_outlined,
            size: 20,
            color: _BookFormColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pageCount != null
                  ? '${l10n.pdfPreviewPagesSection} · $pageCount'
                  : l10n.pdfPreviewPagesSection,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (hasServerPdf && !isNew) ...[
            OutlinedButton(
              onPressed: _busy ? null : _suggestFirstFivePreviewPages,
              style: _chapterOutlineButtonStyle(),
              child: Text(l10n.pdfPreviewPagesSuggest),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _busy ? null : _savePreviewPages,
              style: FilledButton.styleFrom(
                backgroundColor: _BookFormColors.accent,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(l10n.pdfPreviewPagesSave),
            ),
          ],
        ],
      ),
    );

    final pageControls = !hasServerPdf || isNew
        ? Text(
            l10n.pdfUploadHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
        Text(
                l10n.pdfPreviewPagesHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
              const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final page in _previewPages)
            InputChip(
              label: Text('$page'),
                      visualDensity: VisualDensity.compact,
              onDeleted: _busy
                  ? null
                  : () => setState(() {
                      _previewPages = _previewPages
                          .where((p) => p != page)
                          .toList();
                      _markDirty();
                    }),
            ),
                  SizedBox(
                    width: 160,
                    child: TextField(
        controller: _previewPageInput,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.pdfPreviewPageField,
          isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
          suffixIcon: IconButton(
            tooltip: l10n.pdfPreviewPagesAdd,
            onPressed: _busy ? null : _addPreviewPage,
            icon: const Icon(Icons.add),
          ),
        ),
        onSubmitted: (_) => _addPreviewPage(),
      ),
                  ),
                ],
              ),
            ],
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        pageControls,
        const SizedBox(height: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _BookFormColors.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: _AdminPdfPreviewPane(
                bookId: widget.bookId,
                revisionId: server?.revisionId,
                pendingBytes: _pendingPdfBytes,
                pendingName: _pendingPdfFilename,
                hasServerPdf: hasServerPdf,
                // Live Look Inside: filter the full PDF to the selected
                // pages so the editor preview updates without saving.
                onlyPages: _previewPages,
              ),
            ),
          ),
        ),
      ],
    );

    return _BookFormCard(
      expandChild: expand,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: expand
          ? body
          : SizedBox(height: 640, child: body),
    );
  }

  ButtonStyle _chapterOutlineButtonStyle() => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: _BookFormColors.accent,
    backgroundColor: Colors.white,
    side: const BorderSide(color: _BookFormColors.accent, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  /// Narrow layout fallback: chapter list beside pages (no section rail).
  Widget _chaptersWorkspaceNarrow(
    BuildContext context,
    AppLocalizations l10n,
    bool isNew,
  ) {
    final selected = _clampedChapterIndex();
    final chapter = selected == null ? null : _chaptersDraft[selected];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _BookFormColors.line),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 240,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    right: BorderSide(color: _BookFormColors.line),
                  ),
                ),
                child: _chapterSidebar(context, l10n, selected),
              ),
            ),
            Expanded(
              child: _pagesPane(context, l10n, isNew, selected, chapter),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chapterSidebarForm(AppLocalizations l10n) {
    final renaming = _renamingChapterIndex != null;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _BookFormColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              renaming ? l10n.editChapterTooltip : l10n.addChapter,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _BookFormColors.label,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _chapterTitleInput,
              autofocus: renaming,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitChapterInline(),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.chapterNameHint,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _BookFormColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _BookFormColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: _BookFormColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
        children: [
                if (renaming) ...[
          Expanded(
                    child: TextButton(
                      onPressed: _resetChapterForm,
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  flex: renaming ? 1 : 1,
                  child: FilledButton(
                    onPressed: _commitChapterInline,
                    style: FilledButton.styleFrom(
                      backgroundColor: _BookFormColors.accent,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(renaming ? l10n.save : l10n.addChapter),
                  ),
          ),
        ],
      ),
          ],
        ),
      ),
    );
  }

  Widget _chapterSidebar(
    BuildContext context,
    AppLocalizations l10n,
    int? selected, {
    bool showHeader = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              l10n.chaptersPagesSection,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        Expanded(
          child: _chaptersDraft.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Text(
          l10n.noChaptersYetHelp,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _chaptersDraft.length,
                  onReorder: _reorderChapters,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final t = Curves.easeInOut.transform(animation.value);
                        return Material(
                          elevation: 2 + 4 * t,
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          shadowColor: Colors.black26,
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, cIndex) {
                    final chapter = _chaptersDraft[cIndex];
                    final isSelected = cIndex == selected;
                    final key = chapter.chapterKey.isNotEmpty
                        ? ValueKey('ch-${chapter.chapterKey}')
                        : ValueKey('ch-i$cIndex-${chapter.title}');
                    return Material(
                      key: key,
                      color: isSelected
                          ? _BookFormColors.accentSoft
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _flushLivePageEditor();
                          setState(() {
                            _selectedChapterIndex = cIndex;
                            _section = _BookEditSection.content;
                            _previewPageIndex = 0;
                            if (_renamingChapterIndex != cIndex) {
                              _renamingChapterIndex = null;
                              _chapterTitleInput.clear();
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ReorderableDragStartListener(
                                index: cIndex,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    right: 4,
                                  ),
                                  child: Icon(
                                    Icons.drag_indicator,
                                    size: 18,
                                    color: isSelected
                                        ? _BookFormColors.accent
                                        : _BookFormColors.muted,
                                  ),
                                ),
                              ),
                              Container(
                                width: 3,
                                height: 36,
                                margin: const EdgeInsets.only(
                                  right: 8,
                                  top: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _BookFormColors.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Expanded(
                                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? _BookFormColors.accent
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                    Text(
                      l10n.pageCount(chapter.pages.length),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                            tooltip: l10n.editChapterTooltip,
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: isSelected
                                      ? _BookFormColors.accent
                                      : _BookFormColors.muted,
                                ),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'up':
                                      _moveChapter(cIndex, -1);
                                    case 'down':
                                      _moveChapter(cIndex, 1);
                                    case 'rename':
                                      _beginRenameChapter(cIndex);
                                    case 'delete':
                                      if (_renamingChapterIndex == cIndex) {
                                        _resetChapterForm();
                                      }
                              final next = [..._chaptersDraft]
                                ..removeAt(cIndex);
                              _setChaptersDraft(next);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text(l10n.editChapterTooltip),
                                  ),
                                  PopupMenuItem(
                                    value: 'up',
                                    enabled: cIndex > 0,
                                    child: Text(l10n.moveUpTooltip),
                                  ),
                                  PopupMenuItem(
                                    value: 'down',
                                    enabled:
                                        cIndex < _chaptersDraft.length - 1,
                                    child: Text(l10n.moveDownTooltip),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.deleteChapterTooltip),
                          ),
                        ],
                      ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _chapterSidebarForm(l10n),
      ],
    );
  }

  Widget _pagesPane(
    BuildContext context,
    AppLocalizations l10n,
    bool isNew,
    int? selected,
    AdminDraftChapter? chapter,
  ) {
    if (chapter == null || selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.selectChapterToManagePages,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final previewIndex = chapter.pages.isEmpty
        ? 0
        : _clampedPreviewPageIndex(chapter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (!isNew)
                TextButton.icon(
                  onPressed: _busy ? null : _validateDraftOnServer,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _BookFormColors.accent,
                  ),
                  icon: const Icon(Icons.rule_folder_outlined, size: 18),
                  label: Text(l10n.validateDraft),
                ),
            ],
          ),
        ),
        _browserPageTabs(context, l10n, selected, chapter, previewIndex),
        Expanded(
          child: chapter.pages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                          l10n.noPagesYet,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _addBlankPage(selected),
                          style: _chapterOutlineButtonStyle(),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.addPage),
                        ),
                      ],
                    ),
                  ),
                )
              : _DraftPageEditor(
                  key: _livePageEditorKey,
                  isNewPage: false,
                  live: true,
                  pageLocalId: chapter.pages[previewIndex].localId,
                  initialTitle: chapter.pages[previewIndex].title,
                  initialBody: chapter.pages[previewIndex].body,
                  draftKey: FormDraftKeys.scope(
                    userId: _draftUserId(),
                    formKey: FormDraftKeys.adminBookPage(
                      bookId: widget.bookId,
                      chapterIndex: selected,
                      pageIndex: previewIndex,
                      isNew: false,
                    ),
                  ),
                  onLiveCommit: (page) => _patchPageByLocalId(
                    selected,
                    page.localId,
                    page,
                  ),
                  onDelete: () => _deletePreviewPage(selected),
                ),
        ),
      ],
    );
  }

  Widget _browserPageTabs(
    BuildContext context,
    AppLocalizations l10n,
    int chapterIndex,
    AdminDraftChapter chapter,
    int previewIndex,
  ) {
    // Restore the clear folder-tab look. Selected tab is white with an
    // accent crown; a white bridge covers the strip baseline so it opens
    // into the editor without a line through the active page.
    const tabRadius = BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    );
    Widget tabFace({
      required bool isActive,
      required String label,
      required bool showTrailingDivider,
      required VoidCallback onSelect,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: tabRadius,
          onTap: onSelect,
          child: Ink(
            // Active: white sheet over the baseline.
            // Idle: transparent; optional short mid-height divider that does
            // not touch the strip top/bottom edges.
            height: isActive ? 36 : 28,
            width: 132,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: isActive ? tabRadius : BorderRadius.zero,
              border: isActive
                  ? const Border(
                      top: BorderSide(
                        color: _BookFormColors.accent,
                        width: 3,
                      ),
                      left: BorderSide(
                        color: _BookFormColors.accent,
                        width: 1.5,
                      ),
                      right: BorderSide(
                        color: _BookFormColors.accent,
                        width: 1.5,
                      ),
                    )
                  : null,
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: showTrailingDivider ? 8 : 12,
            ),
                            child: Row(
                              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w600,
                      color: isActive
                          ? _BookFormColors.accent
                          : _BookFormColors.label,
                    ),
                  ),
                ),
                if (showTrailingDivider)
                  Container(
                    width: 2,
                    height: 14,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: _BookFormColors.accent.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: _BookFormColors.accentSoft),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ColoredBox(
              color: _BookFormColors.line,
              child: SizedBox(height: 1),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: _BookFormColors.accent,
              child: SizedBox(height: 2),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: chapter.pages.isEmpty
                    ? const SizedBox.shrink()
                    : ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(8, 6, 0, 0),
                        itemCount: chapter.pages.length,
                        onReorder: (oldIndex, newIndex) =>
                            _reorderPages(chapterIndex, oldIndex, newIndex),
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            elevation: 4,
                            color: Colors.white,
                            borderRadius: tabRadius,
                            shadowColor: Colors.black26,
                            child: child,
                          );
                        },
                        itemBuilder: (context, pIndex) {
                          final page = chapter.pages[pIndex];
                          final isActive = pIndex == previewIndex;
                          final label = page.title.trim().isEmpty
                              ? l10n.pageTitleFallback(page.pageNumber)
                              : page.title;
                          // Divider only between idle tabs. Skip when the
                          // next tab is active (its left frame is enough)
                          // or when this is the last tab.
                          final nextIsActive =
                              pIndex + 1 == previewIndex;
                          final showTrailingDivider = !isActive &&
                              pIndex < chapter.pages.length - 1 &&
                              !nextIsActive;
                          return ReorderableDragStartListener(
                            key: ValueKey('tab-${page.localId}'),
                            index: pIndex,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                // Idle clears the 2px accent baseline so it
                                // does not overflow the strip edge.
                                padding: EdgeInsets.only(
                                  right: 6,
                                  bottom: isActive ? 0 : 2,
                                ),
                                child: tabFace(
                                  isActive: isActive,
                                  label: label,
                                  showTrailingDivider: showTrailingDivider,
                                  onSelect: () {
                                    if (pIndex == _previewPageIndex) {
                                      return;
                                    }
                                    _flushLivePageEditor();
                                    setState(
                                      () => _previewPageIndex = pIndex,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 8, 8),
                child: Tooltip(
                  message: l10n.addPage,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(color: _BookFormColors.accent),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _addBlankPage(chapterIndex),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: _BookFormColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) =>
      _bookFieldDecoration(hintText: hintText);

  Widget _labeled(String label, Widget field, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label, requiredMark: required),
        const SizedBox(height: 5),
        field,
      ],
    );
  }

  Widget _pair(bool sideBySide, Widget a, Widget b) {
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, const SizedBox(height: 14), b],
      );
    }
    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: a),
        const SizedBox(width: 14),
                        Expanded(child: b),
                      ],
    );
  }

  bool get _hasCover =>
      _pendingCoverBytes != null ||
      (!_clearCoverOnSave &&
          _serverCoverGetUrl != null &&
          _serverCoverGetUrl!.isNotEmpty);

  Widget _coverPreview() {
    final Widget image;
    if (_pendingCoverBytes != null) {
      image = Image.memory(_pendingCoverBytes!, fit: BoxFit.cover);
    } else if (_hasCover && _serverCoverGetUrl != null) {
      image = Image.network(
        _serverCoverGetUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: _BookFormColors.muted,
        ),
      );
    } else {
      image = const Icon(
        Icons.image_outlined,
        size: 32,
        color: _BookFormColors.muted,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 96,
        height: 128,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _BookFormColors.line),
        ),
        child: image,
      ),
    );
  }

  Widget _coverDropZone(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            OutlinedButton.icon(
              onPressed: _pickCoverImage,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                foregroundColor: _BookFormColors.ink,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _BookFormColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(l10n.chooseImage),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.coverFormatHelp,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: _BookFormColors.muted,
              ),
            ),
            TextButton(
              onPressed: _hasCover ? _clearCover : null,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: _BookFormColors.muted,
                disabledForegroundColor: _BookFormColors.faint,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(l10n.removeCover),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeCard(AppLocalizations l10n, bool isNew) {
    return _BookFormCard(
      title: l10n.bookTypeSection,
      subtitle: l10n.bookTypeSectionHelp,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      headerGap: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToggleRow(
            title: l10n.adminIsBibleLabel,
            subtitle: l10n.adminIsBibleSubtitle,
            value: _isBible,
            onChanged: (v) {
              setState(() {
                _isBible = v;
                if (v) {
                  _isPdfBook = false;
                  _pendingPdfBytes = null;
                  _pendingPdfFilename = null;
                  if (_section == _BookEditSection.lookInside) {
                    _section = _BookEditSection.content;
                  }
                }
                if (!v) _testament = null;
              });
              _markDirty();
            },
          ),
          _ToggleRow(
            title: l10n.pdfBookTypeLabel,
            subtitle: l10n.pdfBookTypeHelp,
            value: _isPdfBook,
            onChanged: (v) {
              setState(() {
                _isPdfBook = v;
                if (v) {
                  _isBible = false;
                  _testament = null;
                } else {
                  _pendingPdfBytes = null;
                  _pendingPdfFilename = null;
                  if (_section == _BookEditSection.lookInside) {
                    _section = _BookEditSection.content;
                  }
                }
              });
              _markDirty();
            },
          ),
          _ToggleRow(
            title: l10n.adminIsPremiumLabel,
            subtitle: l10n.adminIsPremiumSubtitle,
            value: _isPremium,
            onChanged: (v) {
              setState(() => _isPremium = v);
              _markDirty();
            },
          ),
          _ToggleRow(
            title: l10n.adminIsFeaturedLabel,
            subtitle: l10n.adminIsFeaturedSubtitle,
            value: _isFeatured,
            onChanged: (v) {
              setState(() => _isFeatured = v);
              _markDirty();
            },
          ),
          _buildBibleControls(l10n, isNew),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, AppLocalizations l10n, bool isNew) {
    final busy = _busy || (!_loaded && !isNew);
    final cancel = OutlinedButton(
      onPressed: busy ? null : () => Navigator.of(context).maybePop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        foregroundColor: _BookFormColors.label,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _BookFormColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(l10n.cancel),
    );
    final save = FilledButton(
      onPressed: busy ? null : _save,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        backgroundColor: _BookFormColors.accent,
        disabledBackgroundColor: _BookFormColors.accent.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(isNew ? l10n.createBookAction : l10n.saveChanges),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cancel, const SizedBox(height: 12), save],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [cancel, const SizedBox(width: 12), save],
        );
      },
    );
  }

  Widget _formCards(
    BuildContext context,
    AppLocalizations l10n,
    bool isNew, {
    required bool sideBySide,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                            if (_latestReviewNote?.isChangesRequested == true &&
                                _reviewStatus == 'draft') ...[
                              _ChangesRequestedBanner(
                                note: _latestReviewNote!,
            onViewHistory: () =>
                context.push('/admin/books/${widget.bookId}/review'),
          ),
          const SizedBox(height: 14),
        ],
        _BookFormCard(
          title: l10n.metadataSection,
          subtitle: l10n.bookDetailsHelp,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _labeled(
                l10n.titleFieldLabel,
                            TextFormField(
                              controller: _title,
                  decoration: _inputDecoration(hintText: l10n.titlePlaceholder),
                              textCapitalization: TextCapitalization.sentences,
                              validator: (value) {
                    if ((value ?? '').trim().isEmpty) return l10n.titleRequired;
                                return null;
                              },
                              onChanged: (_) => _markDirty(),
                            ),
                required: true,
              ),
              const SizedBox(height: 14),
              _labeled(
                l10n.subtitleLabel,
                            TextField(
                              controller: _subtitle,
                  decoration: _inputDecoration(
                    hintText: l10n.subtitlePlaceholder,
                              ),
                              onChanged: (_) => _markDirty(),
                            ),
              ),
              const SizedBox(height: 14),
              _labeled(
                l10n.adminSummaryLabel,
                            TextField(
                              controller: _summary,
                  decoration: _inputDecoration(
                    hintText: l10n.summaryPlaceholder,
                              ),
                  minLines: 3,
                  maxLines: 6,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => _markDirty(),
                            ),
              ),
              const SizedBox(height: 14),
              _pair(
                sideBySide,
                _labeled(
                  l10n.authorCompilerLabel,
                  TextField(
                    controller: _author,
                    decoration: _inputDecoration(
                      hintText: l10n.authorPlaceholder,
                    ),
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                _labeled(
                  l10n.primaryLanguageCodeLabel,
                  _buildLanguageDropdown(l10n),
                ),
              ),
              const SizedBox(height: 14),
              _ChipsField(
                label: l10n.scriptTagsLabel,
                values: _scriptTagsList,
                onChanged: (v) {
                  setState(() => _scriptTagsList = v);
                  _markDirty();
                },
              ),
            ],
          ),
        ),
        if (kAdminCoverUploadEnabled) ...[
          const SizedBox(height: 14),
          _BookFormCard(
            title: l10n.thumbnailCover,
            subtitle: l10n.coverSectionHelp,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _coverPreview(),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 128,
                    child: _coverDropZone(l10n),
                  ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
        const SizedBox(height: 14),
        _BookFormCard(
          title: l10n.adminGenreLabel,
          subtitle: l10n.genreSectionHelp,
          child: _pair(
            sideBySide,
            _labeled(l10n.adminGenreLabel, _buildGenreDropdown(l10n)),
            _labeled(l10n.adminPublishedYearLabel, _buildYearDropdown(l10n)),
          ),
        ),
        const SizedBox(height: 14),
        _typeCard(l10n, isNew),
        if (_isPremium) ...[
          const SizedBox(height: 14),
          _BookFormCard(
            title: l10n.adminPricingSection,
            subtitle: l10n.adminDualPriceHint,
            child: _buildPricingFields(l10n, sideBySide: sideBySide),
          ),
        ],
      ],
    );
  }

  EdgeInsets _editorPagePadding(BuildContext context) {
    if (useWebShell(context)) {
      return WebTokens.pagePaddingOf(context);
    }
    if (useDesktopShell(context)) {
      return DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));
    }
    return const EdgeInsets.fromLTRB(16, 20, 16, 36);
  }

  Widget _sectionNavItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final fg = selected ? _BookFormColors.accent : _BookFormColors.label;
    final bg = selected ? _BookFormColors.accentSoft : Colors.transparent;
    final labelText = Text(
      label,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: fg,
      ),
    );
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              if (compact) labelText else Expanded(child: labelText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookEditSectionRail(AppLocalizations l10n) {
    // Chapter list + add form always sit in the rail for normal books —
    // no need to click "Chapters & pages" first.
    final chaptersInRail = _chaptersLiveInSectionRail;
    final selected = _clampedChapterIndex();

    return SizedBox(
      width: chaptersInRail ? 280 : 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _BookFormColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pin section nav to the top edge so the rail matches the
            // content card top-to-bottom without floating mid-panel.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionNavItem(
                    label: l10n.metadataSection,
                    icon: Icons.edit_note_outlined,
                    selected: _section == _BookEditSection.details,
                    onTap: _selectDetailsSection,
                  ),
                  // Bible / PDF still need a content switcher; chapters live
                  // in the rail below (no separate "Chapters & pages" item).
                  if (!chaptersInRail) ...[
                    const SizedBox(height: 4),
                    _sectionNavItem(
                      label: _contentSectionLabel(l10n),
                      icon: _isBible
                          ? Icons.menu_book_outlined
                          : Icons.picture_as_pdf_outlined,
                      selected: _section == _BookEditSection.content,
                      onTap: _selectContentSection,
                    ),
                    if (_isPdfBook) ...[
                      const SizedBox(height: 4),
                      _sectionNavItem(
                        label: l10n.pdfPreviewPagesSection,
                        icon: Icons.preview_outlined,
                        selected: _section == _BookEditSection.lookInside,
                        onTap: _selectLookInsideSection,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (chaptersInRail) ...[
              const Divider(height: 1, color: _BookFormColors.line),
              Expanded(
                child: _chapterSidebar(
                  context,
                  l10n,
                  // Only highlight a chapter while the pages pane is active.
                  _section == _BookEditSection.content ? selected : null,
                  showHeader: true,
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  void _selectDetailsSection() {
    if (_section == _BookEditSection.details) return;
    _flushLivePageEditor();
    setState(() => _section = _BookEditSection.details);
  }

  void _selectContentSection() {
    if (_section == _BookEditSection.content) return;
    setState(() => _section = _BookEditSection.content);
  }

  void _selectLookInsideSection() {
    if (_section == _BookEditSection.lookInside) return;
    setState(() => _section = _BookEditSection.lookInside);
  }

  int get _sectionStackIndex {
    switch (_section) {
      case _BookEditSection.details:
        return 0;
      case _BookEditSection.content:
        return 1;
      case _BookEditSection.lookInside:
        return _isPdfBook ? 2 : 1;
    }
  }

  Widget _bookEditSectionTabs(AppLocalizations l10n) {
    // Normal books: only Book details in the tab strip (chapters are inline).
    // Bible / PDF keep a content tab; PDF also has Look Inside.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _sectionNavItem(
            label: l10n.metadataSection,
            icon: Icons.edit_note_outlined,
            selected: _section == _BookEditSection.details,
            compact: true,
            onTap: _selectDetailsSection,
          ),
          if (!_chaptersLiveInSectionRail) ...[
            const SizedBox(width: 6),
            _sectionNavItem(
              label: _contentSectionLabel(l10n),
              icon: _isBible
                  ? Icons.menu_book_outlined
                  : Icons.picture_as_pdf_outlined,
              selected: _section == _BookEditSection.content,
              compact: true,
              onTap: _selectContentSection,
            ),
            if (_isPdfBook) ...[
              const SizedBox(width: 6),
              _sectionNavItem(
                label: l10n.pdfPreviewPagesSection,
                icon: Icons.preview_outlined,
                selected: _section == _BookEditSection.lookInside,
                compact: true,
                onTap: _selectLookInsideSection,
              ),
            ],
          ] else ...[
            const SizedBox(width: 6),
            _sectionNavItem(
              label: l10n.chaptersPagesSection,
              icon: Icons.list_alt_outlined,
              selected: _section == _BookEditSection.content,
              compact: true,
              onTap: _selectContentSection,
            ),
          ],
        ],
      ),
    );
  }

  Widget _editorFooter(BuildContext context, AppLocalizations l10n, bool isNew) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.errorText)),
          const SizedBox(height: 8),
        ],
        _actionRow(context, l10n, isNew),
      ],
    );
  }

  Widget _editorBody(BuildContext context, AppLocalizations l10n, bool isNew) {
    return LayoutBuilder(
      builder: (context, constraints) {
                final screen = MediaQuery.sizeOf(context);
        var width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                    ? constraints.maxWidth
            : (screen.width.isFinite && screen.width > 0
                  ? screen.width
                  : 1400.0);
        var height = constraints.maxHeight.isFinite && constraints.maxHeight > 0
                    ? constraints.maxHeight
            : (screen.height.isFinite && screen.height > 0
                  ? screen.height
                  : 900.0);
        if (!width.isFinite || width <= 0) width = 1400;
        if (!height.isFinite || height <= 0) height = 900;

        final pagePad = _editorPagePadding(context);
        final useRail = width >= 720;
        final sideBySide = width >= 760;
        final pageTitle = isNew ? l10n.newBookAppBar : l10n.editBookAppBar;
        final pageSubtitle = isNew
            ? l10n.newBookPageSubtitle
            : l10n.editBookPageSubtitle;

        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Text(
              pageTitle,
              style: const TextStyle(
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pageSubtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );

        // Keep both panes mounted so switching back to Book details does not
        // rebuild the whole form (that was the main source of jank).
        final detailsPane = ListView(
          key: const PageStorageKey<String>('admin-book-edit-details'),
          padding: EdgeInsets.zero,
                            children: [
            intro,
            const SizedBox(height: 16),
            _formCards(context, l10n, isNew, sideBySide: sideBySide),
            const SizedBox(height: 12),
          ],
        );

        final Widget contentPane;
        if (!useRail && _chaptersLiveInSectionRail) {
          contentPane = Column(
            key: const PageStorageKey<String>('admin-book-edit-content-narrow'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              intro,
              const SizedBox(height: 12),
              Expanded(
                child: _BookFormCard(
                  expandChild: true,
                  padding: const EdgeInsets.all(4),
                  child: _chaptersWorkspaceNarrow(context, l10n, isNew),
                ),
              ),
            ],
          );
        } else {
          contentPane = Column(
            key: const PageStorageKey<String>('admin-book-edit-content'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!useRail) ...[intro, const SizedBox(height: 12)],
              Expanded(
                child: _contentSectionPane(
                  context,
                  l10n,
                  isNew,
                  expand: true,
                ),
              ),
            ],
          );
        }

        final lookInsidePane = _isPdfBook
            ? Column(
                key: const PageStorageKey<String>(
                  'admin-book-edit-look-inside',
                ),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                      Expanded(
                    child: _lookInsideSectionPane(
                      context,
                      l10n,
                      isNew,
                      expand: true,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink();

        final mainPane = IndexedStack(
          index: _sectionStackIndex,
          sizing: StackFit.expand,
          children: [
            detailsPane,
            contentPane,
            if (_isPdfBook) lookInsidePane,
          ],
        );

        Widget shell;
        if (useRail) {
          shell = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bookEditSectionRail(l10n),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: mainPane),
                    const SizedBox(height: 12),
                    _editorFooter(context, l10n, isNew),
                  ],
                ),
              ),
            ],
          );
        } else {
          shell = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bookEditSectionTabs(l10n),
              const SizedBox(height: 12),
              Expanded(child: mainPane),
              const SizedBox(height: 12),
              _editorFooter(context, l10n, isNew),
            ],
          );
        }

        Widget content = Padding(padding: pagePad, child: shell);
        if (!constraints.maxHeight.isFinite || !constraints.maxWidth.isFinite) {
          content = SizedBox(width: width, height: height, child: content);
        }
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _BookFormColors.accent),
          ),
          child: Form(key: _formKey, child: content),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<double>>(commissionRateProvider, (prev, next) {
      final percent = next.valueOrNull;
      if (percent == null || !_pricesAreListedAmounts) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _convertListedPricesIfNeeded(percent);
        setState(() {});
      });
    });
    final l10n = AppLocalizations.of(context)!;
    final isNew = widget.isNew;
    final currentUserId = ref
        .watch(sessionNotifierProvider)
        .valueOrNull
        ?.user
        ?.id;
    final isCreator =
        isNew ||
        (currentUserId != null &&
            _createdById != null &&
            _createdById == currentUserId);
    final pageTitle = isNew ? l10n.newBookAppBar : l10n.editBookAppBar;
    final editBody = (!isNew && !_loaded)
        ? const Center(child: CircularProgressIndicator())
        : (!isNew && _visibility == 'published')
        ? AppStateView(
            title: l10n.adminPublishedBookLockedTitle,
            message: l10n.adminPublishedBookLockedMessage,
            icon: Icons.lock_outline_rounded,
            actionLabel: l10n.goBack,
            onAction: () => context.pop(),
          )
        : (!isNew && _reviewStatus == 'in_review')
        ? AppStateView(
            title: l10n.adminBookInReviewLockedTitle,
            message: l10n.adminBookInReviewLockedMessage,
            icon: Icons.rate_review_outlined,
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
        : _editorBody(context, l10n, isNew);

    void handleBack() => Navigator.of(context).maybePop();
    void openBooks() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).maybePop();
      } else {
        context.go('/admin/books');
      }
    }

    late final Widget chrome;
    if (useWebShell(context)) {
      chrome = WebOverlayScaffold(
        title: pageTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        onBack: handleBack,
        breadcrumbParent: l10n.adminBooksMenuTitle,
        onBreadcrumbParent: openBooks,
        body: ColoredBox(
          color: WebTokens.canvasBg,
          child: WebContentFrame(child: editBody),
        ),
      );
    } else if (useDesktopShell(context)) {
      chrome = DesktopOverlayScaffold(
        title: pageTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        onBack: handleBack,
        breadcrumbParent: l10n.adminBooksMenuTitle,
        onBreadcrumbParent: openBooks,
        body: ColoredBox(
          color: DesktopTokens.canvasBg,
          child: DesktopContentFrame(child: editBody),
        ),
      );
    } else {
      chrome = Scaffold(
        backgroundColor: _BookFormColors.canvas,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: handleBack,
          ),
          title: Text(pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: editBody,
      );
    }

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
      child: chrome,
    );
  }
}

/// Editable list of string values rendered as deletable chips, with a text
/// field to add new ones and optional tap-to-add suggestions.
InputDecoration _bookFieldDecoration({String? hintText}) {
  const radius = BorderRadius.all(Radius.circular(10));
  const side = BorderSide(color: _BookFormColors.border);
  return InputDecoration(
    hintText: hintText,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    hoverColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    hintStyle: const TextStyle(color: _BookFormColors.muted, fontSize: 14),
    border: const OutlineInputBorder(borderRadius: radius, borderSide: side),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: side,
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: _BookFormColors.accent, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.errorBorder),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.errorText, width: 1.5),
    ),
  );
}

class _BookFormColors {
  static const accent = Color(0xFF0277A8);
  static const accentSoft = Color(0xFFE6F4FA);
  static const ink = Color(0xFF0F172A);
  static const label = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);
  static const border = Color(0xFFCBD5E1);
  static const canvas = Color(0xFFF4F7FA);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.requiredMark = false});

  final String text;
  final bool requiredMark;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _BookFormColors.label,
        ),
        children: [
          if (requiredMark)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _BookFormCard extends StatelessWidget {
  const _BookFormCard({
    this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.headerGap = 14,
    this.expandChild = false,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final EdgeInsets padding;
  final double headerGap;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null;
    final header = !hasHeader
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: headerGap),
            ],
          );
    final body = expandChild
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) header,
              Expanded(child: child),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header != null) header,
              child,
            ],
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BookFormColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: padding, child: body),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _BookFormColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _BookSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Compact pill toggle (matches the New book mockup; avoids M3 Switch
/// shrink-wrap misalignment on web).
class _BookSwitch extends StatelessWidget {
  const _BookSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const _width = 44.0;
  static const _height = 26.0;
  static const _thumb = 20.0;
  static const _pad = 3.0;

  @override
  Widget build(BuildContext context) {
    final track = value ? _BookFormColors.accent : const Color(0xFF7C8AA0);
    return Semantics(
      toggled: value,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: _width,
            height: _height,
            padding: const EdgeInsets.all(_pad),
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(_height / 2),
            ),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _thumb,
              height: _thumb,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final available = widget.suggestions
        .where((s) => !widget.values.contains(s))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        const SizedBox(height: 6),
        if (widget.values.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in widget.values)
                InputChip(
                  label: Text(v),
                  onDeleted: () => _remove(v),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
          controller: _ctrl,
                decoration: _bookFieldDecoration(
            hintText: l10n.adminChipAddHint,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.addTagTooltip,
              child: SizedBox(
                width: 38,
                height: 38,
                child: OutlinedButton(
                  onPressed: () => _add(_ctrl.text),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(38, 38),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _BookFormColors.label,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _BookFormColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.add, size: 16),
                ),
              ),
            ),
          ],
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

class _DraftPageEditor extends StatefulWidget {
  const _DraftPageEditor({
    super.key,
    required this.isNewPage,
    required this.initialTitle,
    required this.initialBody,
    required this.draftKey,
    this.live = false,
    this.pageLocalId,
    this.onSaved,
    this.onCancel,
    this.onLiveCommit,
    this.onDelete,
  });

  final bool isNewPage;
  final bool live;
  final String? pageLocalId;
  final String initialTitle;
  final String initialBody;
  final String draftKey;
  final ValueChanged<AdminDraftPage>? onSaved;
  final VoidCallback? onCancel;
  /// Called while typing (debounced) and from [commitNow].
  final ValueChanged<AdminDraftPage>? onLiveCommit;
  final VoidCallback? onDelete;

  @override
  State<_DraftPageEditor> createState() => _DraftPageEditorState();
}

class _DraftPageEditorState extends State<_DraftPageEditor> {
  late final TextEditingController _title;
  late final QuillController _bodyQuill;
  late final FormDraftController _draft;
  Timer? _liveCommitTimer;
  bool _suppressLiveCommit = false;

  AdminDraftPage _snapshot() => AdminDraftPage(
    pageNumber: 0,
    title: _title.text.trim(),
    body: jsonEncode(_bodyQuill.document.toDelta().toJson()),
    localId: widget.pageLocalId,
  );

  void commitNow() {
    _liveCommitTimer?.cancel();
    if (!widget.live || widget.onLiveCommit == null) return;
    widget.onLiveCommit!(_snapshot());
  }

  void _scheduleLiveCommit() {
    if (_suppressLiveCommit) return;
    if (!widget.live || widget.onLiveCommit == null) return;
    _liveCommitTimer?.cancel();
    _liveCommitTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || _suppressLiveCommit) return;
      widget.onLiveCommit!(_snapshot());
    });
  }

  void _loadPage(String title, String body) {
    _suppressLiveCommit = true;
    _title.text = title;
    _applyBodyFromStored(body);
    _suppressLiveCommit = false;
  }

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
    void onEdit() {
      if (_suppressLiveCommit) return;
      _draft.onChanged();
      _scheduleLiveCommit();
    }

    _title.addListener(onEdit);
    _bodyQuill.document.changes.listen((_) => onEdit());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restored = await _draft.restoreIfPresent();
      if (!mounted || !restored) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
      _scheduleLiveCommit();
    });
  }

  @override
  void didUpdateWidget(covariant _DraftPageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageLocalId != widget.pageLocalId) {
      _liveCommitTimer?.cancel();
      _loadPage(widget.initialTitle, widget.initialBody);
    }
  }

  @override
  void dispose() {
    _liveCommitTimer?.cancel();
    _title.dispose();
    _bodyQuill.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    await _draft.persistNow();
    if (!mounted) return;
    widget.onCancel?.call();
  }

  Future<void> _save() async {
    final page = _snapshot();
    await _draft.clear();
    if (!mounted) return;
    widget.onSaved?.call(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
        if (!widget.live) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isNewPage
                        ? l10n.addPageTooltip
                        : l10n.editPageTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _BookFormColors.accent,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(l10n.save),
              ),
            ],
          ),
        ),
          const Divider(height: 1, color: _BookFormColors.line),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _title,
                        decoration: _bookFieldDecoration(
                          hintText: l10n.pageTitleFieldLabel,
                        ),
                      ),
                    ),
                    if (widget.onDelete != null) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.deletePageTooltip,
                        child: OutlinedButton(
                          onPressed: widget.onDelete,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                            foregroundColor: const Color(0xFFB42318),
                            side: const BorderSide(
                              color: Color(0xFFFECACA),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.pageContentHeading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    border: Border.all(color: _BookFormColors.line),
                  ),
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
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      border: const Border(
                        left: BorderSide(color: _BookFormColors.line),
                        right: BorderSide(color: _BookFormColors.line),
                        bottom: BorderSide(color: _BookFormColors.line),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(11),
                      ),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final geez = ref.watch(useGeezNumeralsProvider);
                          return QuillEditor.basic(
                            controller: _bodyQuill,
                            config: QuillEditorConfig(
                              placeholder: l10n.pageEditorPlaceholder,
                              expands: true,
                              scrollable: true,
                              padding: const EdgeInsets.all(16),
                              embedBuilders: const [],
                              unknownEmbedBuilder:
                                  const _UnsupportedEmbedBuilder(),
                              customLeadingBlockBuilder: geez
                                  ? _geezOrderedLeadingBuilder
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    child: Text(config.withDot ? '$label.' : label, style: config.style),
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

/// Banner shown atop the editor when a reviewer has sent the book back with a
/// change request. Renders the reviewer's rich-text comment and links to the
/// full review history.
class _ChangesRequestedBanner extends StatelessWidget {
  const _ChangesRequestedBanner({
    required this.note,
    required this.onViewHistory,
  });

  final BookReviewNote note;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rate_review_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.changesRequestedBannerTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewHistory,
                child: Text(l10n.reviewHistoryTitle),
              ),
            ],
          ),
          if (note.comment.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            StoredRichTextView(raw: note.comment),
          ],
        ],
      ),
    );
  }
}

/// Embedded PDF viewer for the admin book editor (pending bytes or server draft).
class _AdminPdfPreviewPane extends ConsumerWidget {
  const _AdminPdfPreviewPane({
    required this.bookId,
    required this.revisionId,
    required this.pendingBytes,
    required this.pendingName,
    required this.hasServerPdf,
    this.onlyPages,
  });

  final String? bookId;
  final String? revisionId;
  final Uint8List? pendingBytes;
  final String? pendingName;
  final bool hasServerPdf;

  /// When non-null, only these 1-based pages are shown (Look Inside live preview).
  final List<int>? onlyPages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filtered = onlyPages;

    if (filtered != null && filtered.isEmpty) {
      return AppStateView(
        icon: Icons.preview_outlined,
        title: l10n.pdfPreviewPagesSection,
        message: l10n.pdfLookInsideLivePreviewEmpty,
      );
    }

    final pending = pendingBytes;
    if (pending != null && pending.isNotEmpty) {
      final pagesKey = filtered?.join(',') ?? '';
      return PdfDocumentReader(
        key: ValueKey(
          'admin-pdf-pending-${pending.length}-$pendingName-$pagesKey',
        ),
        bytes: pending,
        sourceName: pendingName ?? 'pending.pdf',
        preferFitWidth: true,
        onlyPages: filtered,
        loadingLabel: l10n.pdfLoadingLabel,
        errorTitle: l10n.pdfOpenFailed,
      );
    }

    final id = bookId;
    if (id == null || !hasServerPdf) {
      return AppStateView(
        icon: Icons.picture_as_pdf_outlined,
        title: l10n.pdfAdminPreviewHeading,
        message: l10n.pdfAdminPreviewEmpty,
      );
    }

    final asyncSource = ref.watch(pdfViewerSourceProvider(id));
    return asyncSource.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.pdfLoadingLabel),
          ],
        ),
      ),
      error: (e, _) => AppStateView(
        icon: Icons.error_outline,
        title: l10n.pdfOpenFailed,
        message: e is DioException
            ? (messageFromDioResponse(e.response?.data) ?? l10n.pdfOpenFailed)
            : l10n.pdfOpenFailed,
        actionLabel: l10n.retry,
        onAction: () {
          ref.invalidate(pdfBookAccessProvider(id));
          ref.invalidate(pdfViewerSourceProvider(id));
        },
      ),
      data: (PdfViewerSource source) {
        final pagesKey = filtered?.join(',') ?? 'all';
        return PdfDocumentReader(
          key: ValueKey(
            'admin-pdf-$id-${revisionId ?? ''}-$pagesKey-'
            '${source.sourceName ?? source.uri}',
          ),
          bookId: id,
          filePath: source.filePath,
          uri: source.uri,
          bytes: source.bytes,
          fileSize: source.fileSize,
          read: source.read,
          sourceName: source.sourceName,
          headers: source.headers,
          preferRangeAccess: source.preferRangeAccess,
          preferFitWidth: true,
          onlyPages: filtered,
          loadingLabel: l10n.pdfLoadingLabel,
          errorTitle: l10n.pdfOpenFailed,
          onRetry: () {
            ref.invalidate(pdfBookAccessProvider(id));
            ref.invalidate(pdfViewerSourceProvider(id));
          },
        );
      },
    );
  }
}
