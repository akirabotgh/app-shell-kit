import 'package:app_shell_kit/app_shell_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Released: the generated build_info.dart has been written by `app-fleet release`.
const _released = ShellAppInfo(
  appId: 'ai.rodin.test',
  appName: 'Test App',
  appVersion: '1.4.37',
  buildNumber: 812,
  sourceCommit: 'a3f9c2e',
);

// The old three-argument form every pre-0.4.0 app uses. Must keep compiling.
const _legacy = ShellAppInfo(
  appId: 'ai.rodin.legacy',
  appName: 'Legacy App',
  appVersion: '1.0.0',
);

ShellConfigClient _client({String supportEmail = ''}) {
  return ShellConfigClient(
    httpClient: MockClient(
      (_) async => http.Response(
        '{"revision": 1, "publisher": {"tradingName": "Rodin", '
        '"supportEmail": "$supportEmail"}}',
        200,
      ),
    ),
  );
}

void main() {
  test('versionLabel is one string for every surface', () {
    expect(_released.versionLabel, '1.4.37 (812) · a3f9c2e');
    expect(_released.isReleased, isTrue);
    expect(_legacy.versionLabel, '1.0.0 (unreleased)');
    expect(_legacy.isReleased, isFalse);
    // Build number alone is not a release: both values must be real.
    const half = ShellAppInfo(
      appId: 'x',
      appName: 'x',
      appVersion: '1.0.0',
      buildNumber: 3,
    );
    expect(half.isReleased, isFalse);
  });

  testWidgets('About shows version, build and source commit', (tester) async {
    await tester.pumpWidget(
      ShellApp(
        info: _released,
        configClient: _client(),
        home: const ShellAboutPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 1.4.37 (812) · a3f9c2e'), findsOneWidget);
    // Tests run in debug mode, where the shell line is also present; the app
    // version line above is the one that survives into release builds.
    expect(find.textContaining('shell $kShellKitVersion'), findsOneWidget);
  });

  testWidgets('an unreleased app says so instead of inventing a build', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShellApp(
        info: _legacy,
        configClient: _client(),
        home: const ShellAboutPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0 (unreleased)'), findsOneWidget);
  });

  testWidgets('Settings row and support email carry the same label', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShellApp(
        info: _released,
        configClient: _client(supportEmail: 'help@rodin.ai'),
        home: const ShellSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test App 1.4.37 (812) · a3f9c2e'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);

    final uri = Uri.parse(shellSupportMailto('help@rodin.ai', _released));
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'help@rodin.ai');
    expect(
      uri.queryParameters['subject'],
      'Test App 1.4.37 (812) · a3f9c2e support',
    );
    expect(
      uri.queryParameters['body'],
      contains('Version: 1.4.37 (812) · a3f9c2e'),
    );
    expect(uri.queryParameters['body'], contains('App: ai.rodin.test'));
  });
}
