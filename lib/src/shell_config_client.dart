import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'shell_config.dart';

/// Default location of the fleet manifest.
///
/// Every app points here unless it is deliberately pinned elsewhere (a staging
/// manifest, say). Changing this constant is a fleet-wide event: it only takes
/// effect in apps rebuilt afterwards, so prefer editing the manifest itself.
const String kDefaultManifestUrl =
    'https://raw.githubusercontent.com/akirabotgh/app-shell-config/main/manifest/v1/shell.json';

/// Fetches fleet configuration and legal documents, with a bundled fallback.
///
/// Failure model, in priority order:
///   1. live fetch this launch                 -> ShellConfigSource.network
///   2. in-memory snapshot within the TTL      -> ShellConfigSource.cache
///   3. copy bundled into the binary at build  -> ShellConfigSource.fallback
///
/// The app ALWAYS gets a usable config. A network outage, a DNS failure, a
/// throttled CDN or a malformed manifest degrades to stale-but-working; none of
/// them can produce a crash or an empty legal screen. That property is the
/// reason the fleet can be steered from one JSON file without it being a
/// single point of failure for 200 shipped apps.
class ShellConfigClient {
  ShellConfigClient({
    this.manifestUrl = kDefaultManifestUrl,
    this.appId,
    this.timeout = const Duration(seconds: 6),
    this.ttl = const Duration(hours: 6),
    http.Client? httpClient,
    Future<String> Function(String key)? assetLoader,
  })  : _http = httpClient ?? http.Client(),
        _loadAsset = assetLoader ?? rootBundle.loadString;

  final String manifestUrl;
  final String? appId;
  final Duration timeout;
  final Duration ttl;

  final http.Client _http;
  final Future<String> Function(String key) _loadAsset;

  ShellConfig? _cached;
  DateTime? _cachedAt;
  Future<ShellConfig>? _inFlight;

  /// Returns the current config, fetching if the cache is cold or stale.
  ///
  /// Concurrent callers during a fetch share one request rather than each
  /// opening their own — with several widgets reading config on first frame
  /// that would otherwise be a thundering herd against the CDN on every launch.
  Future<ShellConfig> load({bool forceRefresh = false}) {
    if (!forceRefresh && _cached != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) < ttl) {
        return Future.value(_cached!.withSource(ShellConfigSource.cache));
      }
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  /// The last snapshot without touching the network. Null before the first
  /// successful load — use for synchronous reads on a rebuild, not first paint.
  ShellConfig? get snapshot => _cached;

  Future<ShellConfig> _fetch() async {
    try {
      final response =
          await _http.get(Uri.parse(manifestUrl)).timeout(timeout);
      if (response.statusCode == 200) {
        final parsed = ShellConfig.tryParse(response.body, appId: appId);
        if (parsed != null) {
          _cached = parsed;
          _cachedAt = DateTime.now();
          return parsed.withSource(ShellConfigSource.network);
        }
        // 200 but unparseable: a bad manifest push. Fall through to the last
        // good snapshot rather than adopting garbage.
      }
    } catch (_) {
      // Offline, DNS failure, timeout, TLS error. Fall through.
    }

    if (_cached != null) {
      return _cached!.withSource(ShellConfigSource.cache);
    }
    return _loadBundledFallback();
  }

  Future<ShellConfig> _loadBundledFallback() async {
    try {
      final raw = await _loadAsset(
          'packages/app_shell_kit/assets/fallback/shell.json');
      final parsed = ShellConfig.tryParse(raw, appId: appId);
      if (parsed != null) {
        return parsed.withSource(ShellConfigSource.fallback);
      }
    } catch (_) {
      // Asset missing or corrupt — should be impossible, but the shell must
      // still render rather than throwing on first frame.
    }
    return const ShellConfig();
  }

  /// Fetches a legal document, falling back to the copy bundled at build time.
  ///
  /// [fallbackAsset] is the bundled filename (`tos.md` / `privacy.md`). An app
  /// with no network still shows the terms it shipped with, which is what the
  /// stores require — an empty legal screen is a rejection.
  Future<ShellDocument> loadDocument({
    required String url,
    required String fallbackAsset,
  }) async {
    if (url.isNotEmpty) {
      try {
        final response = await _http.get(Uri.parse(url)).timeout(timeout);
        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          return ShellDocument(response.body, ShellConfigSource.network);
        }
      } catch (_) {
        // Fall through to the bundled copy.
      }
    }
    try {
      final raw = await _loadAsset(
          'packages/app_shell_kit/assets/fallback/$fallbackAsset');
      return ShellDocument(raw, ShellConfigSource.fallback);
    } catch (_) {
      return const ShellDocument(
        'This document is temporarily unavailable. '
        'Please check your connection and try again.',
        ShellConfigSource.fallback,
      );
    }
  }

  void dispose() => _http.close();
}

class ShellDocument {
  const ShellDocument(this.text, this.source);

  final String text;
  final ShellConfigSource source;
}
