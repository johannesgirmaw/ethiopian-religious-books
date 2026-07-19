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
import '../screens/admin/admin_author_applications_screen.dart';
import '../screens/admin/admin_book_edit_screen.dart';
import '../screens/admin/admin_book_review_screen.dart';
import '../screens/admin/admin_books_screen.dart';
import '../screens/admin/admin_purchases_screen.dart';
import '../screens/author_apply_screen.dart';
import '../screens/book_detail_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/author_books_screen.dart';
import '../screens/favourites_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/purchases_screen.dart';
import '../screens/home_screen.dart';
import '../screens/auth_route_shell.dart';
import '../screens/change_password_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/register_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/splash_screen.dart';

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
              child: const AdminBooksScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/payments',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const AdminPurchasesScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/author-applications',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const AdminAuthorApplicationsScreen(),
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
              return b.isBible ? '/bible/book/$id' : null;
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
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final chapter = state.uri.queryParameters['chapter'];
          final page = int.tryParse(state.uri.queryParameters['page'] ?? '');
          final showChapterPicker =
              state.uri.queryParameters['pickChapter'] == '1';
          return _fadeSlide(
            key: state.pageKey,
            child: ReaderScreen(
              bookId: id,
              initialChapterKey: chapter,
              initialPageNumber: page,
              showChapterPicker: showChapterPicker,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/books/new',
        builder: (context, state) => const AdminBookEditScreen(),
      ),
      GoRoute(
        path: '/admin/books/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra is AdminBook
              ? state.extra as AdminBook
              : null;
          return AdminBookEditScreen(bookId: id, initialBook: extra);
        },
      ),
      GoRoute(
        path: '/admin/books/:id/review',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra is AdminBook
              ? state.extra as AdminBook
              : null;
          return AdminBookReviewScreen(bookId: id, initialBook: extra);
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
