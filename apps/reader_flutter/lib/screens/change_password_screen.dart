import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_api.dart';
import '../providers/session_notifier.dart';
import '../router/app_navigation.dart';
import '../utils/api_error_message.dart';
import '../utils/dio_connection_message.dart';
import '../common/platform/platform_shell.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';
import '../widgets/primitives/auth_form_kit.dart';
import '../widgets/primitives/shell_primitives.dart';

/// Authenticated password change, reached from the profile screen.
class ChangePasswordScreen extends ConsumerWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const body = _ChangePasswordBody();

    if (useWebShell(context)) {
      return WebOverlayScaffold(
        title: l10n.changePasswordTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        body: body,
      );
    }
    if (useDesktopShell(context)) {
      return DesktopOverlayScaffold(
        title: l10n.changePasswordTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        body: body,
      );
    }
    return AppSubPageScaffold(
      title: l10n.changePasswordTitle,
      body: body,
    );
  }
}

class _ChangePasswordBody extends ConsumerStatefulWidget {
  const _ChangePasswordBody();

  @override
  ConsumerState<_ChangePasswordBody> createState() =>
      _ChangePasswordBodyState();
}

class _ChangePasswordBodyState extends ConsumerState<_ChangePasswordBody> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
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
      final data = await ref.read(authApiProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      // The server rotates every session; persist the fresh pair so this device
      // stays signed in.
      await ref.read(sessionNotifierProvider.notifier).updateTokens(
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordChangedSuccess)),
      );
      popOverlayRoute(context);
    } on DioException catch (e) {
      final hint = connectionTroubleshootHint(e);
      final msg = messageFromDioResponse(e.response?.data) ??
          hint ??
          e.message ??
          l10n.changePasswordFailed;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.changePasswordSubtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              AppPanel(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthPasswordField(
                          controller: _current,
                          label: l10n.currentPasswordFieldLabel,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) {
                            if ((v ?? '').isEmpty) {
                              return l10n.currentPasswordRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
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
                            if (s != _password.text) {
                              return l10n.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          AppErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 22),
                        AuthPrimaryButton(
                          label: l10n.changePasswordCta,
                          busy: _busy,
                          onPressed: _busy ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
