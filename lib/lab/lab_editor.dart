import 'package:flutter/material.dart';

/// Builds one editor loaded with [initialHtml]. The editor reports to [handle].
typedef LabEditorBuilder = Widget Function(BuildContext context, String initialHtml, LabEditorHandle handle);

/// The link between the lab page and the editor it hosts.
///
/// The editor calls [attach] with a function that returns its current HTML, and
/// [markReady] once it can be used (the lab shows the time it took).
class LabEditorHandle {
  LabEditorHandle() : _clock = Stopwatch()..start();

  final Stopwatch _clock;
  Future<String> Function()? _read;

  /// Time from creation to [markReady]; `null` while the editor is still starting.
  final ValueNotifier<Duration?> readyIn = ValueNotifier(null);

  void attach(Future<String> Function() read) => _read = read;

  void markReady() {
    if (readyIn.value == null) readyIn.value = _clock.elapsed;
  }

  Future<String> readHtml() {
    final Future<String> Function()? read = _read;
    if (read == null) return Future.error(StateError('The editor is not ready yet.'));
    return read();
  }

  void dispose() => readyIn.dispose();
}

/// Shown in place of an editor whose converter threw on the input HTML.
class LabEditorError extends StatelessWidget {
  const LabEditorError({required this.stage, required this.error, super.key});

  /// What failed, for example "HTML → Delta".
  final String stage;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 40),
            const SizedBox(height: 12),
            Text('$stage failed', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText('$error', textAlign: TextAlign.center, style: TextStyle(color: colors.error)),
          ],
        ),
      ),
    );
  }
}
