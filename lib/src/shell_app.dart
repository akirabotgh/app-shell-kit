import 'package:flutter/material.dart';

import 'shell_config.dart';
import 'shell_config_client.dart';
import 'theme/shell_theme.dart';

/// The source commit an app reports before its first release has been cut.
const String kShellUnreleasedCommit = 'unreleased';

/// Identity of one app in the fleet. Supplied by the app, not the shell.
///
/// [appId] must match the `ai.rodin.*` application id used by the platform
/// builds — it is the key the fleet manifest uses for per-app overrides, so a
/// mismatch silently means "overrides never apply".
///
/// [appVersion], [buildNumber] and [sourceCommit] come from the app's generated
/// `lib/build_info.dart`, which `app-fleet release` writes. Apps built from an
/// older template only pass [appVersion]; they read as unreleased until they
/// adopt the generated file.
class ShellAppInfo {
  const ShellAppInfo({
    required this.appId,
    required this.appName,
    required this.appVersion,
    this.tagline = '',
    this.buildNumber = 0,
    this.sourceCommit = kShellUnreleasedCommit,
  });

  final String appId;
  final String appName;
  final String appVersion;
  final String tagline;

  /// Store build number (Android versionCode, Apple CFBundleVersion). 0 means
  /// no release has been cut yet.
  final int buildNumber;

  /// Short hash of the commit the release was cut from.
  final String sourceCommit;

  bool get isReleased =>
      buildNumber > 0 && sourceCommit != kShellUnreleasedCommit;

  /// The one string every surface shows: `1.4.37 (812) · a3f9c2e`, or
  /// `1.0.0 (unreleased)` before the first release. Support asks the user to
  /// read this off the About page, so it must be the same everywhere.
  String get versionLabel => isReleased
      ? '$appVersion ($buildNumber) · $sourceCommit'
      : '$appVersion (unreleased)';
}

/// Root widget for every app in the fleet.
///
/// Wraps MaterialApp so theme, fleet config, the notice banner and the standard
/// pages arrive automatically. An app supplies its identity and its [home]; it
/// does not construct a MaterialApp of its own — doing so opts the app out of
/// every fleet-wide fix.
class ShellApp extends StatefulWidget {
  const ShellApp({
    super.key,
    required this.info,
    required this.home,
    this.seedColor,
    this.themeMode = ThemeMode.system,
    this.configClient,
    this.routes = const <String, WidgetBuilder>{},
    this.navigatorObservers = const <NavigatorObserver>[],
    this.debugShowCheckedModeBanner = false,
  });

  final ShellAppInfo info;
  final Widget home;
  final Color? seedColor;
  final ThemeMode themeMode;

  /// Injectable for tests and for apps pinned to a non-default manifest.
  final ShellConfigClient? configClient;

  final Map<String, WidgetBuilder> routes;
  final List<NavigatorObserver> navigatorObservers;
  final bool debugShowCheckedModeBanner;

  @override
  State<ShellApp> createState() => _ShellAppState();
}

class _ShellAppState extends State<ShellApp> with WidgetsBindingObserver {
  late final ShellConfigClient _client;
  late final bool _ownsClient;
  ShellConfig _config = const ShellConfig();

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.configClient == null;
    _client =
        widget.configClient ?? ShellConfigClient(appId: widget.info.appId);
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  /// Re-check the fleet config when the app comes back to the foreground.
  ///
  /// Without this, config is read once per process start. A desktop app left
  /// open for a week, or a phone app resumed rather than cold-started, would
  /// never see an incident notice or a terms update — which would make the
  /// fleet's only real-time channel unreliable exactly when it matters. The
  /// TTL inside the client means resuming is cheap: past the TTL this is one
  /// small request, inside it there is no network call at all.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final loaded = await _client.load();
    if (!mounted) return;
    setState(() => _config = loaded);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Only close a client we created. Closing an injected one would break a
    // caller that reuses it across widgets or tests.
    if (_ownsClient) _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seedColor ?? ShellTheme.brandSeed;
    return ShellScope(
      info: widget.info,
      config: _config,
      client: _client,
      refresh: _refresh,
      child: MaterialApp(
        title: widget.info.appName,
        debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
        theme: ShellTheme.light(seedColor: seed),
        darkTheme: ShellTheme.dark(seedColor: seed),
        themeMode: widget.themeMode,
        routes: widget.routes,
        navigatorObservers: widget.navigatorObservers,
        home: widget.home,
      ),
    );
  }
}

/// Provides app identity and live fleet config to the widget tree.
///
/// `ShellScope.of(context)` is the supported way for app code to read the
/// publisher details, legal URLs and flags.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.info,
    required this.config,
    required this.client,
    required this.refresh,
    required super.child,
  });

  final ShellAppInfo info;
  final ShellConfig config;
  final ShellConfigClient client;
  final Future<void> Function() refresh;

  static ShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellScope>();
    assert(
      scope != null,
      'ShellScope.of() called outside a ShellApp. The app\'s root widget must '
      'be a ShellApp — see app-shell-template/lib/main.dart.',
    );
    return scope!;
  }

  /// Null-returning variant for widgets that can render without config.
  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      oldWidget.config != config || oldWidget.info != info;
}
