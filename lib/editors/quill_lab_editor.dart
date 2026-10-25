import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lms_testing_html_editors/editors/lms_html_quill_codec.dart';
import 'package:lms_testing_html_editors/lab/lab_editor.dart';

/// flutter_quill with its default toolbar, reading and writing HTML through the LMS codec
/// ([HtmlQuillCodec]).
class QuillLabEditor extends StatefulWidget {
  const QuillLabEditor({required this.initialHtml, required this.handle, super.key});

  final String initialHtml;
  final LabEditorHandle handle;

  @override
  State<QuillLabEditor> createState() => _QuillLabEditorState();
}

class _QuillLabEditorState extends State<QuillLabEditor> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  QuillController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    try {
      _controller = QuillController(
        document: Document.fromDelta(HtmlQuillCodec.htmlToDelta(widget.initialHtml)),
        selection: const TextSelection.collapsed(offset: 0),
      );
      widget.handle.attach(() async => HtmlQuillCodec.deltaToHtml(_controller!.document.toDelta()));
    } catch (error) {
      _error = error;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.handle.markReady());
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QuillController? controller = _controller;
    if (controller == null) return LabEditorError(stage: 'HTML → Delta', error: _error!);
    return Column(
      children: [
        QuillSimpleToolbar(
          controller: controller,
          config: QuillSimpleToolbarConfig(embedButtons: FlutterQuillEmbeds.toolbarButtons()),
        ),
        const Divider(height: 1),
        Expanded(
          child: QuillEditor(
            controller: controller,
            focusNode: _focusNode,
            scrollController: _scrollController,
            config: QuillEditorConfig(
              padding: const EdgeInsets.all(16),
              placeholder: 'Start typing…',
              embedBuilders: [
                ...FlutterQuillEmbeds.defaultEditorBuilders(),
                for (final String type in HtmlEmbedType.all) _RawHtmlEmbedBuilder(type),
              ],
              unknownEmbedBuilder: const _RawHtmlEmbedBuilder('unknown'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws an embed that holds raw HTML (the LMS codec's `iframe`, `table` and `html`
/// embeds) as a card, like the LMS editor does. Tables show their content.
class _RawHtmlEmbedBuilder extends EmbedBuilder {
  const _RawHtmlEmbedBuilder(this.key);

  @override
  final String key;

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final String type = embedContext.node.value.type;
    final Object? data = embedContext.node.value.data;
    final String html = data is String ? data : '$data';
    final ThemeData theme = Theme.of(context);
    final (IconData icon, String title) = switch (type) {
      HtmlEmbedType.iframe => (Icons.web_asset_outlined, 'Embedded page (iframe)'),
      HtmlEmbedType.table => (Icons.table_chart_outlined, 'Table'),
      HtmlEmbedType.html => (Icons.code, 'HTML kept as written'),
      _ => (Icons.extension_outlined, 'Unknown embed "$type"'),
    };
    final RegExpMatch? src = RegExp(r'''src=["']([^"']+)''').firstMatch(html);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 4),
          if (type == HtmlEmbedType.table)
            HtmlWidget(html)
          else
            Text(
              src?.group(1) ?? html,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
        ],
      ),
    );
  }
}
