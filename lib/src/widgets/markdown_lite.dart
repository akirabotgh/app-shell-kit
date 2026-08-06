import 'package:flutter/material.dart';

/// A deliberately tiny Markdown renderer for legal documents.
///
/// WHY NOT a Markdown package: this widget is compiled into every app in the
/// fleet on five platforms. A rendering dependency is a fleet-wide upgrade
/// treadmill and a fleet-wide break risk, for content that is headings,
/// paragraphs, bullets and bold. Those are handled here in ~80 lines with no
/// dependency. If legal text ever needs tables or images, revisit — but that
/// should be a decision, not a default.
///
/// Supports: `#`..`####` headings, `-`/`*` bullets, `>` blockquote,
/// `**bold**`, blank-line paragraph breaks. Anything else renders as plain
/// text, which is safe: unknown syntax is shown, never swallowed.
class MarkdownLite extends StatelessWidget {
  const MarkdownLite(this.source, {super.key, this.padding});

  final String source;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];
    final paragraph = StringBuffer();

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RichLine(
            paragraph.toString().trim(),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
      paragraph.clear();
    }

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trimLeft();

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      final heading = _headingLevel(trimmed);
      if (heading > 0) {
        flushParagraph();
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 20, bottom: 8),
            child: _RichLine(
              trimmed.substring(heading).trim(),
              style: _headingStyle(theme, heading),
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: theme.textTheme.bodyMedium),
                Expanded(
                  child: _RichLine(
                    trimmed.substring(2).trim(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        blocks.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 3),
              ),
            ),
            child: _RichLine(
              trimmed.replaceFirst(RegExp(r'^>\s?'), ''),
              style: theme.textTheme.bodySmall,
            ),
          ),
        );
        continue;
      }

      // Ordinary text: accumulate so wrapped source lines join into one
      // paragraph rather than each becoming its own block.
      if (paragraph.isNotEmpty) paragraph.write(' ');
      paragraph.write(trimmed);
    }
    flushParagraph();

    return Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }

  static int _headingLevel(String line) {
    var level = 0;
    while (level < line.length && line[level] == '#' && level < 4) {
      level++;
    }
    // Require the space, so "#hashtag" is text rather than a heading.
    if (level > 0 && level < line.length && line[level] == ' ') return level;
    return 0;
  }

  static TextStyle? _headingStyle(ThemeData theme, int level) {
    switch (level) {
      case 1:
        return theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        );
      case 2:
        return theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        );
      case 3:
        return theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
      default:
        return theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
    }
  }
}

/// Renders `**bold**` inline; everything else is literal.
class _RichLine extends StatelessWidget {
  const _RichLine(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return SelectableText.rich(TextSpan(style: style, children: spans));
  }
}
