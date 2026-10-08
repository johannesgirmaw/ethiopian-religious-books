import 'package:ethiopian_reader/models/book_models.dart';
import 'package:ethiopian_reader/providers/catalog_providers.dart';
import 'package:ethiopian_reader/widgets/home/home_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lookup = [
    GenreOption(slug: 'bible', label: 'Bible'),
    GenreOption(slug: 'psalms', label: 'Psalms & Mezmur'),
    GenreOption(slug: 'other', label: 'General'),
  ];

  BookSummary book(String id, String? genre) =>
      BookSummary(id: id, title: id, genre: genre);

  test('omits genres that have no books and keeps lookup order', () {
    final options = genreOptionsFor(
      [book('a', 'other'), book('b', 'bible'), book('c', 'other')],
      lookup,
    );

    expect(options.map((g) => g.slug).toList(), ['bible', 'other']);
    expect(options.map((g) => g.label).toList(), ['Bible', 'General']);
  });

  test('appends a book slug that is missing from the lookup', () {
    final options = genreOptionsFor(
      [book('a', 'other'), book('b', 'legacy-hymns')],
      lookup,
    );

    expect(options.map((g) => g.slug).toList(), ['other', 'legacy-hymns']);
    expect(options.last.label, 'legacy-hymns');
  });

  test('ignores blank genres', () {
    final options = genreOptionsFor(
      [book('a', null), book('b', '   '), book('c', 'psalms')],
      lookup,
    );

    expect(options.map((g) => g.slug).toList(), ['psalms']);
  });
}