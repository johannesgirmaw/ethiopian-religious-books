import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/admin_book.dart';
import '../providers/session_notifier.dart';
import '../screens/about_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/admin/admin_book_edit_screen.dart';
import '../screens/admin/admin_books_screen.dart';
import '../screens/admin/admin_purchases_screen.dart';
import '../screens/book_detail_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/author_books_screen.dart';
import '../screens/favourites_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/purchases_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/register_screen.dart';
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
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
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
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionNotifierProvider, (_, __) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refresh,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final asyncSession = ref.read(sessionNotifierProvider);
      if (asyncSession.isLoading && loc.startsWith('/admin')) {
        return null;
      }
      final session = asyncSession.valueOrNull;
      final isAdmin = session?.user?.isSuperuser == true;

      if (loc.startsWith('/admin')) {
        if (session == null) return '/login';
        if (!isAdmin) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
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
            path: '/account',
            redirect: (context, state) => '/profile',
          ),
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
            path: '/admin',
            redirect: (context, state) => '/admin/books',
          ),
        ],
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _fadeSlide(
          key: state.pageKey,
          child: const AboutScreen(),
        ),
      ),
      GoRoute(
        path: '/book/:id',
        parentNavigatorKey: rootNavigatorKey,
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
        pageBuilder: (context, state) => _fadeSlide(
          key: state.pageKey,
          child: const FavouritesScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _fadeSlide(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
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
          final extra =
              state.extra is AdminBook ? state.extra as AdminBook : null;
          return AdminBookEditScreen(bookId: id, initialBook: extra);
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
