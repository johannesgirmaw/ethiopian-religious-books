import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../providers/session_notifier.dart';
import '../utils/api_error_message.dart';
import '../utils/dio_connection_message.dart';
import '../widgets/primitives/auth_screen_layout.dart';
import '../widgets/primitives/shared_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
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
        'auth/register',
        data: {
          'email': _email.text.trim(),
          'password': _password.text,
          'display_name':
              _name.text.trim().isEmpty ? null : _name.text.trim(),
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
          l10n.registrationFailed;
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

    return AuthScreenLayout(
      headline: l10n.createAccountTitle,
      subtitle: l10n.registerSubtitle,
      formChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
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
            const SizedBox(height: 14),
            AppTextField(
              controller: _password,
              label: l10n.passwordFieldLabel,
              hint: '••••••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: !_showPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
              ),
              validator: (v) {
                final s = v ?? '';
                if (s.isEmpty) return l10n.passwordRequired;
                if (s.length < 10) return l10n.passwordTooShort;
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _name,
              label: l10n.displayNameOptional,
              icon: Icons.person_outline_rounded,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AppErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.createAccountTitle),
            ),
          ],
        ),
      ),
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: Text(l10n.alreadyHaveAccount),
      ),
    );
  }
}
