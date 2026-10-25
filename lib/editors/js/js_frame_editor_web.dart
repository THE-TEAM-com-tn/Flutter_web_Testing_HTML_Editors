import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:lms_testing_html_editors/lab/lab_editor.dart';
import 'package:web/web.dart' as web;

/// Web: an `<iframe>` platform view on `editors/<page>.html`, driven over `postMessage`
/// (the protocol is described in `web/editors/bridge.js`).
class JsFrameView extends StatefulWidget {
  const JsFrameView({required this.page, required this.label, required this.initialHtml, required this.handle, super.key});

  final String page;
  final String label;
  final String initialHtml;
  final LabEditorHandle handle;

  @override
  State<JsFrameView> createState() => _JsFrameViewState();
}

class _JsFrameViewState extends State<JsFrameView> {
  static int _nextChannel = 0;

  final String _channel = 'lab-${_nextChannel++}';
  late final String _viewType = 'js-frame-editor-$_channel';
  final Map<int, Completer<String>> _pending = {};
  int _nextRequest = 0;
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final web.HTMLIFrameElement frame = web.HTMLIFrameElement()
        ..src = 'editors/${widget.page}.html?channel=$_channel'
        ..allow = 'clipboard-read; clipboard-write; fullscreen'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      _frame = frame;
      return frame;
    });
    _listener = _onMessage.toJS;
    web.window.addEventListener('message', _listener);
    widget.handle.attach(_readHtml);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    for (final Completer<String> request in _pending.values) {
      if (!request.isCompleted) request.completeError(StateError('Editor closed.'));
    }
    super.dispose();
  }

  void _post(Map<String, Object?> message) {
    _frame?.contentWindow?.postMessage({'channel': _channel, ...message}.jsify(), '*'.toJS);
  }

  void _onMessage(web.MessageEvent event) {
    final Object? data = event.data.dartify();
    if (data is! Map || data['channel'] != _channel) return;
    switch (data['type']) {
      case 'ready':
        _post({'type': 'set', 'html': widget.initialHtml});
      case 'loaded':
        widget.handle.markReady();
        if (mounted) setState(() => _loaded = true);
      case 'html':
        _pending.remove((data['id'] as num?)?.toInt())?.complete('${data['html'] ?? ''}');
      case 'error':
        final String message = '${data['message']}';
        final Completer<String>? request = _pending.remove((data['id'] as num?)?.toInt());
        if (request != null) {
          request.completeError(message);
        } else if (mounted) {
          setState(() => _error = message);
        }
    }
  }

  Future<String> _readHtml() {
    final int id = _nextRequest++;
    final Completer<String> request = Completer<String>();
    _pending[id] = request;
    _post({'type': 'get', 'id': id});
    return request.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('${widget.label} did not answer.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(child: HtmlElementView(viewType: _viewType)),
        if (!_loaded && _error == null)
          Positioned.fill(
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text('Loading ${widget.label} from the CDN…'),
                  ],
                ),
              ),
            ),
          ),
        if (_error != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Material(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                leading: Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                title: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _error = null),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
