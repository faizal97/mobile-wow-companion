import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'effect_types.dart';
import 'td_dungeon_registry.dart';

class TdRotation {
  TdRotationDef? _rotation;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Load rotation from assets/td/rotation.json
  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/td/rotation.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _rotation = TdRotationDef.fromJson(data);
      _loaded = true;
    } catch (e) {
      _loaded = true;
    }
  }

  /// Season name (e.g., "Midnight Season 1")
  String get season => _rotation?.season ?? 'Unknown Season';

  /// Dungeon keys in rotation order.
  List<String> get dungeonKeys => _rotation?.dungeonKeys ?? [];

  /// Resolve dungeon keys to full definitions using the registry.
  /// Falls back to all dungeons if rotation is empty.
  List<TdDungeonDef> getDungeons(TdDungeonRegistry registry) {
    final resolved = registry.getDungeons(dungeonKeys);
    return resolved.isNotEmpty ? resolved : registry.allDungeons;
  }
}
