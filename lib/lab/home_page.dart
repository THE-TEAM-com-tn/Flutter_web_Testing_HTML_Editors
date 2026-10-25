import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lms_testing_html_editors/catalog.dart';
import 'package:lms_testing_html_editors/lab/widgets.dart';

/// The list of editors, grouped by how they are built.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('HTML editor lab')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double cardWidth = math.min(420, constraints.maxWidth - 32);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card.filled(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find a replacement for the LMS lesson editor', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Open an editor.  2. Pick a sample, or paste the HTML of a real lesson.  '
                        '3. Edit it.  4. Press Export HTML: you get the HTML the editor would save, how the student '
                        'app renders it, and the tags it lost on the way.',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${editorCatalog.length} editors: the ones that kept the LMS media (PDF, YouTube and Calendar '
                        'iframes, <video>) through a round trip. Versions, dates, licences and download counts were '
                        'checked on pub.dev, npm and GitHub on 25 Oct 2026.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              for (final EditorFamily family in EditorFamily.values) ...[
                const SizedBox(height: 24),
                Text(family.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(family.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final EditorInfo info in editorCatalog.where((e) => e.family == family))
                      SizedBox(width: cardWidth, child: _EditorCard(info: info)),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.info});

  final EditorInfo info;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? small = theme.textTheme.bodySmall;

    Widget fact(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: small)),
            ],
          ),
        );

    Widget point(String sign, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 16, child: Text(sign, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/editor/${info.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(info.name, style: theme.textTheme.titleMedium)),
                  HealthBadge(health: info.health),
                ],
              ),
              const SizedBox(height: 2),
              Text('${info.package} · ${info.released}', style: small?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(info.summary),
              const SizedBox(height: 10),
              fact(Icons.gavel_outlined, info.license),
              fact(Icons.devices_outlined, info.platforms),
              fact(Icons.code, info.htmlModel),
              fact(Icons.trending_up, info.popularity),
              const SizedBox(height: 6),
              for (final String pro in info.pros) point('+', const Color(0xFF2E7D32), pro),
              for (final String con in info.cons) point('−', theme.colorScheme.error, con),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(info.link, style: small?.copyWith(color: theme.colorScheme.primary)),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Try it'),
                    onPressed: () => Navigator.pushNamed(context, '/editor/${info.id}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
