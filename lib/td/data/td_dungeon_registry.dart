import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'effect_types.dart';

class TdDungeonRegistry {
  final Map<String, TdDungeonDef> _dungeons = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Load dungeons from assets/td/dungeons.json
  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/td/dungeons.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final dungeons = data['dungeons'] as Map<String, dynamic>? ?? {};
      for (final entry in dungeons.entries) {
        _dungeons[entry.key] = TdDungeonDef.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        );
      }

      _loaded = true;
    } catch (e) {
      _loaded = true;
    }
  }

  /// Get dungeon by key. Returns null if not found.
  TdDungeonDef? getDungeon(String key) => _dungeons[key];

  /// Get multiple dungeons by keys (skips unknown keys).
  List<TdDungeonDef> getDungeons(List<String> keys) {
    return keys
        .map((k) => _dungeons[k])
        .whereType<TdDungeonDef>()
        .toList();
  }

  /// All dungeon keys.
  List<String> get allKeys => _dungeons.keys.toList();

  /// All dungeon definitions.
  List<TdDungeonDef> get allDungeons => _dungeons.values.toList();
}
