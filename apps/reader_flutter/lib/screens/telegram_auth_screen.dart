import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/platform/platform_shell.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/auth_api.dart';
import '../providers/session_notifier.dart';
import '../utils/api_error_message.dart';
import '../utils/auth_validators.dart';
import '../utils/dio_connection_message.dart';
import '../web/widgets/shell/adaptive_auth_layout.dart';
import '../widgets/primitives/auth_form_kit.dart';
import '../widgets/primitives/shared_widgets.dart';
import '../widgets/telegram_icon.dart';

/// Telegram bot flow for login/register (`purpose=login`) or short link
/// (`linkMode` — open Telegram, confirm phone once, no OTP).
class TelegramAuthScreen extends ConsumerStatefulWidget {
  const TelegramAuthScreen({
    super.key,
    this.purpose = 'login',
    this.linkMode = false,
  });

  final String purpose;
  final bool linkMode;

  @override
  ConsumerState<TelegramAuthScreen> createState() => _TelegramAuthScreenState();
}

class _TelegramAuthScreenState extends ConsumerState<TelegramAuthScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _completeFormKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _botLink;
  String? _botUsername;
  String? _sessionId;
  String? _normalizedPhone;
  String? _pendingCode;
  bool _awaitingOtp = false;
  bool _awaitingLink = false;
  bool _needsEmail = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  Timer? _pollTimer;

  String get _purpose => widget.linkMode ? 'phone_link' : widget.purpose;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _pollTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _startLinkPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollLinkStatus());
    });
  }

  Future<void> _pollLinkStatus() async {
    final id = _sessionId;
    if (id == null || !mounted) return;
    try {
      final data = await ref.read(authApiProvider).telegramSessionStatus(id);
      if (data['linked'] == true) {
        _pollTimer?.cancel();
        final userMap = data['user'] as Map<String, dynamic>?;
        if (userMap != null) {
          await ref
              .read(sessionNotifierProvider.notifier)
              .updateUser(UserProfile.fromJson(userMap));
        }
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.telegramLinkedSuccess)),
        );
        context.pop();
      }
    } catch (_) {
      // Keep polling; transient network errors are fine.
    }
  }

  Future<void> _openBot() async {
    final link = _botLink;
    if (link == null) return;
    final username = _botUsername ?? '';
    final start = Uri.tryParse(link)?.queryParameters['start'];
    if (username.isNotEmpty && start != null) {
      final tg = Uri.parse('tg://resolve?domain=$username&start=$start');
      try {
        if (await canLaunchUrl(tg)) {
          await launchUrl(tg, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  Future<void> _startLink() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ref.read(authApiProvider).telegramInitiate(
            purpose: 'phone_link',
          );
      _botLink = data['bot_link'] as String?;
      _botUsername = data['bot_username'] as String?;
      _sessionId = data['session_id'] as String?;
      setState(() => _awaitingLink = true);
      await _openBot();
      _startLinkPoll();
    } on DioException catch (e) {
      final hint = connectionTroubleshootHint(e);
      setState(() {
        _error = messageFromDioResponse(e.response?.data) ??
            hint ??
            e.message ??
            l10n.telegramAuthFailed;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _initiate({bool resend = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (!resend) {
      final form = _phoneFormKey.currentState;
      if (form == null || !form.validate()) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ref.read(authApiProvider).telegramInitiate(
            phone: _phone.text.trim(),
            purpose: _purpose,
          );
      _botLink = data['bot_link'] as String?;
      _botUsername = data['bot_username'] as String?;
      _sessionId = data['session_id'] as String?;
      _normalizedPhone = _phone.text.trim();
      setState(() {
        _awaitingOtp = true;
        _needsEmail = false;
      });
      _startResendCooldown();
      await _openBot();
    } on DioException catch (e) {
      final hint = connectionTroubleshootHint(e);
      setState(() {
        _error = messageFromDioResponse(e.response?.data) ??
            hint ??
            e.message ??
            l10n.telegramAuthFailed;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    final form = _otpFormKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final phone = _normalizedPhone ?? _phone.text.trim();
      final code = _code.text.trim();
      final data = await ref.read(authApiProvider).telegramVerify(
            phone: phone,
            code: code,
            purpose: _purpose,
          );

      if (data['needs_email'] == true) {
        _pendingCode = code;
        setState(() {
          _needsEmail = true;
          _awaitingOtp = false;
        });
        return;
      }

      await ref
          .read(sessionNotifierProvider.notifier)
          .persistFromAuthResponse(data);
      if (!mounted) return;
      context.go('/home');
    } on DioException catch (e) {
      final hint = connectionTroubleshootHint(e);
      setState(() {
        _error = messageFromDioResponse(e.response?.data) ??
            hint ??
            e.message ??
            l10n.telegramAuthFailed;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context)!;
    final form = _completeFormKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ref.read(authApiProvider).telegramComplete(
            phone: _normalizedPhone ?? _phone.text.trim(),
            code: _pendingCode ?? _code.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            displayName: _displayName.text.trim(),
          );
      await ref
          .read(sessionNotifierProvider.notifier)
          .persistFromAuthResponse(data);
      if (!mounted) return;
      context.go('/home');
    } on DioException catch (e) {
      final hint = connectionTroubleshootHint(e);
      setState(() {
        _error = messageFromDioResponse(e.response?.data) ??
            hint ??
            e.message ??
            l10n.telegramAuthFailed;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.linkMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.telegramLinkTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _pollTimer?.cancel();
              context.pop();
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildLinkBody(l10n),
          ),
        ),
      );
    }

    final headline = l10n.telegramContinueTitle;
    final subtitle = _needsEmail
        ? l10n.telegramCompleteSubtitle
        : (_awaitingOtp
            ? l10n.telegramOtpSubtitle
            : l10n.telegramContinueSubtitle);

    late final Widget formChild;
    if (_needsEmail) {
      formChild = _buildCompleteForm(l10n);
    } else if (_awaitingOtp) {
      formChild = _buildOtpForm(l10n);
    } else {
      formChild = _buildPhoneForm(l10n);
    }

    if (useWideAuthSplit(context)) {
      return AdaptiveAuthFormPane(
        headline: headline,
        subtitle: subtitle,
        formChild: formChild,
      );
    }
    return AdaptiveAuthLayout(
      headline: headline,
      subtitle: subtitle,
      formChild: formChild,
    );
  }

  Widget _buildLinkBody(AppLocalizations l10n) {
    if (_awaitingLink) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Center(child: TelegramIcon(size: 48)),
          const SizedBox(height: 20),
          Text(
            l10n.telegramLinkWaitingTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.telegramLinkWaitingBody,
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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.telegramLinkShortSubtitle,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: l10n.telegramOpenBotCta,
          busy: _busy,
          onPressed: _busy ? null : _startLink,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _buildPhoneForm(AppLocalizations l10n) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _phone,
            label: l10n.phoneFieldLabel,
            hint: l10n.phoneFieldHint,
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            required: true,
            autofocus: true,
            validator: (v) => validatePhone(v, l10n),
            onSubmitted: (_) => _busy ? null : _initiate(),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.telegramPhoneHelper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppErrorBanner(message: _error!),
          ],
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: l10n.telegramOpenBotCta,
            busy: _busy,
            onPressed: _busy ? null : () => _initiate(),
            icon: Icons.send_rounded,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(l10n.backToSignIn),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm(AppLocalizations l10n) {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.telegramOtpInstructions,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _openBot,
            icon: const TelegramIcon(size: 18),
            label: Text(l10n.telegramReopenBot),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _code,
            label: l10n.resetCodeFieldLabel,
            hint: '123456',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            required: true,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return l10n.resetCodeRequired;
              if (!RegExp(r'^\d{6}$').hasMatch(s)) return l10n.resetCodeInvalid;
              return null;
            },
            onSubmitted: (_) => _busy ? null : _verify(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppErrorBanner(message: _error!),
          ],
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: l10n.telegramVerifyCta,
            busy: _busy,
            onPressed: _busy ? null : _verify,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_busy || _resendSeconds > 0)
                ? null
                : () => _initiate(resend: true),
            child: Text(
              _resendSeconds > 0
                  ? l10n.resendCodeIn(_resendSeconds)
                  : l10n.resendCode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteForm(AppLocalizations l10n) {
    return Form(
      key: _completeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _email,
            label: l10n.emailFieldLabel,
            hint: l10n.emailFieldHint,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            required: true,
            autofocus: true,
            validator: (v) => validateEmail(v, l10n),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _displayName,
            label: l10n.displayNameOptional,
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthPasswordField(
            controller: _password,
            label: l10n.passwordFieldLabel,
            hint: l10n.telegramPasswordOptionalHint,
            showLabel: l10n.showPassword,
            hideLabel: l10n.hidePassword,
            textInputAction: TextInputAction.done,
            validator: (v) {
              final s = v ?? '';
              if (s.isEmpty) return null;
              if (s.length < 10) return l10n.passwordTooShort;
              return null;
            },
            onSubmitted: (_) => _busy ? null : _complete(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppErrorBanner(message: _error!),
          ],
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: l10n.telegramCompleteCta,
            busy: _busy,
            onPressed: _busy ? null : _complete,
          ),
        ],
      ),
    );
  }
}
