/// The version of the shell compiled into this app.
///
/// `app-fleet drift` reads this constant out of each app's resolved dependency
/// to report which shell version every app in the fleet is actually on. Keep it
/// in lockstep with `version:` in pubspec.yaml and with the git tag — the
/// release check in `app-fleet` fails the release if the three disagree.
const String kShellKitVersion = '0.2.0';

/// Bumped only when the shell changes in a way an app must react to (a new
/// required parameter, a removed page). Apps can assert on this to fail fast at
/// build time instead of misbehaving at runtime.
const int kShellKitContract = 1;
