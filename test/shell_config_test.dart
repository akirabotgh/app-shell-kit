import 'package:app_shell_kit/app_shell_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShellConfig.tryParse', () {
    test('parses a well-formed manifest', () {
      final config = ShellConfig.tryParse('''
      {
        "schemaVersion": 1,
        "revision": 7,
        "publisher": {"legalName": "Acme Ltd", "supportEmail": "a@b.c"},
        "legal": {"termsUrl": "https://x/tos.md", "termsRevision": 3},
        "links": [{"id": "w", "label": "Web", "url": "https://x"}],
        "flags": {"analyticsEnabled": true}
      }
      ''');

      expect(config, isNotNull);
      expect(config!.revision, 7);
      expect(config.publisher.legalName, 'Acme Ltd');
      expect(config.legal.termsRevision, 3);
      expect(config.links.single.label, 'Web');
      expect(config.flag('analyticsEnabled'), isTrue);
    });

    // The whole fleet-update model rests on these: a manifest edited today must
    // not break a binary compiled a year ago.
    test('ignores unknown keys rather than failing', () {
      final config = ShellConfig.tryParse(
          '{"revision": 2, "somethingInventedLater": {"deep": [1,2]}}');
      expect(config, isNotNull);
      expect(config!.revision, 2);
    });

    test('defaults every missing field', () {
      final config = ShellConfig.tryParse('{}');
      expect(config, isNotNull);
      expect(config!.revision, 0);
      expect(config.publisher.legalName, '');
      expect(config.legal.termsUrl, '');
      expect(config.links, isEmpty);
      expect(config.notice, isNull);
      expect(config.flag('anything'), isFalse);
      expect(config.flag('anything', orElse: true), isTrue);
    });

    test('survives wrongly-typed values by coercing or defaulting', () {
      final config = ShellConfig.tryParse('''
      {
        "revision": "12",
        "publisher": "not an object",
        "links": "not a list",
        "flags": {"good": true, "bad": "yes"},
        "legal": {"reconsentRequired": "true"}
      }
      ''');
      expect(config, isNotNull);
      expect(config!.revision, 12, reason: 'numeric string coerces');
      expect(config.publisher.legalName, '');
      expect(config.links, isEmpty);
      expect(config.flag('good'), isTrue);
      expect(config.flag('bad'), isFalse,
          reason: 'non-bool flag is dropped, not guessed');
      expect(config.legal.reconsentRequired, isTrue);
    });

    test('returns null on unparseable input so the caller keeps its snapshot',
        () {
      expect(ShellConfig.tryParse('not json at all'), isNull);
      expect(ShellConfig.tryParse('[1,2,3]'), isNull,
          reason: 'a JSON array is not a manifest');
    });

    test('drops links missing a label or url', () {
      final config = ShellConfig.tryParse('''
      {"links": [
        {"label": "Good", "url": "https://x"},
        {"label": "No url"},
        {"url": "https://no-label"}
      ]}
      ''');
      expect(config!.links, hasLength(1));
      expect(config.links.single.label, 'Good');
    });
  });

  group('per-app overrides', () {
    const manifest = '''
    {
      "revision": 5,
      "publisher": {"legalName": "Fleet Co", "supportEmail": "fleet@x.com"},
      "flags": {"analyticsEnabled": false},
      "apps": {
        "ai.rodin.special": {
          "publisher": {"supportEmail": "special@x.com"},
          "flags": {"analyticsEnabled": true}
        }
      }
    }
    ''';

    test('an app with no override block gets fleet defaults', () {
      final config = ShellConfig.tryParse(manifest, appId: 'ai.rodin.plain');
      expect(config!.publisher.supportEmail, 'fleet@x.com');
      expect(config.flag('analyticsEnabled'), isFalse);
    });

    test('an override wins over the fleet default', () {
      final config = ShellConfig.tryParse(manifest, appId: 'ai.rodin.special');
      expect(config!.publisher.supportEmail, 'special@x.com');
      expect(config.flag('analyticsEnabled'), isTrue);
    });

    test('an override merges rather than replacing the whole block', () {
      final config = ShellConfig.tryParse(manifest, appId: 'ai.rodin.special');
      expect(config!.publisher.legalName, 'Fleet Co',
          reason: 'overriding supportEmail must not wipe legalName');
    });
  });

  group('ShellNotice', () {
    test('is null unless active', () {
      final config = ShellConfig.tryParse(
          '{"notice": {"active": false, "title": "Down"}}');
      expect(config!.notice, isNull);
    });

    test('is null when active but empty', () {
      final config = ShellConfig.tryParse(
          '{"notice": {"active": true, "title": "", "body": ""}}');
      expect(config!.notice, isNull);
    });

    test('parses an active notice and defaults severity to info', () {
      final config = ShellConfig.tryParse(
          '{"notice": {"active": true, "title": "Heads up", "body": "b"}}');
      expect(config!.notice, isNotNull);
      expect(config.notice!.title, 'Heads up');
      expect(config.notice!.severity, 'info');
      expect(config.notice!.dismissible, isTrue);
    });
  });
}
