import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/book_models.dart';

/// Content categories derived from book titles — the meaningful "genre" axis
/// for Ethiopian religious texts (there is no genre field in the data model,
/// so we classify by well-known title keywords).
enum BookCategory {
  psalms,
  marian,
  liturgy,
  synaxarium,
  saints,
  other,
}

extension BookCategoryLabel on BookCategory {
  String label(AppLocalizations l10n) => switch (this) {
        BookCategory.psalms => l10n.bookCategoryPsalms,
        BookCategory.marian => l10n.bookCategoryMarian,
        BookCategory.liturgy => l10n.bookCategoryLiturgy,
        BookCategory.synaxarium => l10n.bookCategorySynaxarium,
        BookCategory.saints => l10n.bookCategorySaints,
        BookCategory.other => l10n.bookCategoryOther,
      };

  IconData get icon => switch (this) {
        BookCategory.psalms => Icons.music_note_rounded,
        BookCategory.marian => Icons.favorite_rounded,
        BookCategory.liturgy => Icons.local_fire_department_rounded,
        BookCategory.synaxarium => Icons.calendar_month_rounded,
        BookCategory.saints => Icons.self_improvement_rounded,
        BookCategory.other => Icons.menu_book_rounded,
      };
}

/// Maps a server genre slug (see Django `Book.Genre`) to a [BookCategory].
BookCategory? _categoryFromGenre(String? genre) {
  switch (genre) {
    case 'psalms':
      return BookCategory.psalms;
    case 'marian':
      return BookCategory.marian;
    case 'liturgy':
      return BookCategory.liturgy;
    case 'synaxarium':
      return BookCategory.synaxarium;
    case 'saints':
      return BookCategory.saints;
    case 'other':
      return BookCategory.other;
    default:
      return null;
  }
}

/// Classifies a book — prefers the server `genre` field, falling back to
/// deriving from the title/subtitle when the server hasn't set a real genre.
BookCategory categoryForBook(BookSummary book) {
  final fromGenre = _categoryFromGenre(book.genre);
  // Treat a server 'other' as "unclassified" and still try the title, so books
  // the backfill couldn't classify can be refined client-side.
  if (fromGenre != null && fromGenre != BookCategory.other) return fromGenre;
  final t = '${book.title} ${book.subtitle ?? ''}'.toLowerCase();
  if (t.contains('mezmur') || t.contains('psalm') || t.contains('dawit')) {
    return BookCategory.psalms;
  }
  if (t.contains('wudase') ||
      t.contains('weddase') ||
      t.contains('mary') ||
      t.contains('kidane')) {
    return BookCategory.marian;
  }
  if (t.contains('kidase') ||
      t.contains('qeddase') ||
      t.contains('liturgy') ||
      t.contains('anaphora')) {
    return BookCategory.liturgy;
  }
  if (t.contains('senkes') || t.contains('synax') || t.contains('calendar')) {
    return BookCategory.synaxarium;
  }
  if (t.contains('gedle') ||
      t.contains('gedl') ||
      t.contains('saint') ||
      t.contains('hagi')) {
    return BookCategory.saints;
  }
  return BookCategory.other;
}

/// The distinct categories present in [books], ordered by the enum's natural
/// order so chips/tabs stay stable across rebuilds.
List<BookCategory> categoriesPresent(List<BookSummary> books) {
  final present = <BookCategory>{for (final b in books) categoryForBook(b)};
  return BookCategory.values.where(present.contains).toList();
}
