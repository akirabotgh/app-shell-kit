/// The version of the shell compiled into this app.
///
/// Shown on the About page in debug builds so a developer can tell which shell
/// an app was compiled against. Keep it in lockstep with `version:` in
/// pubspec.yaml and with the git tag; nothing enforces that yet, so the tagger
/// checks by hand. This is the SHELL's version — the app's own version, build
/// number and source commit come from the app's generated `lib/build_info.dart`.
const String kShellKitVersion = '0.4.0';

/// Bumped only when the shell changes in a way an app must react to (a new
/// required parameter, a removed page). Apps can assert on this to fail fast at
/// build time instead of misbehaving at runtime.
const int kShellKitContract = 1;
