import 'package:flutter/widgets.dart';
import 'package:lms_testing_html_editors/lab/lab_editor.dart';

import 'js_frame_editor_stub.dart' if (dart.library.js_interop) 'js_frame_editor_web.dart';

/// A browser JavaScript editor running in an iframe: the page `web/editors/<page>.html`,
/// which loads the editor from a CDN and talks to Flutter through `web/editors/bridge.js`.
///
/// Web only; on Android and iOS this shows a notice instead.
class JsFrameEditor extends StatelessWidget {
  const JsFrameEditor({required this.page, required this.label, required this.initialHtml, required this.handle, super.key});

  /// The page name under `web/editors/`, without `.html`.
  final String page;

  /// The editor's name, for the loading and error messages.
  final String label;
  final String initialHtml;
  final LabEditorHandle handle;

  @override
  Widget build(BuildContext context) =>
      JsFrameView(page: page, label: label, initialHtml: initialHtml, handle: handle);
}
