import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shell_app.dart';
import '../shell_version.dart';
import '../widgets/shell_notice_banner.dart';
import 'shell_legal_page.dart';

/// Standard About page: app identity, publisher details, legal links.
///
/// Publisher name, address and support email come from the fleet manifest, not
/// from app code — so a company rename or an address change is one commit for
/// the whole fleet rather than 200 edits.
class ShellAboutPage extends StatelessWidget {
  const ShellAboutPage({super.key, this.icon});

  /// Optional app-specific mark. Falls back to the fleet logo.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final scope = ShellScope.of(context);
    final info = scope.info;
    final config = scope.config;
    final publisher = config.publisher;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 24),
            Center(
              child:
                  icon ??
                  Icon(
                    Icons.apps_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                info.appName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (info.tagline.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 6,
                ),
                child: Text(
                  info.tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Version ${info.versionLabel}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Center(
                child: ShellConfigSourceChip(
                  source: config.source,
                  revision: config.revision,
                ),
              ),
              Center(
                child: Text(
                  'shell $kShellKitVersion · ${info.appId}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ShellLegalPage(document: ShellLegalDocument.terms),
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
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Open source licences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: info.appName,
                applicationVersion: info.versionLabel,
                applicationLegalese: publisher.legalName.isEmpty
                    ? null
                    : '© ${DateTime.now().year} ${publisher.legalName}',
              ),
            ),
            for (final link in config.links)
              ListTile(
                leading: Icon(
                  link.url.startsWith('mailto:')
                      ? Icons.mail_outline
                      : Icons.open_in_new,
                ),
                title: Text(link.label),
                onTap: () => openShellLink(context, link.url),
              ),
            const Divider(),
            if (publisher.legalName.isNotEmpty ||
                publisher.addressLines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (publisher.legalName.isNotEmpty)
                      Text(
                        publisher.legalName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    for (final line in publisher.addressLines)
                      Text(line, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens an external link, degrading to a copyable dialog if the platform
/// refuses.
///
/// Never let a failed launch be a dead end: on a locked-down desktop or a
/// misconfigured mail handler `launchUrl` returns false or throws, and a
/// silently inert "Contact support" row is a support problem across the whole
/// fleet. Showing the raw URL always leaves the user a route.
Future<void> openShellLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Fall through to the copyable dialog.
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Open this link'),
      content: SelectableText(url),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.of(dialogContext).pop();
            messenger?.showSnackBar(
              const SnackBar(content: Text('Link copied')),
            );
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
