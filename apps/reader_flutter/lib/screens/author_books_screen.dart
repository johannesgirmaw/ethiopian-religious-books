import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../mobile/widgets/catalog/mobile_book_card.dart';
import '../providers/engagement_providers.dart';
import '../router/app_navigation.dart';
import '../widgets/app_state_view.dart';

class AuthorBooksScreen extends ConsumerWidget {
  const AuthorBooksScreen({super.key, required this.author});

  final String author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(booksByAuthorProvider(author));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOverlayRoute(context),
        ),
        title: Text(author),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppStateView(
          title: author,
          message: '$e',
          icon: Icons.person_outline_rounded,
        ),
        data: (books) {
          if (books.isEmpty) {
            return AppStateView(
              title: author,
              message: l10n.noMatchingBooksMessage,
              icon: Icons.menu_book_outlined,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: GridView.builder(
                padding: const EdgeInsets.all(AppLayout.pageHorizontal),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.62,
                ),
                itemCount: books.length,
                itemBuilder: (context, i) =>
                    MobileBookCard(book: books[i], index: i),
              ),
            ),
          );
        },
      ),
    );
  }
}
