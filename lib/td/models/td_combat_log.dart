import 'dart:ui' show Color;

/// A single entry in the combat log.
class TdCombatLogEntry {
  final String message;
  final Color color;

  const TdCombatLogEntry({
    required this.message,
    required this.color,
  });
}
