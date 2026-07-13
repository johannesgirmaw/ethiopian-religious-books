import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/platform/platform_shell.dart';
import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/author_application.dart';
import '../../providers/author_application_api.dart';
import '../../providers/session_notifier.dart';
import '../../utils/api_error_message.dart';
import '../app_state_view.dart';
import '../primitives/auth_form_kit.dart';
import '../primitives/shell_primitives.dart';
import 'author_page_header.dart';

/// The reader-facing "Become an author" form + application status. Shared across
/// mobile / web / desktop; each platform's route adapter wraps it in a scaffold.
class AuthorApplyView extends ConsumerStatefulWidget {
  const AuthorApplyView({super.key, this.showHeader = false});

  /// When true (web/desktop, which have no app bar), a title header is rendered
  /// above the form. Mobile passes false and uses the scaffold's app bar.
  final bool showHeader;

  @override
  ConsumerState<AuthorApplyView> createState() => _AuthorApplyViewState();
}

class _AuthorApplyViewState extends ConsumerState<AuthorApplyView> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _penName = TextEditingController();
  final _title = TextEditingController();
  final _bio = TextEditingController();
  final _phone = TextEditingController();
  final _country = TextEditingController();
  final _credentials = TextEditingController();
  final _sampleLinks = TextEditingController();
  final _paymentEmail = TextEditingController();
  final _telebirr = TextEditingController();

  Uint8List? _photoBytes;
  String? _photoMime;

  bool _seeded = false;
  bool _busy = false;
  bool _refreshedSession = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _penName,
      _title,
      _bio,
      _phone,
      _country,
      _credentials,
      _sampleLinks,
      _paymentEmail,
      _telebirr,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(AuthorApplication? app) {
    if (_seeded) return;
    _seeded = true;
    if (app == null) return;
    _fullName.text = app.fullName;
    _penName.text = app.penName;
    _title.text = app.title;
    _bio.text = app.bio;
    _phone.text = app.phone;
    _country.text = app.country;
    _credentials.text = app.credentials;
    _sampleLinks.text = app.sampleLinks;
    _paymentEmail.text = app.paymentEmail;
    _telebirr.text = app.telebirrNumber;
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickPhoto() async {
    Uint8List? bytes;
    String? name;
    // image_picker has no Windows/Linux implementation; use file_picker there.
    if (isDesktopPlatform) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
      name = result.files.first.name;
    } else {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (x == null) return;
      bytes = await x.readAsBytes();
      name = x.path;
    }
    if (bytes == null || bytes.isEmpty || !mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoMime = _mimeFromName(name!);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(authorApplicationApiProvider);
      final draft = AuthorApplication(
        id: '',
        fullName: _fullName.text,
        penName: _penName.text,
        title: _title.text,
        bio: _bio.text,
        phone: _phone.text,
        country: _country.text,
        photoObjectKey: '',
        photoUrl: '',
        credentials: _credentials.text,
        sampleLinks: _sampleLinks.text,
        paymentEmail: _paymentEmail.text,
        telebirrNumber: _telebirr.text,
        status: 'pending',
        reviewNote: '',
      );
      // Text first so the row exists, then attach the photo (which PATCHes it).
      await api.submit(draft);
      if (_photoBytes != null && _photoBytes!.isNotEmpty) {
        await api.uploadPhoto(_photoBytes!, _photoMime ?? 'image/jpeg');
      }
      ref.invalidate(myAuthorApplicationProvider);
      if (!mounted) return;
      setState(() {
        _photoBytes = null;
        _photoMime = null;
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.authorApplySubmitted)));
    } on DioException catch (e) {
      setState(() => _error =
          messageFromDioResponse(e.response?.data) ??
              e.message ??
              l10n.authorApplyFailed);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _buildContent(l10n);
    if (!widget.showHeader) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthorPageHeader(
          title: l10n.authorApplyTitle,
          subtitle: l10n.authorApplyEntrySubtitle,
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final async = ref.watch(myAuthorApplicationProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppStateView(
        title: l10n.authorApplyFailed,
        message: '$e',
        icon: Icons.error_outline_rounded,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(myAuthorApplicationProvider),
      ),
      data: (my) {
        // Server says the user is now an author (application approved elsewhere):
        // pull the fresh role into the session so the app unlocks author tools.
        final approvedSomewhere = my.isAuthor || (my.application?.isApproved == true);
        if (approvedSomewhere && !_refreshedSession) {
          _refreshedSession = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(sessionNotifierProvider.notifier).refreshUser();
          });
        }
        if (my.isAuthor) {
          return _AlreadyAuthor(l10n: l10n);
        }
        _seed(my.application);
        return _buildForm(l10n, my.application);
      },
    );
  }

  Widget _buildForm(AppLocalizations l10n, AuthorApplication? app) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (app != null) _StatusBanner(app: app, l10n: l10n),
                  Text(
                    l10n.authorApplyIntro,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),

                  // --- Identity ---
                  AppSectionAccent(
                    label: l10n.authorApplySectionIdentity.toUpperCase(),
                  ),
                  const SizedBox(height: AppSpace.md),
                  _PhotoPicker(
                    l10n: l10n,
                    bytes: _photoBytes,
                    existingUrl: app?.photoUrl ?? '',
                    onPick: _busy ? null : _pickPhoto,
                  ),
                  const SizedBox(height: AppSpace.md),
                  AuthTextField(
                    controller: _fullName,
                    label: l10n.authorFieldFullName,
                    hint: l10n.authorFieldFullNameHint,
                    icon: Icons.badge_outlined,
                    required: true,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.authorFullNameRequired
                        : null,
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _penName,
                    label: l10n.authorFieldPenName,
                    hint: l10n.authorFieldPenNameHint,
                    icon: Icons.drive_file_rename_outline,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _title,
                    label: l10n.authorFieldTitle,
                    hint: l10n.authorFieldTitleHint,
                    icon: Icons.workspace_premium_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _bio,
                    label: l10n.authorFieldBio,
                    hint: l10n.authorFieldBioHint,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AuthTextField(
                          controller: _phone,
                          label: l10n.authorFieldPhone,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AuthTextField(
                          controller: _country,
                          label: l10n.authorFieldCountry,
                          icon: Icons.public_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),

                  // --- Supporting evidence ---
                  AppSectionAccent(
                    label: l10n.authorApplySectionEvidence.toUpperCase(),
                  ),
                  const SizedBox(height: AppSpace.md),
                  AuthTextField(
                    controller: _credentials,
                    label: l10n.authorFieldCredentials,
                    hint: l10n.authorFieldCredentialsHint,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _sampleLinks,
                    label: l10n.authorFieldSampleLinks,
                    hint: l10n.authorFieldSampleLinksHint,
                    maxLines: 3,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpace.lg),

                  // --- Payout ---
                  AppSectionAccent(
                    label: l10n.authorApplySectionPayout.toUpperCase(),
                  ),
                  const SizedBox(height: AppSpace.md),
                  AuthTextField(
                    controller: _paymentEmail,
                    label: l10n.authorFieldPaymentEmail,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _telebirr,
                    label: l10n.authorFieldTelebirr,
                    icon: Icons.account_balance_wallet_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    AppErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  AuthPrimaryButton(
                    label: (app != null && app.isRejected)
                        ? l10n.authorApplyResubmit
                        : (app != null
                            ? l10n.authorApplyResubmit
                            : l10n.authorApplySubmit),
                    busy: _busy,
                    icon: Icons.send_rounded,
                    onPressed: _busy ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlreadyAuthor extends StatelessWidget {
  const _AlreadyAuthor({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppPanel(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.successSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_outlined,
                    size: 28,
                    color: AppColors.successText,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.authorApplyStatusApproved,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/admin/books'),
                    icon: const Icon(Icons.menu_book_outlined, size: 20),
                    label: Text(l10n.authorApplyManageBooks),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.referencePrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.app, required this.l10n});

  final AuthorApplication app;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (kind, message) = app.isRejected
        ? (AppStatusKind.neutral, l10n.authorApplyStatusRejected)
        : (AppStatusKind.pending, l10n.authorApplyStatusPending);
    final statusLabel = app.isRejected
        ? l10n.adminAuthorAppStatusRejected
        : l10n.adminAuthorAppStatusPending;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusChip(label: statusLabel, kind: kind),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          if (app.isRejected && app.reviewNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.authorApplyReviewNoteLabel}: ${app.reviewNote}',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.l10n,
    required this.bytes,
    required this.existingUrl,
    required this.onPick,
  });

  final AppLocalizations l10n;
  final Uint8List? bytes;
  final String existingUrl;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (bytes != null) {
      avatar = Image.memory(bytes!, fit: BoxFit.cover, width: 76, height: 76);
    } else if (existingUrl.isNotEmpty) {
      avatar = Image.network(
        existingUrl,
        fit: BoxFit.cover,
        width: 76,
        height: 76,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      avatar = _placeholder();
    }

    final hasPhoto = bytes != null || existingUrl.isNotEmpty;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(width: 76, height: 76, child: avatar),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.authorFieldPhoto,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(
                  hasPhoto ? l10n.authorPhotoChange : l10n.authorPhotoPick,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.referencePrimary,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: AppColors.surfaceInput,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Icon(
            Icons.person_outline_rounded,
            size: 32,
            color: AppColors.textTertiary,
          ),
        ),
      );
}
