# Changelog

Every entry must say whether apps need a rebuild to get the change, because
that is the difference between a free fleet update and 200 store submissions.

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
