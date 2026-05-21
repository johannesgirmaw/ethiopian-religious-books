import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import '../design/reference_assets.dart';
import '../l10n/app_localizations.dart';
import '../widgets/about_section_card.dart';

/// About page — layout aligned with reference `AboutAppPage`.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      appBar: AppBar(
        title: Text(
          l10n.aboutTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.referencePrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Image.asset(
                ReferenceAssets.appLogo,
                width: 100,
                height: 88,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            AboutSectionCard(
              title: l10n.aboutAppSectionTitle,
              content: l10n.aboutAppSectionBody,
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 16),
            AboutSectionCard(
              title: l10n.aboutVersionSectionTitle,
              content: l10n.aboutVersionValue,
              icon: Icons.phone_android_rounded,
            ),
            const SizedBox(height: 16),
            AboutSectionCard(
              title: l10n.aboutDevelopersSectionTitle,
              content: l10n.aboutDevelopersBody,
              icon: Icons.code_rounded,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
