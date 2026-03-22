import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'effect_types.dart';

class TdClassRegistry {
  final Map<String, TdClassDef> _classes = {};
  TdClassDef? _fallback;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Load classes from assets/td/classes.json
  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/td/classes.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

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

  /// The fallback class definition for unknown classes.
  TdClassDef get fallback => _fallback ?? TdClassDef.fromJson('unknown', {});

  /// All loaded class names.
  List<String> get allClassNames => _classes.keys.toList();
}
