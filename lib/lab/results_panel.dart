import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lms_testing_html_editors/lab/html_report.dart';

/// One "Export HTML": what went in, what came out, and the comparison.
class LabResult {
  LabResult({required this.input, required this.output, required this.readTime})
      : report = HtmlReport.compare(input, output);

  final String input;
  final String output;
  final Duration readTime;
  final HtmlReport report;
}

/// The exported HTML in four tabs: rendered by flutter_widget_from_html, source out, round trip, source in.
class ResultsPanel extends StatelessWidget {
  const ResultsPanel({required this.result, this.onClose, super.key});

  final LabResult result;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceContainer,
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Rendered'),
                      Tab(text: 'HTML out'),
                      Tab(text: 'Round trip'),
                      Tab(text: 'HTML in'),
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RenderedTab(html: result.output),
                _SourceTab(html: result.output, note: '${result.output.length} characters · read in '
                    '${result.readTime.inMilliseconds} ms'),
                _RoundTripTab(report: result.report),
                _SourceTab(html: result.input, note: '${result.input.length} characters given to the editor'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RenderedTab extends StatelessWidget {
  const _RenderedTab({required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Rendered with flutter_widget_from_html, as a Flutter app would show it to readers.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const Divider(height: 24),
        if (html.trim().isEmpty) const Text('(empty)') else HtmlWidget(html),
      ],
    );
  }
}

class _SourceTab extends StatefulWidget {
  const _SourceTab({required this.html, required this.note});

  final String html;
  final String note;

  @override
  State<_SourceTab> createState() => _SourceTabState();
}

class _SourceTabState extends State<_SourceTab> {
  bool _pretty = true;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(widget.note, style: theme.textTheme.bodySmall),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: true, label: Text('Indented')),
                  ButtonSegment(value: false, label: Text('Raw')),
                ],
                selected: {_pretty},
                onSelectionChanged: (value) => setState(() => _pretty = value.first),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy raw'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.html));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HTML copied')));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.html.isEmpty ? '(empty)' : (_pretty ? prettyHtml(widget.html) : widget.html),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundTripTab extends StatelessWidget {
  const _RoundTripTab({required this.report});

  final HtmlReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<TagChange> lost = report.lost;
    final List<TagChange> added = report.added;
    final int percent = (report.textKept * 100).round();

    Widget line(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        line(
          percent == 100 ? Icons.check_circle : Icons.warning_amber_rounded,
          percent == 100 ? Colors.green : Colors.orange,
          'Text kept: $percent% of ${report.inputWords} words',
        ),
        line(
          lost.isEmpty ? Icons.check_circle : Icons.remove_circle,
          lost.isEmpty ? Colors.green : colors.error,
          lost.isEmpty
              ? 'Nothing lost: every tag and tracked attribute is still there'
              : 'Lost: ${lost.map((c) => '${c.name} ×${c.input - c.output}').join(', ')}',
        ),
        if (added.isNotEmpty)
          line(Icons.add_circle, colors.primary, 'Added: ${added.map((c) => '${c.name} ×${c.output - c.input}').join(', ')}'),
        const SizedBox(height: 4),
        Text(
          'Counts of every tag, and of the attributes ${HtmlReport.trackedAttributes.map((a) => '[$a]').join(' ')}. '
          'Equivalent tags count together (b|strong, i|em, s|strike|del). '
          'Before editing, a perfect editor shows no red row.',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(), 1: FixedColumnWidth(56), 2: FixedColumnWidth(56)},
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
              children: [
                for (final String header in ['Tag / [attribute]', 'In', 'Out'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(header, style: theme.textTheme.labelLarge),
                  ),
              ],
            ),
            for (final TagChange change in report.changes)
              TableRow(
                decoration: BoxDecoration(
                  color: change.lost
                      ? colors.errorContainer
                      : change.added
                          ? colors.primaryContainer.withValues(alpha: 0.5)
                          : null,
                ),
                children: [
                  for (final String cell in [change.name, '${change.input}', '${change.output}'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Text(cell, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
