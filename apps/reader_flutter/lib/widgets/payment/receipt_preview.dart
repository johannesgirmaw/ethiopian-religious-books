import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';
import '../../providers/payment_providers.dart';

/// Shows a transaction's uploaded receipt. Fetches the bytes through the
/// authenticated API client (the receipt endpoint is private) and renders an
/// image; non-image receipts (PDF) and missing files fall back to a labelled
/// placeholder. Shared by the buyer's purchase detail and the admin review.
class ReceiptPreview extends ConsumerWidget {
  const ReceiptPreview({super.key, required this.transaction, this.height = 240});

  final PaymentTransaction transaction;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (transaction.receiptUrl.isEmpty) {
      return _placeholder(
          l10n.adminNoReceipt, Icons.image_not_supported_outlined);
    }
    final bytesAsync = ref.watch(receiptBytesProvider(transaction.id));
    return bytesAsync.when(
      loading: () => SizedBox(
        height: height * 0.5,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => InkWell(
        onTap: () => ref.invalidate(receiptBytesProvider(transaction.id)),
        child: _placeholder(l10n.retry, Icons.refresh_rounded),
      ),
      data: (bytes) {
        if (bytes == null) {
          return _placeholder(
              l10n.adminNoReceipt, Icons.image_not_supported_outlined);
        }
        return GestureDetector(
          onTap: () => _openFullScreen(context, bytes),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Stack(
              children: [
                Image.memory(
                  bytes,
                  height: height,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _placeholder(
                      l10n.adminViewReceipt, Icons.description_outlined),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFullScreen(BuildContext context, Uint8List bytes) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ReceiptFullScreen(bytes: bytes),
      ),
    );
  }

  Widget _placeholder(String label, IconData icon) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textTertiary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Full-screen, zoomable/pannable view of a receipt image. Non-image files
/// (e.g. PDF) show a labelled fallback since they can't render as an image.
class _ReceiptFullScreen extends StatelessWidget {
  const _ReceiptFullScreen({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.adminReceipt),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined,
                      size: 56, color: Colors.white70),
                  const SizedBox(height: 12),
                  Text(
                    l10n.adminViewReceipt,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled key/value row used in transaction detail panels.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
