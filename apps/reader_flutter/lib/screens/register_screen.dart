import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_api.dart';
import '../providers/session_notifier.dart';
import '../utils/api_error_message.dart';
import '../utils/dio_connection_message.dart';
import '../utils/form_draft_controller.dart';
import '../utils/form_draft_keys.dart';
import '../common/platform/platform_shell.dart';
import '../web/widgets/shell/adaptive_auth_layout.dart';
import '../widgets/primitives/auth_form_kit.dart';
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
  late final FormDraftController _draft;

  @override
  void initState() {
    super.initState();
    _draft = FormDraftController(
      draftKey: FormDraftKeys.register(),
      capture: () => {'email': _email.text, 'name': _name.text},
      restore: (data) {
        _email.text = data['email'] as String? ?? '';
        _name.text = data['name'] as String? ?? '';
      },
      isEmpty: (data) {
        final email = (data['email'] as String? ?? '').trim();
        final name = (data['name'] as String? ?? '').trim();
        return email.isEmpty && name.isEmpty;
      },
    );
    _email.addListener(_draft.onChanged);
    _name.addListener(_draft.onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restored = await _draft.restoreIfPresent();
      if (!mounted || !restored) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
    });
  }

  @override
  void dispose() {
    unawaited(_draft.persistNow());
    _email.removeListener(_draft.onChanged);
    _name.removeListener(_draft.onChanged);
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _draft.dispose();
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
      final data = await ref.read(authApiProvider).register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
          );
      await ref
          .read(sessionNotifierProvider.notifier)
          .persistFromAuthResponse(data);
      await _draft.clear();
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
    final form = Form(
      key: _formKey,
      child: AutofillGroup(
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
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
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
            AuthPasswordField(
              controller: _password,
              label: l10n.passwordFieldLabel,
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
            AuthTextField(
              controller: _name,
              label: l10n.displayNameOptional,
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.name],
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AppErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: l10n.createAccountTitle,
              busy: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
    final footer = Center(
      child: TextButton(
        onPressed: () => context.go('/login'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.referencePrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        child: Text(l10n.alreadyHaveAccount),
      ),
    );

    if (useWideAuthSplit(context)) {
      return AdaptiveAuthFormPane(
        headline: l10n.createAccountTitle,
        subtitle: l10n.registerSubtitle,
        formChild: form,
        footer: footer,
      );
    }
    return AdaptiveAuthLayout(
      headline: l10n.createAccountTitle,
      subtitle: l10n.registerSubtitle,
      formChild: form,
      footer: footer,
    );
  }
}
