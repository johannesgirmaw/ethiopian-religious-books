import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../design/app_tokens.dart';
import '../design/reference_assets.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_locale_provider.dart';
import '../providers/session_notifier.dart';
import '../utils/api_error_message.dart';
import '../utils/dio_connection_message.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _showPassword = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
        ),
      );
      final res = await dio.post<Map<String, dynamic>>(
        'auth/login',
        data: {
          'email': _email.text.trim(),
          'password': _password.text,
        },
      );
      await ref
          .read(sessionNotifierProvider.notifier)
          .persistFromAuthResponse(res.data!);
      if (!mounted) return;
      context.go('/home');
    } on DioException catch (e) {
      final hint = connectionTroubleshootHint(e);
      final msg = messageFromDioResponse(e.response?.data) ??
          hint ??
          e.message ??
          l10n.loginFailed;
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero gradient panel — top 46 %
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.46,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppGradients.hero,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -40,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Language toggle (transparent on dark bg)
                          const Align(
                            alignment: Alignment.centerRight,
                            child: _LangToggle(),
                          ),
                          const SizedBox(height: 28),

                          // Gold logo tile
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE8B84B),
                                  Color(0xFFD4A017),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
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
                          const SizedBox(height: 22),

                          // Headline on gradient bg
                          Text(
                            l10n.welcomeBack,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: 0.72,
                            child: Text(
                              l10n.signInSubtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Floating form card
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.xl),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.97),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xl),
                                  boxShadow: AppShadows.modal,
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    PremiumField(
                                      controller: _email,
                                      label: l10n.emailFieldLabel,
                                      hint: l10n.emailFieldHint,
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      autocorrect: false,
                                      validator: (v) {
                                        final s = (v ?? '').trim();
                                        if (s.isEmpty) {
                                          return l10n.emailRequired;
                                        }
                                        if (!s.contains('@') ||
                                            !s.contains('.')) {
                                          return l10n.emailInvalid;
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    PremiumField(
                                      controller: _password,
                                      label: l10n.passwordFieldLabel,
                                      hint: '••••••••••',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: !_showPassword,
                                      onSubmitted: (_) =>
                                          _busy ? null : _submit(),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showPassword
                                              ? Icons
                                                  .visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                          color: AppColors.textTertiary,
                                        ),
                                        onPressed: () => setState(() =>
                                            _showPassword = !_showPassword),
                                      ),
                                      validator: (v) {
                                        if ((v ?? '').isEmpty) {
                                          return l10n.passwordRequired;
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 14),
                                      AuthErrorBanner(message: _error!),
                                    ],
                                    const SizedBox(height: 22),
                                    GradientButton(
                                      label: l10n.signIn,
                                      onPressed: _busy ? null : _submit,
                                      loading: _busy,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Center(
                            child: TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text(
                                l10n.createAccount,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable auth widgets (also used in register_screen) ────────────────────

class PremiumField extends StatelessWidget {
  const PremiumField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autocorrect = true,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autocorrect;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
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
        prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceSoft,
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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.errorBorder),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide:
              const BorderSide(color: AppColors.errorBorder, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: enabled
            ? AppGradients.hero
            : LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.4),
                AppColors.primaryMid.withValues(alpha: 0.35),
              ]),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: enabled ? AppShadows.floatingBtn : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        border: Border.all(color: AppColors.errorBorder, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
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

class _LangToggle extends ConsumerWidget {
  const _LangToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(appLocaleProvider).languageCode;
    return SegmentedButton<String>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        foregroundColor: Colors.white,
        selectedBackgroundColor: Colors.white.withValues(alpha: 0.30),
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      segments: const [
        ButtonSegment(
          value: 'en',
          label: Text('EN',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        ButtonSegment(
          value: 'am',
          label: Text('አማ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
      selected: {code},
      onSelectionChanged: (s) async => ref.setAppLocale(Locale(s.first)),
    );
  }
}
