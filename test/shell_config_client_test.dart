import 'package:app_shell_kit/app_shell_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A stand-in for the bundled fallback assets, so these tests exercise the
/// degradation path without needing a real asset bundle.
Future<String> _fakeAssets(String key) async {
  if (key.endsWith('shell.json')) {
    return '{"revision": 1, "publisher": {"legalName": "Bundled Co"}}';
  }
  if (key.endsWith('tos.md')) return '# Bundled terms';
  if (key.endsWith('privacy.md')) return '# Bundled privacy';
  throw Exception('no such asset: $key');
}

void main() {
  test('a successful fetch is reported as network', () async {
    final client = ShellConfigClient(
      httpClient: MockClient((_) async =>
          http.Response('{"revision": 42}', 200)),
      assetLoader: _fakeAssets,
    );
    final config = await client.load();
    expect(config.revision, 42);
    expect(config.source, ShellConfigSource.network);
  });

  test('a second load inside the TTL is served from cache without refetching',
      () async {
    var calls = 0;
    final client = ShellConfigClient(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{"revision": 9}', 200);
      }),
      assetLoader: _fakeAssets,
    );
    await client.load();
    final second = await client.load();
    expect(calls, 1);
    expect(second.source, ShellConfigSource.cache);
    expect(second.revision, 9);
  });

  test('forceRefresh bypasses the cache', () async {
    var calls = 0;
    final client = ShellConfigClient(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{"revision": $calls}', 200);
      }),
      assetLoader: _fakeAssets,
    );
    await client.load();
    final second = await client.load(forceRefresh: true);
    expect(calls, 2);
    expect(second.revision, 2);
  });

  // The degradation ladder. These are the tests that make it safe to steer 200
  // shipped apps from one JSON file.
  test('a network failure falls back to the bundled copy', () async {
    final client = ShellConfigClient(
      httpClient: MockClient((_) async => throw Exception('offline')),
      assetLoader: _fakeAssets,
    );
    final config = await client.load();
    expect(config.source, ShellConfigSource.fallback);
    expect(config.publisher.legalName, 'Bundled Co');
  });

  test('a non-200 falls back rather than adopting an error body', () async {
    final client = ShellConfigClient(
      httpClient: MockClient((_) async => http.Response('<html>502</html>', 502)),
      assetLoader: _fakeAssets,
    );
    final config = await client.load();
    expect(config.source, ShellConfigSource.fallback);
    expect(config.publisher.legalName, 'Bundled Co');
  });

  test('a 200 with a malformed body keeps the last good snapshot', () async {
    var calls = 0;
    final client = ShellConfigClient(
      httpClient: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('{"revision": 5}', 200)
            : http.Response('}{ broken', 200);
      }),
      assetLoader: _fakeAssets,
    );
    await client.load();
    final second = await client.load(forceRefresh: true);
    expect(second.revision, 5,
        reason: 'a bad manifest push must not downgrade a running app');
    expect(second.source, ShellConfigSource.cache);
  });

  test('everything failing still yields a usable config, never a throw',
      () async {
    final client = ShellConfigClient(
      httpClient: MockClient((_) async => throw Exception('offline')),
      assetLoader: (_) async => throw Exception('no bundle'),
    );
    final config = await client.load();
    expect(config.source, ShellConfigSource.fallback);
    expect(config.revision, 0);
  });

  test('concurrent loads share one request', () async {
    var calls = 0;
    final client = ShellConfigClient(
      httpClient: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{"revision": 3}', 200);
      }),
      assetLoader: _fakeAssets,
    );
    await Future.wait([client.load(), client.load(), client.load()]);
    expect(calls, 1, reason: 'first frame must not stampede the CDN');
  });

  group('loadDocument', () {
    test('returns the fetched document', () async {
      final client = ShellConfigClient(
        httpClient: MockClient((_) async => http.Response('# Live terms', 200)),
        assetLoader: _fakeAssets,
      );
      final doc = await client.loadDocument(
          url: 'https://x/tos.md', fallbackAsset: 'tos.md');
      expect(doc.text, '# Live terms');
      expect(doc.source, ShellConfigSource.network);
    });

    test('falls back to the bundled copy when offline', () async {
      final client = ShellConfigClient(
        httpClient: MockClient((_) async => throw Exception('offline')),
        assetLoader: _fakeAssets,
      );
      final doc = await client.loadDocument(
          url: 'https://x/tos.md', fallbackAsset: 'tos.md');
      expect(doc.text, '# Bundled terms');
      expect(doc.source, ShellConfigSource.fallback);
    });

    test('falls back when the response is 200 but empty', () async {
      final client = ShellConfigClient(
        httpClient: MockClient((_) async => http.Response('   ', 200)),
        assetLoader: _fakeAssets,
      );
      final doc = await client.loadDocument(
          url: 'https://x/tos.md', fallbackAsset: 'tos.md');
      expect(doc.source, ShellConfigSource.fallback,
          reason: 'an empty legal screen fails store review');
    });

    test('never returns empty text, even with no bundle', () async {
      final client = ShellConfigClient(
        httpClient: MockClient((_) async => throw Exception('offline')),
        assetLoader: (_) async => throw Exception('no bundle'),
      );
      final doc = await client.loadDocument(url: '', fallbackAsset: 'tos.md');
      expect(doc.text.trim(), isNotEmpty);
    });
  });
}
