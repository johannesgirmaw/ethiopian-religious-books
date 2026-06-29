/// Stable, typed keys for every form draft scope in the app.
class FormDraftKeys {
  FormDraftKeys._();

  /// Prefixes a form key with the signed-in user id when available so drafts
  /// on shared devices never bleed across accounts.
  static String scope({String? userId, required String formKey}) {
    if (userId != null && userId.isNotEmpty) return 'u:$userId:$formKey';
    return formKey;
  }

  static String login() => 'form/login';

  static String register() => 'form/register';

  static String adminBook({String? bookId}) =>
      'form/admin_book/${bookId ?? 'new'}';

  static String adminBookChapter({
    String? bookId,
    String? chapterKey,
    int? chapterIndex,
    bool isNew = false,
  }) {
    if (isNew) {
      return 'form/admin_book/${bookId ?? 'new'}/chapter/new';
    }
    final chapterPart = chapterKey?.trim().isNotEmpty == true
        ? chapterKey!.trim()
        : 'idx_${chapterIndex ?? 0}';
    return 'form/admin_book/${bookId ?? 'new'}/chapter/$chapterPart';
  }

  static String adminBookPage({
    String? bookId,
    required int chapterIndex,
    int? pageIndex,
    bool isNew = false,
  }) {
    final pagePart = isNew ? 'new' : 'idx_${pageIndex ?? 0}';
    return 'form/admin_book/${bookId ?? 'new'}/chapter/$chapterIndex/page/$pagePart';
  }

  static String payment(String bookId) => 'form/payment/$bookId';

  static String bookReview(String bookId) => 'form/book_review/$bookId';

  static String quickNote(String bookId) => 'form/quick_note/$bookId';

  static String adminPaymentReview(String transactionId) =>
      'form/admin_payment_review/$transactionId';
}
