import 'package:flutter/material.dart';

import '../shell_app.dart';
import '../shell_config.dart';

/// Renders the fleet-wide notice from the manifest, if one is active.
///
/// This is the fleet's only real-time channel to already-installed apps: set
/// `notice.active` in `app-shell-config` and every app shows the message on its
/// next launch, with no rebuild. Use it for outages, urgent legal changes and
/// forced-update warnings.
///
/// Place it at the top of the app's main scaffold body. When no notice is
/// active it renders a zero-size box, so it is safe to leave in permanently —
/// and leaving it in permanently is the point: a banner an app has to add
/// during an incident is a banner that is not there during the incident.
class ShellNoticeBanner extends StatefulWidget {
  const ShellNoticeBanner({super.key});

  @override
  State<ShellNoticeBanner> createState() => _ShellNoticeBannerState();
}

class _ShellNoticeBannerState extends State<ShellNoticeBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final notice = ShellScope.maybeOf(context)?.config.notice;
    if (notice == null || _dismissed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (notice.severity) {
      'critical' => (scheme.errorContainer, scheme.onErrorContainer),
      'warning' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };

    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              notice.severity == 'critical'
                  ? Icons.error_outline
                  : Icons.info_outline,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notice.title.isNotEmpty)
                    Text(
                      notice.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: foreground),
                    ),
                  if (notice.body.isNotEmpty)
                    Text(
                      notice.body,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                ],
              ),
            ),
            if (notice.dismissible)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: foreground),
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _dismissed = true),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small chip showing where the current config came from. Shown on the About
/// page in debug builds only, so "did my manifest change actually reach the
/// device?" is answerable without a debugger.
class ShellConfigSourceChip extends StatelessWidget {
  const ShellConfigSourceChip({
    super.key,
    required this.source,
    required this.revision,
  });

  final ShellConfigSource source;
  final int revision;

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      ShellConfigSource.network => 'live',
      ShellConfigSource.cache => 'cached',
      ShellConfigSource.fallback => 'bundled fallback',
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('config rev $revision · $label'),
      labelStyle: Theme.of(context).textTheme.labelSmall,
    );
  }
}
