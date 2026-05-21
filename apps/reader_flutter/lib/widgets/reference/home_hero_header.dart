import 'package:flutter/material.dart';

import '../../design/reference_assets.dart';
import 'reference_menu_button.dart';

/// Home hero — matches mobile `HomePage` header stack (bg1, logo, slice).
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
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 250,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 35),
            decoration: const BoxDecoration(
              image: DecorationImage(
                opacity: 0.16,
                image: AssetImage(ReferenceAssets.bgPattern),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 100,
                    child: Image.asset(
                      ReferenceAssets.appLogo,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
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
          Positioned(
            top: -50,
            right: 0,
            child: Container(
              width: 200,
              height: 250,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(ReferenceAssets.headerSlice),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
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
