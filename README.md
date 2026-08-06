# app_shell_kit

**The shared shell every Rodin app is built on.** Standard pages, theme,
branding, and the client that reads live fleet configuration.

Apps do not copy this code — they depend on it. That is what makes a fleet of
200 one-shot apps maintainable: a fix here reaches all of them.

## Why this repo is public

Every build lane (Ubuntu, the Windows runner on VM107, the Mac runner) has to
run `flutter pub get` and resolve this package. A private git dependency would
mean putting credentials on machines that build code — and the org token is a
classic PAT carrying `admin:org`, which must never land on a build box.

There is nothing sensitive here: it is UI shell code, and the legal text it
renders is published to users anyway. **Never put a secret, key or endpoint
credential in this repo.** App-specific business logic belongs in the app.

## What an app gets

| Piece | What it does |
|---|---|
| `ShellApp` | Root widget. Wraps `MaterialApp`, applies the fleet theme, loads config, exposes `ShellScope` |
| `ShellScope.of(context)` | App identity + live config anywhere in the tree |
| `ShellSettingsPage` | Settings, with the store-required legal/support/about block appended automatically |
| `ShellAboutPage` | App identity, publisher details, legal links, OSS licences |
| `ShellLegalPage` | Renders TOS/Privacy **fetched live**, with bundled fallback |
| `ShellNoticeBanner` | Fleet-wide incident banner, driven from the manifest |
| `ShellTheme` | Fleet brand tokens, mobile-first, one breakpoint |
| `MarkdownLite` | Dependency-free renderer for legal text |

## Minimal use

```dart
import 'package:app_shell_kit/app_shell_kit.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => ShellApp(
        info: const ShellAppInfo(
          appId: 'ai.rodin.example',
          appName: 'Example',
          appVersion: '1.0.0',
        ),
        home: const HomePage(),
      );
}
```

Then anywhere below it:

```dart
final scope = ShellScope.of(context);
scope.config.publisher.supportEmail;     // from the live manifest
scope.config.flag('analyticsEnabled');   // fleet flag
```

## The update model

Three tiers, cheapest first. **Always reach for the cheapest one that works.**

1. **Change the manifest** (`app-shell-config`) — legal text, support email,
   links, flags, incident banner. Reaches every installed app on next launch.
   No rebuild. No store submission. Seconds.
2. **Change this package** — pages, theme, behaviour. One commit, then
   `app-fleet bump` opens a PR against every app repo. Requires a rebuild, and
   for mobile a store resubmission.
3. **Change the template** (`app-shell-template`) — affects new apps only.
   Existing apps need a fleet PR to catch up.

The uncomfortable truth tier 2 encodes: **you cannot update a published mobile
app without a store submission.** Nothing changes that. So the design goal is to
keep as much as possible in tier 1 — which is why legal text is fetched, not
compiled in.

## Rules for changing this package

- **Additive changes only**, unless you are prepared to fix every app. A new
  required parameter on `ShellApp` breaks 200 repos at once.
- **Bump `kShellKitVersion` and `version:` together**, and tag the release.
  `app-fleet` compares all three and refuses a release if they disagree.
- **Bump `kShellKitContract`** only for a genuinely breaking change, so apps
  fail at build time rather than misbehaving at runtime.
- **Think hard before adding a dependency.** See the policy comment in
  `pubspec.yaml` — every dependency here is inherited by 200 apps on 5 platforms.

## Verify

```bash
flutter pub get && flutter analyze && flutter test
```

## Related

- `app-shell-config` — the live manifest and legal docs this package reads
- `app-shell-template` — the template new apps are created from
- `app-fleet` — the CLI that reports drift and updates every app at once
