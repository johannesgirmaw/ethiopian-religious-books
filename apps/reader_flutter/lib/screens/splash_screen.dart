import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/reference_assets.dart';
import '../l10n/app_localizations.dart';
import '../providers/session_notifier.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    await ref.read(sessionNotifierProvider.future);
    if (!mounted) return;
    final session = ref.read(sessionNotifierProvider).valueOrNull;
    if (session != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF070412),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Deep radial gradient background
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.splashRadial,
            ),
          ),

          // Decorative concentric rings
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outermost ring
                  Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.07),
                        width: 1,
                      ),
                    ),
                  ),
                  // Middle ring
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.13),
                        width: 1,
                      ),
                    ),
                  ),
                  // Inner ambient glow
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.55),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Gold-framed logo tile
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE8B84B), Color(0xFFD4A017)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: AppShadows.goldGlow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          ReferenceAssets.appLogo,
                          fit: BoxFit.contain,
                          color: const Color(0xFF1A0E2E),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom anchored text + progress
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  children: [
                    Text(
                      l10n.appTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.splashTagline,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: LinearProgressIndicator(
                        value: null,
                        minHeight: 2,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 44),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
