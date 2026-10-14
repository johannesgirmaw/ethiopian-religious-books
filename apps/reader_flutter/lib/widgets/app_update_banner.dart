import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_update_provider.dart';
import '../utils/app_release.dart';
import '../utils/app_update_client.dart';
import '../utils/app_update_exception.dart';

/// Offers a newer mobile or desktop build. Hidden when nothing newer is published.
class AppUpdateBanner extends ConsumerStatefulWidget {
  const AppUpdateBanner({super.key});

  @override
  ConsumerState<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends ConsumerState<AppUpdateBanner> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(appUpdateProvider).valueOrNull;
    if (release == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.primaryDeep,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.appUpdateAvailable(release.version),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => _confirmAndUpdate(release),
              child: Text(
                l10n.appUpdateAction,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndUpdate(AppRelease release) async {
    final l10n = AppLocalizations.of(context);
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.appUpdateTitle),
        content: Text(l10n.appUpdateBody(release.version)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.appUpdateLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.appUpdateAction),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;

    setState(() => _busy = true);
    final progress = ValueNotifier<_UpdateProgress>(const _UpdateProgress());
    var dialogOpen = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return ValueListenableBuilder<_UpdateProgress>(
            valueListenable: progress,
            builder: (context, value, _) {
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        value.installing
                            ? l10n.appUpdateInstalling
                            : l10n.appUpdateDownloading,
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: value.fraction),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      dialogOpen = true;
      final path = await downloadAppUpdate(
        release.url,
        onProgress: (fraction) {
          progress.value = _UpdateProgress(fraction: fraction);
        },
      );
      progress.value = const _UpdateProgress(fraction: 1, installing: true);
      await applyDownloadedUpdate(path);
      _closeDialog(dialogOpen);
      _showMessage(l10n.appUpdateInstalling);
    } on AppUpdateNeedPermission {
      _closeDialog(dialogOpen);
      _showMessage(l10n.appUpdateNeedPermission);
    } on AppUpdateNotWritable {
      _closeDialog(dialogOpen);
      _showMessage(l10n.appUpdateNotWritable);
    } catch (_) {
      _closeDialog(dialogOpen);
      _showMessage(l10n.appUpdateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => progress.dispose());
    }
  }

  void _closeDialog(bool dialogOpen) {
    if (dialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 5), content: Text(message)),
    );
  }
}

class _UpdateProgress {
  const _UpdateProgress({this.fraction, this.installing = false});

  final double? fraction;
  final bool installing;
}
