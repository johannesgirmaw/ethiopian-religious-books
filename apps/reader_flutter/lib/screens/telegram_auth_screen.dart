import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/auth_api.dart';
import '../providers/session_notifier.dart';
import '../utils/api_error_message.dart';
import '../utils/auth_validators.dart';
import '../utils/dio_connection_message.dart';
import '../utils/open_telegram_bot.dart';
import '../utils/telegram_return_url.dart';
import '../web/widgets/shell/adaptive_auth_layout.dart';
import '../widgets/primitives/auth_form_kit.dart';
import '../widgets/primitives/shared_widgets.dart';
import '../widgets/telegram_icon.dart';

/// Telegram bot flow for login/register or Settings link.
///
/// Flow: open Telegram app → Confirm my phone → app polls / claims (no OTP).
class TelegramAuthScreen extends ConsumerStatefulWidget {
  const TelegramAuthScreen({
    super.key,
    this.purpose = 'login',
    this.linkMode = false,
    this.initialSessionId,
  });

  final String purpose;
  final bool linkMode;

  /// From return deep link `?session=` after Confirm my phone.
  final String? initialSessionId;

  @override
  ConsumerState<TelegramAuthScreen> createState() => _TelegramAuthScreenState();
}

class _TelegramAuthScreenState extends ConsumerState<TelegramAuthScreen> {
  final _completeFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();

  bool _busy = false;
  bool _claiming = false;
  String? _error;
  String? _botLink;
  String? _botUsername;
  String? _sessionId;
  bool _awaitingConfirm = false;
  bool _needsEmail = false;
  Timer? _pollTimer;

  String get _purpose => widget.linkMode ? 'phone_link' : widget.purpose;

  @override
  void initState() {
    super.initState();
    final incoming = widget.initialSessionId?.trim();
    if (incoming != null && incoming.isNotEmpty && !widget.linkMode) {
      _sessionId = incoming;
      _awaitingConfirm = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startPoll();
        unawaited(_tryClaimLogin());
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollStatus());
    });
  }

  Future<void> _pollStatus() async {
    final id = _sessionId;
    if (id == null || !mounted || _claiming) return;
    try {
      final data = await ref.read(authApiProvider).telegramSessionStatus(
            id,
            purpose: _purpose,
          );
      if (!mounted) return;

      if (widget.linkMode) {
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
        return;
      }

      if (data['ready'] == true) {
        if (data['needs_email'] == true) {
          _pollTimer?.cancel();
          setState(() {
            _needsEmail = true;
            _awaitingConfirm = false;
          });
        } else {
          await _tryClaimLogin();
        }
      }
    } catch (_) {
      // Keep polling; transient network errors are fine.
    }
  }

  Future<void> _tryClaimLogin() async {
    final id = _sessionId;
    if (id == null || _claiming || widget.linkMode) return;
    _claiming = true;
    try {
      final data = await ref.read(authApiProvider).telegramClaim(id);
      if (!mounted) return;
      if (data['needs_email'] == true) {
        _pollTimer?.cancel();
        setState(() {
          _needsEmail = true;
          _awaitingConfirm = false;
          _error = null;
        });
        return;
      }
      if (data['access_token'] != null) {
        _pollTimer?.cancel();
        await ref
            .read(sessionNotifierProvider.notifier)
            .persistFromAuthResponse(data);
        if (!mounted) return;
        context.go('/home');
      }
    } on DioException catch (e) {
      // NOT_READY while user is still confirming — keep waiting.
      final code = e.response?.statusCode;
      if (code == 400) return;
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = messageFromDioResponse(e.response?.data) ??
            connectionTroubleshootHint(e) ??
            e.message ??
            l10n.telegramAuthFailed;
      });
    } catch (_) {
      // Ignore; poll will retry.
    } finally {
      _claiming = false;
    }
  }

  Future<void> _openBot() async {
    final username = _botUsername ?? '';
    final link = _botLink;
    final start = link == null
        ? null
        : Uri.tryParse(link)?.queryParameters['start'];
    if (username.isNotEmpty && start != null && start.isNotEmpty) {
      final ok = await openTelegramBot(
        username: username,
        startPayload: start,
        httpsFallback: link,
      );
      if (ok) return;
    }
    if (link != null) {
      await openTelegramBot(
        username: username.isNotEmpty ? username : 'felegemetsahft_bot',
        startPayload: start ?? _sessionId ?? '',
        httpsFallback: link,
      );
    }
  }

  Future<void> _startFlow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ref.read(authApiProvider).telegramInitiate(
            purpose: _purpose,
            returnUrl: telegramAppReturnUrl(),
          );
      _botLink = data['bot_link'] as String?;
      _botUsername = data['bot_username'] as String?;
      _sessionId = data['session_id'] as String?;
      setState(() {
        _awaitingConfirm = true;
        _needsEmail = false;
      });
      await _openBot();
      _startPoll();
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
            sessionId: _sessionId,
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
            child: _buildWaitingOrStart(
              l10n,
              title: l10n.telegramLinkWaitingTitle,
              body: l10n.telegramLinkWaitingBody,
              startLabel: l10n.telegramOpenBotCta,
              subtitle: l10n.telegramLinkShortSubtitle,
            ),
          ),
        ),
      );
    }

    final headline = l10n.telegramContinueTitle;
    final subtitle = _needsEmail
        ? l10n.telegramCompleteSubtitle
        : (_awaitingConfirm
            ? l10n.telegramWaitingSubtitle
            : l10n.telegramContinueSubtitle);

    late final Widget formChild;
    if (_needsEmail) {
      formChild = _buildCompleteForm(l10n);
    } else {
      formChild = _buildWaitingOrStart(
        l10n,
        title: l10n.telegramWaitingTitle,
        body: l10n.telegramWaitingBody,
        startLabel: l10n.telegramOpenBotCta,
        subtitle: l10n.telegramContinueSubtitle,
        showBackToSignIn: true,
      );
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

  Widget _buildWaitingOrStart(
    AppLocalizations l10n, {
    required String title,
    required String body,
    required String startLabel,
    required String subtitle,
    bool showBackToSignIn = false,
  }) {
    if (_awaitingConfirm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Center(child: TelegramIcon(size: 48)),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
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
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: startLabel,
          busy: _busy,
          onPressed: _busy ? null : _startFlow,
          icon: Icons.send_rounded,
        ),
        if (showBackToSignIn) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(l10n.backToSignIn),
          ),
        ],
      ],
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
