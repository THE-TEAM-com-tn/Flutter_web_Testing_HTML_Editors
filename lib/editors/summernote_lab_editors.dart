import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart' as enhanced;
import 'package:html_editor_plus/editor_plus.dart' as plus;
import 'package:lms_testing_html_editors/lab/lab_editor.dart';

/// html_editor_enhanced: Summernote in an iframe on web, in a WebView on mobile.
class HtmlEditorEnhancedLab extends StatefulWidget {
  const HtmlEditorEnhancedLab({required this.initialHtml, required this.handle, super.key});

  final String initialHtml;
  final LabEditorHandle handle;

  @override
  State<HtmlEditorEnhancedLab> createState() => _HtmlEditorEnhancedLabState();
}

class _HtmlEditorEnhancedLabState extends State<HtmlEditorEnhancedLab> {
  final enhanced.HtmlEditorController _controller = enhanced.HtmlEditorController();

  @override
  void initState() {
    super.initState();
    widget.handle.attach(_controller.getText);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => enhanced.HtmlEditor(
        controller: _controller,
        htmlEditorOptions: enhanced.HtmlEditorOptions(hint: 'Start typing…', initialText: widget.initialHtml),
        htmlToolbarOptions: const enhanced.HtmlToolbarOptions(
          toolbarPosition: enhanced.ToolbarPosition.aboveEditor,
          toolbarType: enhanced.ToolbarType.nativeGrid,
        ),
        otherOptions: enhanced.OtherOptions(height: constraints.maxHeight),
        callbacks: enhanced.Callbacks(onInit: widget.handle.markReady),
      ),
    );
  }
}

/// html_editor_plus: a maintained fork of html_editor_enhanced, with its new "plus" API
/// (the HTML kept in the controller's value).
///
/// The plus API ships no formatting toolbar: it sets Summernote's `toolbar: []` and its bundled
/// summernote-lite.min.css hides `.note-toolbar`. The lab turns Summernote's own toolbar back on:
/// [_toolbar] comes later in the options and wins, and [_showToolbar] beats the CSS rule.
class HtmlEditorPlusLab extends StatefulWidget {
  const HtmlEditorPlusLab({required this.initialHtml, required this.handle, super.key});

  final String initialHtml;
  final LabEditorHandle handle;

  @override
  State<HtmlEditorPlusLab> createState() => _HtmlEditorPlusLabState();
}

class _HtmlEditorPlusLabState extends State<HtmlEditorPlusLab> {
  static const String _toolbar = '''
toolbar: [
  ['history', ['undo', 'redo']],
  ['style', ['style']],
  ['font', ['bold', 'italic', 'underline', 'strikethrough', 'superscript', 'subscript', 'clear']],
  ['fontname', ['fontname', 'fontsize']],
  ['color', ['color']],
  ['para', ['ul', 'ol', 'paragraph', 'height']],
  ['table', ['table']],
  ['insert', ['link', 'picture', 'video', 'hr']],
  ['view', ['codeview', 'help']],
],''';

  static const String _showToolbar = '.note-editor .note-toolbar { display: block !important; }';

  late final plus.HtmlEditorController _controller = plus.HtmlEditorController(initialHtml: widget.initialHtml);

  @override
  void initState() {
    super.initState();
    widget.handle.attach(() async => _controller.html);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return plus.HtmlEditor(
      controller: _controller,
      hint: 'Start typing…',
      customOptions: const [_toolbar],
      cssBuilder: (css, theme) => '$css$_showToolbar',
      onInit: widget.handle.markReady,
    );
  }
}
