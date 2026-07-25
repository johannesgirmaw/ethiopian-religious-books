import 'package:flutter/material.dart';
import '../../router/app_navigation.dart';
import '../../design/app_decorations.dart';
import '../../design/app_tokens.dart';
import '../../design/app_typography.dart';
import '../../l10n/app_localizations.dart';

String greetingForL10n(AppLocalizations l10n) {
  final hour = DateTime.now().hour;
  if (hour < 5) return l10n.goodEvening;
  if (hour < 12) return l10n.goodMorning;
  if (hour < 18) return l10n.goodAfternoon;
  return l10n.goodEvening;
}

// ─── Section accent bar (replaces gold gradient bars) ────────────────────────

class AppSectionAccent extends StatelessWidget {
  const AppSectionAccent({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.referenceAccent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.sectionTitle.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}

// ─── Detail row (v2 DetailRow) ───────────────────────────────────────────────

class AppDetailRow extends StatelessWidget {
  const AppDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.referencePrimary,
    this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error banner ────────────────────────────────────────────────────────────

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        border: Border.all(color: AppColors.errorBorder, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.errorText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.errorText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Amharic wordmark logo ───────────────────────────────────────────────────

(String, String) _brandLines(String name) {
  final parts = name.split(RegExp(r'\s+'));
  final line1 = parts.isNotEmpty ? parts.first : name;
  final line2 = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  return (line1, line2);
}

/// Gold gradient fill for elegant wordmark glyphs.
class _GoldText extends StatelessWidget {
  const _GoldText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF7D48A),
          Color(0xFFF5A623),
          Color(0xFFE08E00),
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Thin gold accent rule used between brand lines.
class _BrandHairline extends StatelessWidget {
  const _BrandHairline({
    required this.width,
    this.color,
  });

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 1,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: color == null
            ? const LinearGradient(
                colors: [
                  Color(0x00F5A623),
                  Color(0xFFF5A623),
                  Color(0x00F5A623),
                ],
              )
            : null,
        color: color,
      ),
    );
  }
}

/// Framed mark: deep ink tile with gold Amharic lockup (splash / auth / about).
class AppLogoTile extends StatelessWidget {
  const AppLogoTile({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) {
    final name = AppLocalizations.of(context).brandName;
    final (line1, line2) = _brandLines(name);
    final primarySize = size * (line2.isEmpty ? 0.26 : 0.22);
    final captionSize = size * 0.13;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A3A4A),
            Color(0xFF041820),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(
          color: const Color(0xFFF5A623).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5A623).withValues(alpha: 0.18),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.08,
        vertical: size * 0.12,
      ),
      child: _GoldText(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              line1,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.brandWordmark(
                fontSize: primarySize,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            if (line2.isNotEmpty) ...[
              SizedBox(height: size * 0.06),
              _BrandHairline(width: size * 0.28, color: Colors.white),
              SizedBox(height: size * 0.06),
              Text(
                line2,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.brandWordmarkCaption(
                  fontSize: captionSize,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline / stacked Amharic wordmark for nav, sidebars, and hero lockups.
class AppBrandWordmark extends StatelessWidget {
  const AppBrandWordmark({
    super.key,
    this.fontSize = 16,
    this.color = AppColors.textPrimary,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.stacked = false,
    this.gold = false,
  });

  final double fontSize;
  final Color color;
  final int maxLines;
  final TextAlign textAlign;

  /// Two-line lockup with a gold hairline between words.
  final bool stacked;

  /// Soft gold gradient fill (best on dark surfaces).
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final name = AppLocalizations.of(context).brandName;
    final (line1, line2) = _brandLines(name);

    if (!stacked || line2.isEmpty) {
      final text = Text(
        name,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.brandWordmark(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
        ),
      );
      return gold ? _GoldText(child: text) : text;
    }

    final cross = switch (textAlign) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };

    final column = Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line1,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.brandWordmark(
            fontSize: fontSize,
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
          ),
        ),
        SizedBox(height: fontSize * 0.28),
        _BrandHairline(
          width: fontSize * 1.35,
          color: gold ? Colors.white70 : color.withValues(alpha: 0.35),
        ),
        SizedBox(height: fontSize * 0.28),
        Text(
          line2,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.brandWordmarkCaption(
            fontSize: fontSize * 0.58,
            color: gold ? color : color.withValues(alpha: 0.78),
          ),
        ),
      ],
    );

    return gold ? _GoldText(child: column) : column;
  }
}

// ─── iOS-style text field ────────────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autocorrect = true,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppColors.textTertiary)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ─── Sub-page scaffold (about, pushed routes) ────────────────────────────────

class AppSubPageScaffold extends StatelessWidget {
  const AppSubPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOverlayRoute(context),
        ),
        title: Text(title),
        actions: actions,
        backgroundColor: AppColors.referencePageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.line),
        ),
      ),
      body: body,
    );
  }
}

// ─── List row (v2 ListItem) ──────────────────────────────────────────────────

class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.leading,
    this.trailing,
    this.chip,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? subtitleIcon;
  final Widget? leading;
  final Widget? trailing;
  final Widget? chip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: AppDecorations.listRow(),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chip != null) ...[
                          const SizedBox(width: 6),
                          chip!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (subtitleIcon != null) ...[
                            Icon(
                              subtitleIcon,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
