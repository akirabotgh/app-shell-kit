import 'package:flutter/material.dart';

import '../shell_app.dart';
import '../shell_config.dart';
import '../shell_config_client.dart';
import '../widgets/markdown_lite.dart';

/// Which legal document a [ShellLegalPage] shows.
enum ShellLegalDocument { terms, privacy }

/// Renders a legal document fetched live from the fleet config repo.
///
/// The document is NOT compiled into the app. That is the single most important
/// property of this page: updating the terms for 200 shipped apps is one commit
/// in `app-shell-config`, not 200 rebuilds and 200 store resubmissions.
///
/// If the fetch fails the page falls back to the copy bundled at build time, so
/// an offline user still sees terms — an empty legal screen fails store review.
class ShellLegalPage extends StatefulWidget {
  const ShellLegalPage({super.key, required this.document});

  final ShellLegalDocument document;

  @override
  State<ShellLegalPage> createState() => _ShellLegalPageState();
}

class _ShellLegalPageState extends State<ShellLegalPage> {
  Future<ShellDocument>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deferred to didChangeDependencies because it needs ShellScope, which is
    // not available in initState.
    _future ??= _load();
  }

  Future<ShellDocument> _load() {
    final scope = ShellScope.of(context);
    final legal = scope.config.legal;
    final isTerms = widget.document == ShellLegalDocument.terms;
    return scope.client.loadDocument(
      url: isTerms ? legal.termsUrl : legal.privacyUrl,
      fallbackAsset: isTerms ? 'tos.md' : 'privacy.md',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTerms = widget.document == ShellLegalDocument.terms;
    final legal = ShellScope.of(context).config.legal;
    final revision = isTerms ? legal.termsRevision : legal.privacyRevision;
    final effective = isTerms
        ? legal.termsEffectiveDate
        : legal.privacyEffectiveDate;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTerms ? 'Terms of Service' : 'Privacy Policy'),
      ),
      body: FutureBuilder<ShellDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data;
          if (doc == null) {
            return const Center(child: Text('Unable to load this document.'));
          }
          return SafeArea(
            child: ListView(
              children: [
                if (doc.source == ShellConfigSource.fallback)
                  Container(
                    width: double.infinity,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Text(
                      'Showing the version included with this app. '
                      'Connect to the internet for the latest.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ConstrainedBox(
                  // Legal text is long; cap the measure so it stays readable on
                  // desktop and tablet instead of running the full window width.
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: MarkdownLite(doc.text),
                ),
                if (revision > 0 || effective.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Text(
                      [
                        if (revision > 0) 'Revision $revision',
                        if (effective.isNotEmpty) 'Effective $effective',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
