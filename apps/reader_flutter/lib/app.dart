import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/app_tokens.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_locale_provider.dart';
import 'router/app_router.dart';

class EthiopianReaderApp extends ConsumerWidget {
  const EthiopianReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.referencePrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.referencePrimary,
          onPrimary: Colors.white,
          secondary: AppColors.referenceAccent,
          onSecondary: AppColors.textPrimary,
          surface: AppColors.referencePageBg,
          surfaceContainer: AppColors.surfaceCard,
          surfaceContainerHigh: AppColors.surfaceStrong,
          surfaceContainerHighest: AppColors.surfaceStrong,
          outlineVariant: AppColors.border,
          shadow: const Color(0xFF5B3B8C),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.referencePageBg,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceCard,
          indicatorColor: AppColors.referencePrimary.withValues(alpha: 0.35),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(
              color: AppColors.referencePrimary,
              width: 1.6,
            ),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceCard,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.referencePrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.xs)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          space: 1,
          thickness: 1,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 48,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          headlineSmall: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          titleSmall: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          bodyLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.55,
            letterSpacing: 0.1,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
            letterSpacing: 0.1,
          ),
          bodySmall: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.45,
            letterSpacing: 0.2,
          ),
          labelLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          labelMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          labelSmall: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
