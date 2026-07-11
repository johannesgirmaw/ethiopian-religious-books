import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_tokens.dart';

/// Modern, elegant auth building blocks shared by every platform's auth screens
/// (login, register, forgot/reset password, change password). Keeping these in
/// `lib/` honours the "common once" rule — the platform layouts only supply
/// chrome around the form built from these primitives.

/// A labelled, filled text field with a clear focus ring and optional helper /
/// trailing affordance. Plays nicely inside a [Form] via [validator].
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.trailing,
    this.helper,
    this.validator,
    this.onSubmitted,
    this.autovalidateMode,
    this.enabled = true,
    this.required = false,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? trailing;
  final String? helper;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final AutovalidateMode? autovalidateMode;
  final bool enabled;

  /// When true, renders a red asterisk after the label and exposes the field
  /// as required to assistive technology.
  final bool required;

  /// Autofocus this field when its screen first mounts (accessibility: puts the
  /// caret in the primary input so keyboard/screen-reader users start there).
  final bool autofocus;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.referencePrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Semantics(
            label: widget.required ? '${widget.label}, required' : widget.label,
            child: ExcludeSemantics(
              child: RichText(
                text: TextSpan(
                  text: widget.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.1,
                  ),
                  children: widget.required
                      ? const [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.errorText),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: AppMotion.fast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : const [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autocorrect: widget.autocorrect,
            enableSuggestions: !widget.obscureText,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            validator: widget.validator,
            autovalidateMode: widget.autovalidateMode ??
                (widget.validator != null
                    ? AutovalidateMode.onUserInteraction
                    : null),
            onFieldSubmitted: widget.onSubmitted,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: _focused ? Colors.white : AppColors.surfaceInput,
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: widget.icon != null
                  ? Icon(
                      widget.icon,
                      size: 20,
                      color: _focused ? accent : AppColors.textTertiary,
                    )
                  : null,
              suffixIcon: widget.trailing,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.errorBorder,
                  width: 1.4,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.errorBorder,
                  width: 1.6,
                ),
              ),
            ),
          ),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 7),
            child: Text(
              widget.helper!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

/// A password field with a built-in show/hide toggle.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.required = false,
    this.autofocus = false,
    this.showLabel = 'Show password',
    this.hideLabel = 'Hide password',
  });

  final TextEditingController? controller;
  final String label;

  /// Placeholder text. Never render bullet characters here — dots read as an
  /// already-filled password and make the empty field look populated.
  final String? hint;
  final String? helper;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final bool required;
  final bool autofocus;
  final String showLabel;
  final String hideLabel;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      helper: widget.helper,
      icon: Icons.lock_outline_rounded,
      obscureText: !_show,
      autocorrect: false,
      required: widget.required,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onSubmitted: widget.onSubmitted,
      trailing: IconButton(
        splashRadius: 20,
        icon: Icon(
          _show
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
          color: AppColors.textTertiary,
        ),
        onPressed: () => setState(() => _show = !_show),
        tooltip: _show ? widget.hideLabel : widget.showLabel,
      ),
    );
  }
}

/// Full-width, brand-gradient primary call to action with a loading state.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: AppGradients.hero,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 54,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green confirmation banner mirroring [AppErrorBanner]'s shape.
class AuthSuccessBanner extends StatelessWidget {
  const AuthSuccessBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        border: Border.all(color: AppColors.successBorder, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: AppColors.successText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.successText,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
