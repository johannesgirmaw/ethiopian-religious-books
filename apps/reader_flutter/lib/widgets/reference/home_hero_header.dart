import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/reference_assets.dart';
import 'reference_menu_button.dart';

/// Immersive gradient hero header — Lalibela Digital style.
class HomeHeroHeader extends StatelessWidget {
  const HomeHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showMenu = true,
  });

  final String title;
  final String? subtitle;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Full-bleed gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.hero,
            ),
          ),

          // Decorative circle — top-right
          Positioned(
            top: -40,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Decorative circle — bottom-left
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content — logo + title + subtitle
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo row
                  SizedBox(
                    height: 56,
                    child: Image.asset(
                      ReferenceAssets.appLogo,
                      fit: BoxFit.contain,
                      color: Colors.white,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: 0.72,
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.2,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Gold accent line at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.accent,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Menu button
          if (showMenu)
            Positioned(
              top: ReferenceMenuLayout.top(context),
              left: ReferenceMenuLayout.left,
              child: const ReferenceMenuButton(),
            ),
        ],
      ),
    );
  }
}
