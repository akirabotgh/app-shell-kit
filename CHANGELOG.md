# Changelog

Every entry must say whether apps need a rebuild to get the change, because
that is the difference between a free fleet update and 200 store submissions.

## 0.4.0 — 2026-09-03

**Rebuild required** to reach users. Additive — old apps compile unchanged and
read as "unreleased" until they adopt the generated `lib/build_info.dart`.

- `ShellAppInfo` gains `buildNumber` and `sourceCommit`, both optional, and a
  `versionLabel` (`1.4.37 (812) · a3f9c2e`, or `1.0.0 (unreleased)`).
- About, the Settings "About" row, the licence page and the support email
  prefill all show `versionLabel`, so support can ask a user to read one
  string off the screen and know exactly which code they are running.
- Pairs with `app-fleet release`, which derives the version from git and writes
  `pubspec.yaml` and `lib/build_info.dart` in one tagged commit.

## 0.3.0 — 2026-08-06

**Rebuild required** to reach users. No app code changes needed.

- Default config TTL cut from 6 hours to 1. Measured: raw.githubusercontent.com
  holds a ~4.5 minute CDN cache, so a fleet change already has a ~5 minute floor
  before any app can see it. A 6-hour client TTL on top made the notice banner
  too slow for the incidents it exists for. Cost is one small CDN request per
  app per hour.

## 0.2.0 — 2026-08-06

**Rebuild required** to reach users. Additive only — no app code changes needed.

- `ShellApp` now re-checks fleet config when the app returns to the foreground.
  Previously config was read once per process start, so a desktop app left open
  for days, or a phone app resumed rather than cold-started, would never see an
  incident notice or a terms update. The client TTL still applies, so a resume
  inside the window costs no network call.

## 0.1.0 — 2026-08-06

Initial shell. Rebuild required (it is the first version).

- `ShellApp` root widget with `ShellScope` for identity and live config
- `ShellConfigClient`: live fetch → in-memory cache → bundled fallback, never
  throws, shares concurrent requests
- `ShellConfig`: fully defensive parsing, per-app overrides, fleet flags
- Standard pages: Settings, About, Legal (TOS/Privacy), OSS licences
- `ShellNoticeBanner` for fleet-wide incident messaging
- `ShellTheme`: Material 3, mobile-first, one large-screen breakpoint
- `MarkdownLite`: dependency-free legal-text renderer
