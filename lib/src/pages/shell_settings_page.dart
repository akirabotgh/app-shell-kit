import 'package:flutter/material.dart';

import '../shell_app.dart';
import 'shell_about_page.dart';
import 'shell_legal_page.dart';

/// Standard Settings page.
///
/// Apps add their own rows via [sections]; the legal/about/support block at the
/// bottom is supplied by the shell so every app in the fleet has the same
/// store-required surfaces without anyone remembering to add them.
class ShellSettingsPage extends StatelessWidget {
  const ShellSettingsPage({
    super.key,
    this.sections = const <Widget>[],
    this.title = 'Settings',
  });

  /// App-specific rows, rendered above the standard block.
  final List<Widget> sections;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scope = ShellScope.of(context);
    final config = scope.config;
    final showLegal = config.flag('showLegalInSettings', orElse: true);
    final showAbout = config.flag('showAboutPage', orElse: true);
    final supportEmail = config.publisher.supportEmail;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          children: [
            ...sections,
            if (sections.isNotEmpty) const Divider(),
            if (supportEmail.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Contact support'),
                subtitle: Text(supportEmail),
                onTap: () =>
                    openShellLink(context, _supportMailto(supportEmail, scope)),
              ),
            if (showLegal) ...[
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ShellLegalPage(
                      document: ShellLegalDocument.terms,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ShellLegalPage(
                      document: ShellLegalDocument.privacy,
                    ),
                  ),
                ),
              ),
            ],
            if (showAbout)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: Text(
                  '${scope.info.appName} ${scope.info.appVersion}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ShellAboutPage(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Pre-fills the subject with app identity and version. Support for 200 apps
  /// is unworkable if the first reply is always "which app, which version?".
  static String _supportMailto(String email, ShellScope scope) {
    final subject = Uri.encodeComponent(
      '${scope.info.appName} ${scope.info.appVersion} support',
    );
    final body = Uri.encodeComponent(
      '\n\n---\nApp: ${scope.info.appId}\nVersion: ${scope.info.appVersion}\n',
    );
    return 'mailto:$email?subject=$subject&body=$body';
  }
}
