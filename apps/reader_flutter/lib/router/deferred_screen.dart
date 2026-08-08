import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Bridges a `deferred as` library into a go_router builder.
///
/// dart2js splits every deferred library into its own `main.dart.js_N.part.js`
/// chunk that is only fetched when [loader] (the generated `loadLibrary()`) is
/// first called. On web that keeps the reader and the admin console out of the
/// initial download; on every other target `loadLibrary()` resolves immediately
/// and this is a no-op wrapper.
///
/// [libraryKey] must be unique per deferred library — it is how we remember
/// that a chunk is already resolved so re-navigating builds synchronously
/// instead of flashing a spinner.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.libraryKey,
    required this.loader,
    required this.builder,
  });

  final String libraryKey;
  final Future<void> Function() loader;
  final WidgetBuilder builder;

  /// Libraries whose chunk has already been fetched this session.
  static final Set<String> _loaded = <String>{};

  /// Warm a chunk ahead of navigation (e.g. on hover/long-press of a book
  /// card) so the tap itself feels instant. Safe to call repeatedly.
  static Future<void> prefetch(
    String libraryKey,
    Future<void> Function() loader,
  ) async {
    if (_loaded.contains(libraryKey)) return;
    await loader();
    _loaded.add(libraryKey);
  }

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  Future<void>? _pending;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (!DeferredScreen._loaded.contains(widget.libraryKey)) {
      _pending = _load();
    }
  }

  Future<void> _load() async {
    try {
      await widget.loader();
      DeferredScreen._loaded.add(widget.libraryKey);
    } catch (e) {
      // A failed chunk fetch (offline, stale deploy) must not be cached as
      // loaded — surface it and let the user retry.
      if (mounted) setState(() => _error = e);
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _pending = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DeferredScreen._loaded.contains(widget.libraryKey)) {
      return widget.builder(context);
    }
    return FutureBuilder<void>(
      future: _pending,
      builder: (context, snapshot) {
        if (_error != null || snapshot.hasError) {
          return _DeferredLoadError(onRetry: _retry);
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return widget.builder(context);
        }
        return const _DeferredLoading();
      },
    );
  }
}

class _DeferredLoading extends StatelessWidget {
  const _DeferredLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DeferredLoadError extends StatelessWidget {
  const _DeferredLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
