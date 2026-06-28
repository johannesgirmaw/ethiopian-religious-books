import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_api.dart';
import '../utils/api_error_message.dart';
import '../utils/dio_connection_message.dart';
import '../common/platform/platform_shell.dart';
import '../web/widgets/shell/adaptive_auth_layout.dart';
import '../widgets/primitives/auth_form_kit.dart';
import '../widgets/primitives/shared_widgets.dart';

/// Step 2 of password reset: enter the emailed 6-digit code + a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const int _resendCooldown = 60;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  Timer? _timer;
  int _secondsLeft = _resendCooldown;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _email.text.trim();
    if (email.isEmpty) return;
    try {
      await ref.read(authApiProvider).forgotPassword(email: email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resetCodeResent)),
      );
    } catch (_) {
      // Resend failures are non-fatal; the user can try again.
    }
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
      await ref.read(authApiProvider).resetPassword(
            email: _email.text.trim(),
            code: _code.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordResetSuccess)),
      );
      context.go('/login');
    } on DioException catch (e) {
      final hint = connectionTroubleshootHint(e);
      final msg = messageFromDioResponse(e.response?.data) ??
          hint ??
          e.message ??
          l10n.resetPasswordFailed;
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
    final email = widget.initialEmail?.trim() ?? '';
    final subtitle = email.isNotEmpty
        ? l10n.resetPasswordSubtitle(email)
        : l10n.forgotPasswordSubtitle;

    final canResend = _secondsLeft == 0;
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (email.isEmpty) ...[
            AuthTextField(
              controller: _email,
              label: l10n.emailFieldLabel,
              hint: l10n.emailFieldHint,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return l10n.emailRequired;
                if (!s.contains('@') || !s.contains('.')) {
                  return l10n.emailInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          AuthTextField(
            controller: _code,
            label: l10n.resetCodeFieldLabel,
            hint: '••••••',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return l10n.resetCodeRequired;
              if (s.length != 6) return l10n.resetCodeInvalid;
              return null;
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: canResend ? _resend : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.referencePrimary,
              ),
              child: Text(
                canResend ? l10n.resendCode : l10n.resendCodeIn(_secondsLeft),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AuthPasswordField(
            controller: _password,
            label: l10n.newPasswordFieldLabel,
            helper: l10n.passwordMinRegisterHelper,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) {
              final s = v ?? '';
              if (s.isEmpty) return l10n.passwordRequired;
              if (s.length < 10) return l10n.passwordTooShort;
              return null;
            },
          ),
          const SizedBox(height: 16),
          AuthPasswordField(
            controller: _confirm,
            label: l10n.confirmPasswordFieldLabel,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
            validator: (v) {
              final s = v ?? '';
              if (s.isEmpty) return l10n.confirmPasswordRequired;
              if (s != _password.text) return l10n.passwordsDoNotMatch;
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: l10n.resetPasswordCta,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
    final footer = Center(
      child: TextButton.icon(
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text(l10n.backToSignIn),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.referencePrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

    if (useWideAuthSplit(context)) {
      return AdaptiveAuthFormPane(
        headline: l10n.resetPasswordTitle,
        subtitle: subtitle,
        formChild: form,
        footer: footer,
      );
    }
    return AdaptiveAuthLayout(
      headline: l10n.resetPasswordTitle,
      subtitle: subtitle,
      formChild: form,
      footer: footer,
    );
  }
}
