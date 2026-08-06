import 'dart:convert';

/// Immutable snapshot of the fleet configuration served by `app-shell-config`.
///
/// PARSING RULE — every field here is optional and defaulted. A build shipped a
/// year ago must still parse a manifest edited today, so parsing NEVER throws on
/// an unknown, missing, renamed or wrongly-typed key: it falls back to the
/// default for that field and keeps going. A malformed manifest must degrade a
/// single value, never take down 200 apps.
class ShellConfig {
  const ShellConfig({
    this.schemaVersion = 1,
    this.revision = 0,
    this.publisher = const ShellPublisher(),
    this.legal = const ShellLegal(),
    this.links = const <ShellLink>[],
    this.flags = const <String, bool>{},
    this.notice,
    this.source = ShellConfigSource.fallback,
  });

  final int schemaVersion;
  final int revision;
  final ShellPublisher publisher;
  final ShellLegal legal;
  final List<ShellLink> links;
  final Map<String, bool> flags;
  final ShellNotice? notice;

  /// Where this snapshot came from. Surfaced on the About page in debug builds
  /// so "did my config change actually land?" is answerable on a device.
  final ShellConfigSource source;

  bool flag(String key, {bool orElse = false}) => flags[key] ?? orElse;

  ShellConfig withSource(ShellConfigSource value) => ShellConfig(
    schemaVersion: schemaVersion,
    revision: revision,
    publisher: publisher,
    legal: legal,
    links: links,
    flags: flags,
    notice: notice,
    source: value,
  );

  /// Parses a manifest, applying any override block for [appId] on top of the
  /// fleet defaults. Returns null only if the payload is not a JSON object at
  /// all — callers treat that as "keep the previous snapshot".
  static ShellConfig? tryParse(String raw, {String? appId}) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      // Per-app overrides win over fleet defaults, shallow-merged one level
      // deep so an app can override just `legal.termsUrl` without restating
      // the whole block.
      if (appId != null) {
        final apps = _map(map['apps']);
        final override = _map(apps[appId]);
        if (override.isNotEmpty) {
          for (final entry in override.entries) {
            final base = map[entry.key];
            final patch = entry.value;
            if (base is Map && patch is Map) {
              map[entry.key] = <String, dynamic>{
                ...Map<String, dynamic>.from(base),
                ...Map<String, dynamic>.from(patch),
              };
            } else {
              map[entry.key] = patch;
            }
          }
        }
      }

      return ShellConfig(
        schemaVersion: _int(map['schemaVersion'], 1),
        revision: _int(map['revision'], 0),
        publisher: ShellPublisher.fromJson(_map(map['publisher'])),
        legal: ShellLegal.fromJson(_map(map['legal'])),
        links: _list(map['links'])
            .map((e) => ShellLink.fromJson(_map(e)))
            .where((e) => e.isValid)
            .toList(growable: false),
        flags: _boolMap(map['flags']),
        notice: ShellNotice.tryFromJson(_map(map['notice'])),
      );
    } catch (_) {
      // Unparseable payload. The caller keeps whatever snapshot it already has.
      return null;
    }
  }
}

enum ShellConfigSource {
  /// Fetched live from `app-shell-config` this launch.
  network,

  /// Served from the in-memory cache within the TTL.
  cache,

  /// The copy bundled into the binary at build time. Means the fetch failed or
  /// has not completed — the app is running on possibly-stale legal text.
  fallback,
}

class ShellPublisher {
  const ShellPublisher({
    this.legalName = '',
    this.tradingName = '',
    this.supportEmail = '',
    this.websiteUrl = '',
    this.addressLines = const <String>[],
  });

  final String legalName;
  final String tradingName;
  final String supportEmail;
  final String websiteUrl;
  final List<String> addressLines;

  factory ShellPublisher.fromJson(Map<String, dynamic> m) => ShellPublisher(
    legalName: _str(m['legalName']),
    tradingName: _str(m['tradingName']),
    supportEmail: _str(m['supportEmail']),
    websiteUrl: _str(m['websiteUrl']),
    addressLines: _list(
      m['addressLines'],
    ).map(_str).where((s) => s.isNotEmpty).toList(growable: false),
  );
}

class ShellLegal {
  const ShellLegal({
    this.termsUrl = '',
    this.privacyUrl = '',
    this.termsRevision = 0,
    this.privacyRevision = 0,
    this.termsEffectiveDate = '',
    this.privacyEffectiveDate = '',
    this.reconsentRequired = false,
  });

  final String termsUrl;
  final String privacyUrl;
  final int termsRevision;
  final int privacyRevision;
  final String termsEffectiveDate;
  final String privacyEffectiveDate;

  /// Set fleet-wide when a terms change is material enough that users must
  /// actively re-accept rather than be silently updated. Apps that gate on
  /// consent read this; apps that do not simply ignore it.
  final bool reconsentRequired;

  factory ShellLegal.fromJson(Map<String, dynamic> m) => ShellLegal(
    termsUrl: _str(m['termsUrl']),
    privacyUrl: _str(m['privacyUrl']),
    termsRevision: _int(m['termsRevision'], 0),
    privacyRevision: _int(m['privacyRevision'], 0),
    termsEffectiveDate: _str(m['termsEffectiveDate']),
    privacyEffectiveDate: _str(m['privacyEffectiveDate']),
    reconsentRequired: _bool(m['reconsentRequired'], false),
  );
}

class ShellLink {
  const ShellLink({this.id = '', this.label = '', this.url = ''});

  final String id;
  final String label;
  final String url;

  bool get isValid => label.isNotEmpty && url.isNotEmpty;

  factory ShellLink.fromJson(Map<String, dynamic> m) => ShellLink(
    id: _str(m['id']),
    label: _str(m['label']),
    url: _str(m['url']),
  );
}

/// A fleet-wide message shown inside every app. This is the only channel that
/// reaches already-installed apps in real time, so it is the incident tool:
/// service outage, urgent legal notice, "update required".
class ShellNotice {
  const ShellNotice({
    required this.severity,
    required this.title,
    required this.body,
    this.dismissible = true,
  });

  final String severity; // info | warning | critical
  final String title;
  final String body;
  final bool dismissible;

  /// Returns null unless the notice is both active and has something to say, so
  /// callers can render it unconditionally without an emptiness check.
  static ShellNotice? tryFromJson(Map<String, dynamic> m) {
    if (m.isEmpty) return null;
    if (!_bool(m['active'], false)) return null;
    final title = _str(m['title']);
    final body = _str(m['body']);
    if (title.isEmpty && body.isEmpty) return null;
    return ShellNotice(
      severity: _str(m['severity']).isEmpty ? 'info' : _str(m['severity']),
      title: title,
      body: body,
      dismissible: _bool(m['dismissible'], true),
    );
  }
}

// --- defensive coercion helpers -------------------------------------------
// Each returns the default rather than throwing, so one bad value in the
// manifest cannot cascade into a parse failure for the whole fleet.

String _str(Object? v) => v is String ? v : (v == null ? '' : v.toString());

int _int(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool _bool(Object? v, bool fallback) {
  if (v is bool) return v;
  if (v is String) {
    if (v.toLowerCase() == 'true') return true;
    if (v.toLowerCase() == 'false') return false;
  }
  return fallback;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];

Map<String, bool> _boolMap(Object? v) {
  final out = <String, bool>{};
  if (v is Map) {
    v.forEach((key, value) {
      if (value is bool) out[key.toString()] = value;
    });
  }
  return out;
}
