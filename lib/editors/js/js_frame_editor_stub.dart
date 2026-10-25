import 'package:flutter/material.dart';
import 'package:lms_testing_html_editors/lab/lab_editor.dart';

/// Android / iOS: the JavaScript editors run only in the web build of the lab.
class JsFrameView extends StatelessWidget {
  const JsFrameView({required this.page, required this.label, required this.initialHtml, required this.handle, super.key});

  final String page;
  final String label;
  final String initialHtml;
  final LabEditorHandle handle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$label runs in the browser build of the lab (flutter run -d chrome).\n'
          'In a mobile app it would need a WebView (webview_flutter) loading web/editors/$page.html.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
