import 'package:app_shell_kit/app_shell_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _info = ShellAppInfo(
  appId: 'ai.rodin.test',
  appName: 'Test App',
  appVersion: '1.2.3',
);

void main() {
  testWidgets('config reaches the tree via ShellScope', (tester) async {
    final client = ShellConfigClient(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"revision": 11, "publisher": {"tradingName": "Rodin"}}',
          200,
        ),
      ),
    );

    String? seen;
    await tester.pumpWidget(
      ShellApp(
        info: _info,
        configClient: client,
        home: Builder(
          builder: (context) {
            seen = ShellScope.of(context).config.publisher.tradingName;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, 'Rodin');
  });

  testWidgets('returning to the foreground re-checks the fleet config', (
    tester,
  ) async {
    var calls = 0;
    final client = ShellConfigClient(
      // Zero TTL so the resume path actually refetches inside the test rather
      // than being served from cache.
      ttl: Duration.zero,
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{"revision": $calls}', 200);
      }),
    );

    await tester.pumpWidget(
      ShellApp(info: _info, configClient: client, home: const SizedBox()),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    // Simulate the app being backgrounded and resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      calls,
      2,
      reason:
          'an app resumed rather than cold-started must still pick up an '
          'incident notice',
    );
  });

  testWidgets('resuming inside the TTL costs no network call', (tester) async {
    var calls = 0;
    final client = ShellConfigClient(
      ttl: const Duration(hours: 6),
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{"revision": 1}', 200);
      }),
    );

    await tester.pumpWidget(
      ShellApp(info: _info, configClient: client, home: const SizedBox()),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(calls, 1, reason: 'resume must not hammer the CDN');
  });

  testWidgets('an app renders even when config never loads', (tester) async {
    final client = ShellConfigClient(
      httpClient: MockClient((_) async => throw Exception('offline')),
      assetLoader: (_) async => throw Exception('no bundle'),
    );
    await tester.pumpWidget(
      ShellApp(
        info: _info,
        configClient: client,
        home: const Scaffold(body: Text('app content')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('app content'), findsOneWidget);
  });
}
