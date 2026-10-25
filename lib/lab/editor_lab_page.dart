import 'package:flutter/material.dart';
import 'package:lms_testing_html_editors/catalog.dart';
import 'package:lms_testing_html_editors/lab/lab_editor.dart';
import 'package:lms_testing_html_editors/lab/results_panel.dart';
import 'package:lms_testing_html_editors/lab/widgets.dart';
import 'package:lms_testing_html_editors/samples.dart';

/// One editor, a sample document, and the "Export HTML" results.
class EditorLabPage extends StatefulWidget {
  const EditorLabPage({required this.info, this.initialSample = HtmlSamples.lesson, super.key});

  final EditorInfo info;
  final HtmlSample initialSample;

  @override
  State<EditorLabPage> createState() => _EditorLabPageState();
}

class _EditorLabPageState extends State<EditorLabPage> {
  static const double _wideLayout = 1000;

  late HtmlSample _sample = widget.initialSample;
  int _generation = 0;
  LabEditorHandle _handle = LabEditorHandle();
  LabResult? _result;
  bool _exporting = false;

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  /// Rebuilds the editor from scratch with [sample].
  void _load(HtmlSample sample) {
    final LabEditorHandle previous = _handle;
    setState(() {
      _sample = sample;
      _result = null;
      _handle = LabEditorHandle();
      _generation++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  Future<void> _pasteHtml() async {
    final TextEditingController text = TextEditingController(text: _sample.id == 'custom' ? _sample.html : '');
    final String? html = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load your own HTML'),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: text,
            autofocus: true,
            minLines: 12,
            maxLines: 20,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste your own HTML (for example a page from your database or API).',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, text.text), child: const Text('Load')),
        ],
      ),
    );
    text.dispose();
    if (html == null) return;
    _load(HtmlSample(id: 'custom', title: 'Your HTML', description: 'Pasted in the lab.', html: html));
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final Stopwatch clock = Stopwatch()..start();
    try {
      final String output = await _handle.readHtml();
      final LabResult result = LabResult(input: _sample.html, output: output, readTime: clock.elapsed);
      if (!mounted) return;
      setState(() => _result = result);
      if (MediaQuery.sizeOf(context).width < _wideLayout) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => FractionallySizedBox(
            heightFactor: 0.9,
            child: ResultsPanel(result: result),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not read the HTML: $error')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final EditorInfo info = widget.info;
    final ThemeData theme = Theme.of(context);
    final bool wide = MediaQuery.sizeOf(context).width >= _wideLayout;
    final LabResult? result = _result;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.name),
            Text(
              '${info.package} · ${info.released}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12), child: HealthBadge(health: info.health)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownMenu<HtmlSample>(
                  key: ValueKey('sample-$_generation'),
                  initialSelection: HtmlSamples.all.contains(_sample) ? _sample : null,
                  label: const Text('Sample'),
                  hintText: _sample.title,
                  width: 260,
                  dropdownMenuEntries: [
                    for (final HtmlSample sample in HtmlSamples.all)
                      DropdownMenuEntry(value: sample, label: sample.title),
                  ],
                  onSelected: (sample) {
                    if (sample != null) _load(sample);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste HTML…'),
                  onPressed: _pasteHtml,
                ),
                IconButton(
                  tooltip: 'Reload the editor with the sample',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _load(_sample),
                ),
                ValueListenableBuilder<Duration?>(
                  valueListenable: _handle.readyIn,
                  builder: (context, readyIn, _) => Chip(
                    avatar: Icon(readyIn == null ? Icons.hourglass_top : Icons.timer_outlined, size: 18),
                    label: Text(readyIn == null ? 'Starting…' : 'Ready in ${readyIn.inMilliseconds} ms'),
                  ),
                ),
                FilledButton.icon(
                  icon: _exporting
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.output),
                  label: const Text('Export HTML'),
                  onPressed: _exporting ? null : _export,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              [_sample.description, if (info.tip != null) 'Tip: ${info.tip}'].join('\n'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    clipBehavior: Clip.antiAlias,
                    child: KeyedSubtree(
                      key: ValueKey('${info.id}-$_generation'),
                      child: Builder(builder: (context) => info.builder(context, _sample.html, _handle)),
                    ),
                  ),
                ),
                if (wide && result != null)
                  SizedBox(
                    width: 460,
                    child: Card(
                      margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                      clipBehavior: Clip.antiAlias,
                      child: ResultsPanel(result: result, onClose: () => setState(() => _result = null)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
