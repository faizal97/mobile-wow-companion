import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'effect_types.dart';

/// Archetype display info loaded from classes.json.
class ArchetypeInfo {
  final String name;
  final double damageMult;
  final double attackSpeed;
  final String targeting;
  final String description;
  final String stats;

  const ArchetypeInfo({
    required this.name,
    required this.damageMult,
    required this.attackSpeed,
    required this.targeting,
    required this.description,
    required this.stats,
  });

  factory ArchetypeInfo.fromJson(String name, Map<String, dynamic> json) {
    return ArchetypeInfo(
      name: name,
      damageMult: (json['damageMult'] as num?)?.toDouble() ?? 0,
      attackSpeed: (json['attackSpeed'] as num?)?.toDouble() ?? 0,
      targeting: json['targeting'] as String? ?? 'none',
      description: json['description'] as String? ?? '',
      stats: json['stats'] as String? ?? '',
    );
  }
}

class TdClassRegistry {
  final Map<String, TdClassDef> _classes = {};
  final Map<String, ArchetypeInfo> _archetypes = {};
  TdClassDef? _fallback;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Load classes from assets/td/classes.json
  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/td/classes.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Parse archetypes
      final archetypes = data['archetypes'] as Map<String, dynamic>? ?? {};
      for (final entry in archetypes.entries) {
        _archetypes[entry.key] = ArchetypeInfo.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        );
      }

      // Parse fallback
      if (data['_fallback'] != null) {
        _fallback = TdClassDef.fromJson('_fallback', data['_fallback']);
      }

      // Parse classes
      final classes = data['classes'] as Map<String, dynamic>? ?? {};
      for (final entry in classes.entries) {
        _classes[entry.key.toLowerCase()] = TdClassDef.fromJson(
          entry.key.toLowerCase(),
          entry.value as Map<String, dynamic>,
        );
      }

      _loaded = true;
    } catch (e) {
      // Graceful fallback — log but don't crash
      _loaded = true; // mark as loaded even on error so game doesn't hang
    }
  }

  /// Get class definition by WoW class name (case-insensitive).
  /// Returns fallback for unknown classes.
  TdClassDef getClass(String className) {
    return _classes[className.toLowerCase()] ?? fallback;
  }

  /// Get archetype display info. Returns null if not loaded.
  ArchetypeInfo? getArchetype(TowerArchetype archetype) {
    return _archetypes[archetype.name];
  }

  /// The fallback class definition for unknown classes.
  TdClassDef get fallback => _fallback ?? TdClassDef.fromJson('unknown', {});

  /// All loaded class names.
  List<String> get allClassNames => _classes.keys.toList();
}
