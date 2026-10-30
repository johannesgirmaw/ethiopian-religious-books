import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_api.dart';
import '../utils/api_error_message.dart';
import '../utils/auth_validators.dart';
import '../utils/dio_connection_message.dart';
import '../utils/open_telegram_bot.dart';
import '../utils/telegram_return_url.dart';
import '../common/platform/platform_shell.dart';
import '../web/widgets/shell/adaptive_auth_layout.dart';
import '../widgets/primitives/auth_form_kit.dart';
import '../widgets/primitives/shared_widgets.dart';
import '../widgets/telegram_icon.dart';

/// Step 1 of password reset: email → Telegram delivers the 6-digit code.
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
  bool _awaitingTelegram = false;
  String? _error;
  String? _botLink;
  String? _botUsername;
  String? _sessionId;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _goReset() {
    final email = _email.text.trim();
    context.go('/reset-password?email=${Uri.encodeComponent(email)}');
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollStatus());
    });
  }

  Future<void> _pollStatus() async {
    final id = _sessionId;
    if (id == null || !mounted) return;
    try {
      final data = await ref.read(authApiProvider).telegramSessionStatus(
            id,
            purpose: 'password_reset',
          );
      if (data['code_sent'] == true) {
        _pollTimer?.cancel();
        if (!mounted) return;
        _goReset();
      }
    } catch (_) {}
  }

  Future<void> _openBot() async {
    final username = _botUsername ?? '';
    final link = _botLink;
    final start =
        link == null ? null : Uri.tryParse(link)?.queryParameters['start'];
    if (username.isNotEmpty && start != null && start.isNotEmpty) {
      await openTelegramBot(
        username: username,
        startPayload: start,
        httpsFallback: link,
      );
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
    final email = _email.text.trim();
    try {
      final data = await ref.read(authApiProvider).forgotPassword(
            email: email,
            returnUrl: telegramAppReturnUrl(),
          );
      if (!mounted) return;

      if (data['needs_telegram'] == true) {
        _botLink = data['bot_link'] as String?;
        _botUsername = data['bot_username'] as String?;
        _sessionId = data['session_id'] as String?;
        setState(() => _awaitingTelegram = true);
        await _openBot();
        _startPoll();
        return;
      }

      // Code already DMed on Telegram (account already linked).
      _goReset();
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

    late final Widget form;
    if (_awaitingTelegram) {
      form = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: TelegramIcon(size: 48)),
          const SizedBox(height: 20),
          Text(
            l10n.forgotPasswordWaitingTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.forgotPasswordWaitingBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _busy ? null : _openBot,
            icon: const TelegramIcon(size: 18),
            label: Text(l10n.telegramReopenBot),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppErrorBanner(message: _error!),
          ],
        ],
      );
    } else {
      form = Form(
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
              validator: (v) => validateEmail(v, l10n),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AppErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: l10n.sendResetCodeTelegram,
              busy: _busy,
              onPressed: _busy ? null : _submit,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      );
    }

    final footer = Center(
      child: TextButton.icon(
        onPressed: () {
          _pollTimer?.cancel();
          context.go('/login');
        },
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text(l10n.backToSignIn),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.referencePrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

    final subtitle = _awaitingTelegram
        ? l10n.forgotPasswordWaitingSubtitle
        : l10n.forgotPasswordSubtitle;

    if (useWideAuthSplit(context)) {
      return AdaptiveAuthFormPane(
        headline: l10n.forgotPasswordTitle,
        subtitle: subtitle,
        formChild: form,
        footer: footer,
      );
    }
    return AdaptiveAuthLayout(
      headline: l10n.forgotPasswordTitle,
      subtitle: subtitle,
      formChild: form,
      footer: footer,
    );
  }
}
