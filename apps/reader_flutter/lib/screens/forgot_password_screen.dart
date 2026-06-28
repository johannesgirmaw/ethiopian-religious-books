import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

/// Step 1 of password reset: collect the email and request a 6-digit code.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
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
    final email = _email.text.trim();
    try {
      await ref.read(authApiProvider).forgotPassword(email: email);
      if (!mounted) return;
      // Server is intentionally silent about whether the account exists; move on
      // to code entry regardless.
      context.go('/reset-password?email=${Uri.encodeComponent(email)}');
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
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _email,
            label: l10n.emailFieldLabel,
            hint: l10n.emailFieldHint,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _busy ? null : _submit(),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return l10n.emailRequired;
              if (!s.contains('@') || !s.contains('.')) {
                return l10n.emailInvalid;
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: l10n.sendResetCode,
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
        headline: l10n.forgotPasswordTitle,
        subtitle: l10n.forgotPasswordSubtitle,
        formChild: form,
        footer: footer,
      );
    }
    return AdaptiveAuthLayout(
      headline: l10n.forgotPasswordTitle,
      subtitle: l10n.forgotPasswordSubtitle,
      formChild: form,
      footer: footer,
    );
  }
}
