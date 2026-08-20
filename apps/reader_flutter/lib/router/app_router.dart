import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/admin_book.dart';
import '../providers/catalog_providers.dart';
import '../providers/session_notifier.dart';
import '../screens/about_screen.dart';
import '../screens/bible_screen.dart';
import '../screens/bible_reader_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/author_apply_screen.dart';
import '../screens/book_detail_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/author_books_screen.dart';
import '../screens/favourites_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/purchases_screen.dart';
import '../screens/home_screen.dart';
import '../screens/auth_route_shell.dart';
import '../screens/change_password_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell_screen.dart';
import '../screens/register_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/splash_screen.dart';
import 'deferred_screen.dart';

// --- Deferred route targets -------------------------------------------------
// These are the two heaviest branches of the app and neither is on the startup
// path: the reader opens only after a book is picked, and /admin is gated to
// authors and platform admins. `deferred as` makes dart2js emit them as
// separate `main.dart.js_N.part.js` chunks that are fetched on first
// navigation, keeping them out of the initial web download.
//
// IMPORTANT: these libraries must not be imported eagerly anywhere else in the
// app, or dart2js silently folds the chunk back into the main output. Their
// transitive deps (admin_book_actions, admin_book_import, the platform admin
// bodies, the reader widgets) are only reachable through these entry points --
// keep it that way. Verify with:
//   flutter build web --release --dart2js-optimization=O3 && ls build/web/*.part.js
import '../screens/admin/admin_author_applications_screen.dart'
    deferred as admin_author_applications;
import '../screens/admin/admin_book_edit_screen.dart'
    deferred as admin_book_edit;
import '../screens/admin/admin_book_review_screen.dart'
    deferred as admin_book_review;
import '../screens/admin/admin_books_screen.dart' deferred as admin_books;
import '../screens/admin/admin_purchases_screen.dart'
    deferred as admin_purchases;
import '../screens/reader_screen.dart' deferred as reader;

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Smooth fade+slide transition for detail / reader pages.
CustomTransitionPage<T> _fadeSlide<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Keep browser URL in sync with imperative navigation (context.push/pop)
  // so overlay/detail pages get dedicated, reload-safe routes on web.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionNotifierProvider, (_, __) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refresh,
    initialLocation: '/splash',
    errorBuilder: (context, state) => const SplashScreen(),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final asyncSession = ref.read(sessionNotifierProvider);
      final session = asyncSession.valueOrNull;
      final user = session?.user;
      final isAdmin = user?.isPlatformAdmin == true;
      final canManageBooks = user?.canManageBooks == true;
      final isAuthRoute =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/reset-password';
      final isPublicRoute = loc == '/splash' || isAuthRoute;
      final isProtectedRoute = !isPublicRoute;

      if (loc == '/') {
        return session == null ? '/login' : '/home';
      }

      if (asyncSession.isLoading) {
        return null;
      }

      if (session == null && isProtectedRoute) {
        return '/login';
      }

      if (session != null && isAuthRoute) {
        return '/home';
      }

      if (loc.startsWith('/admin')) {
        // Book management is open to authors (their own books); everything
        // else under /admin is platform-admin only.
        if (loc.startsWith('/admin/books')) {
          if (!canManageBooks) return '/home';
        } else if (!isAdmin) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/splash'),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AuthRouteShell(child: child),
        routes: [
          GoRoute(
            path: '/login',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const LoginScreen(),
            ),
          ),
          GoRoute(
            path: '/register',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const RegisterScreen(),
            ),
          ),
          GoRoute(
            path: '/forgot-password',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: ForgotPasswordScreen(
                initialEmail: state.uri.queryParameters['email'],
              ),
            ),
          ),
          GoRoute(
            path: '/reset-password',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: ResetPasswordScreen(
                initialEmail: state.uri.queryParameters['email'],
              ),
            ),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/downloads',
            builder: (context, state) => const DownloadsScreen(),
          ),
          GoRoute(
            path: '/bible',
            builder: (context, state) => const BibleScreen(),
          ),
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchasesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/become-author',
            builder: (context, state) => const AuthorApplyScreen(),
          ),
          GoRoute(path: '/account', redirect: (context, state) => '/profile'),
          GoRoute(
            path: '/admin/books',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: DeferredScreen(
                libraryKey: 'admin_books',
                loader: admin_books.loadLibrary,
                builder: (_) => admin_books.AdminBooksScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/admin/payments',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: DeferredScreen(
                libraryKey: 'admin_purchases',
                loader: admin_purchases.loadLibrary,
                builder: (_) => admin_purchases.AdminPurchasesScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/admin/author-applications',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: DeferredScreen(
                libraryKey: 'admin_author_applications',
                loader: admin_author_applications.loadLibrary,
                builder: (_) =>
                    admin_author_applications.AdminAuthorApplicationsScreen(),
              ),
            ),
          ),
          GoRoute(path: '/admin', redirect: (context, state) => '/admin/books'),
        ],
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const AboutScreen()),
      ),
      GoRoute(
        path: '/change-password',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final session = ref.read(sessionNotifierProvider).valueOrNull;
          return session == null ? '/login' : null;
        },
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const ChangePasswordScreen()),
      ),
      GoRoute(
        path: '/bible/book/:bookId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final chapter =
              int.tryParse(state.uri.queryParameters['chapter'] ?? '') ?? 1;
          final verse = int.tryParse(state.uri.queryParameters['verse'] ?? '');
          return _fadeSlide(
            key: state.pageKey,
            child: BibleReaderScreen(
              bookId: bookId,
              initialChapter: chapter,
              highlightVerse: verse,
            ),
          );
        },
      ),
      GoRoute(
        path: '/book/:id',
        parentNavigatorKey: rootNavigatorKey,
        // Bible books are verse-served: route them straight to the Bible reader
        // instead of the page detail screen. Uses the loaded catalog to decide;
        // BookDetailScreen also redirects as a cold-open fallback.
        redirect: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null) return null;
          final items = ref.read(catalogProvider).valueOrNull?.items;
          if (items == null) return null;
          for (final b in items) {
            if (b.id == id) {
              if (b.isBible) return '/bible/book/$id';
              if (b.isPdf) return null; // detail still useful; reader opens via /pdf
              return null;
            }
          }
          return null;
        },
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _fadeSlide(
            key: state.pageKey,
            child: BookDetailScreen(bookId: id),
          );
        },
      ),
      GoRoute(
        path: '/favourites',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const FavouritesScreen()),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/author/:name',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _fadeSlide(
          key: state.pageKey,
          child: AuthorBooksScreen(
            author: Uri.decodeComponent(state.pathParameters['name']!),
          ),
        ),
      ),
      GoRoute(
        path: '/payment/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _fadeSlide(
            key: state.pageKey,
            child: PaymentScreen(bookId: id),
          );
        },
      ),
      GoRoute(
        path: '/reader/:id',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null) return null;
          final items = ref.read(catalogProvider).valueOrNull?.items;
          if (items == null) return null;
          for (final b in items) {
            if (b.id == id && b.isPdf) return '/pdf/$id';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final chapter = state.uri.queryParameters['chapter'];
          final page = int.tryParse(state.uri.queryParameters['page'] ?? '');
          final showChapterPicker =
              state.uri.queryParameters['pickChapter'] == '1';
          return _fadeSlide(
            key: state.pageKey,
            child: DeferredScreen(
              libraryKey: 'reader',
              loader: reader.loadLibrary,
              builder: (_) => reader.ReaderScreen(
                bookId: id,
                initialChapterKey: chapter,
                initialPageNumber: page,
                showChapterPicker: showChapterPicker,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/pdf/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _fadeSlide(
            key: state.pageKey,
            child: PdfReaderScreen(bookId: id),
          );
        },
      ),
      GoRoute(
        path: '/admin/books/new',
        builder: (context, state) => DeferredScreen(
          libraryKey: 'admin_book_edit',
          loader: admin_book_edit.loadLibrary,
          builder: (_) => admin_book_edit.AdminBookEditScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/books/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra is AdminBook
              ? state.extra as AdminBook
              : null;
          return DeferredScreen(
            libraryKey: 'admin_book_edit',
            loader: admin_book_edit.loadLibrary,
            builder: (_) => admin_book_edit.AdminBookEditScreen(
              bookId: id,
              initialBook: extra,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/books/:id/review',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra is AdminBook
              ? state.extra as AdminBook
              : null;
          return DeferredScreen(
            libraryKey: 'admin_book_review',
            loader: admin_book_review.loadLibrary,
            builder: (_) => admin_book_review.AdminBookReviewScreen(
              bookId: id,
              initialBook: extra,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/books/:id',
        redirect: (context, state) {
          final id = state.pathParameters['id']!;
          return '/admin/books/$id/edit';
        },
      ),
    ],
  );
});
