import 'package:flutter/material.dart';
import 'package:lms_testing_html_editors/catalog.dart';

/// A dot and a label for an editor's release activity.
class HealthBadge extends StatelessWidget {
  const HealthBadge({required this.health, super.key});

  final Health health;

  static Color colorOf(Health health) => switch (health) {
        Health.active => const Color(0xFF2E7D32),
        Health.slow => const Color(0xFFEF8F00),
        Health.stale => const Color(0xFFC62828),
      };

  @override
  Widget build(BuildContext context) {
    final Color color = colorOf(health);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 5),
          Text(health.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
