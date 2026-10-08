import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/web_apk_install_provider.dart';
import '../../../widgets/primitives/shared_widgets.dart';
import 'liquid_glass_nav_bar.dart';

/// Floating install card for Android visitors on Flutter web.
class InstallAppBanner extends ConsumerWidget {
  const InstallAppBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showWebAndroidInstallPrompt) return const SizedBox.shrink();
    final state = ref.watch(webApkInstallProvider);
    if (state.dismissed) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final bottom = LiquidGlassNavBar.bottomInset + 8;
    final busy = state.phase == WebApkInstallPhase.downloading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.pageHorizontal,
        0,
        AppLayout.pageHorizontal,
        bottom,
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: busy
              ? null
              : () => ref.read(webApkInstallProvider.notifier).startDownload(),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.elevated,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: _BannerBody(l10n: l10n, state: state),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerBody extends ConsumerWidget {
  const _BannerBody({required this.l10n, required this.state});

  final AppLocalizations l10n;
  final WebApkInstallState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloading = state.phase == WebApkInstallPhase.downloading;
    final done = state.phase == WebApkInstallPhase.done;
    final failed = state.phase == WebApkInstallPhase.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AppLogoMark(size: 40, light: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.installAppBannerTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? l10n.installAppReady
                        : failed
                        ? l10n.installAppRetryHint
                        : downloading
                        ? l10n.installAppDownloading
                        : l10n.installAppBannerMessage,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (!downloading)
              TextButton(
                onPressed: () =>
                    ref.read(webApkInstallProvider.notifier).startDownload(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDeep,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  failed ? l10n.installAppRetry : l10n.installAppBannerAction,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ),
            IconButton(
              tooltip: l10n.installAppBannerDismiss,
              onPressed: () =>
                  ref.read(webApkInstallProvider.notifier).dismiss(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (downloading || done) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: done ? 1 : state.fraction,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _progressLine(l10n, state),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _progressLine(AppLocalizations l10n, WebApkInstallState state) {
    final received = _formatBytes(state.receivedBytes);
    final total = state.totalBytes > 0 ? _formatBytes(state.totalBytes) : '…';
    final speed = state.bytesPerSecond > 0
        ? '${_formatBytes(state.bytesPerSecond.round())}/s'
        : '—';
    return l10n.installAppProgress(received, total, speed);
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}
