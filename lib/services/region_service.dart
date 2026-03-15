import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/battlenet_region.dart';

/// Persists the user's active region and detection results.
class RegionService {
  static const _activeRegionKey = 'active_region';
  static const _detectedRegionsKey = 'detected_regions';
  static const _detectionDoneKey = 'region_detection_done';

  final SharedPreferences _prefs;

  RegionService(this._prefs);

  BattleNetRegion get activeRegion {
    final key = _prefs.getString(_activeRegionKey);
    return BattleNetRegion.fromKey(key ?? '') ?? BattleNetRegion.us;
  }

  Future<void> setActiveRegion(BattleNetRegion region) async {
    await _prefs.setString(_activeRegionKey, region.key);
  }

  Map<BattleNetRegion, int> get detectedRegions {
    final raw = _prefs.getString(_detectedRegionsKey);
    if (raw == null) return {};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = <BattleNetRegion, int>{};
      for (final entry in map.entries) {
        final region = BattleNetRegion.fromKey(entry.key);
        if (region != null) {
          result[region] = entry.value as int;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDetectedRegions(Map<BattleNetRegion, int> regions) async {
    final map = <String, int>{};
    for (final entry in regions.entries) {
      map[entry.key.key] = entry.value;
    }
    await _prefs.setString(_detectedRegionsKey, jsonEncode(map));
  }

  bool get isRegionDetectionDone {
    return _prefs.getBool(_detectionDoneKey) ?? false;
  }

  Future<void> markRegionDetectionDone() async {
    await _prefs.setBool(_detectionDoneKey, true);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_activeRegionKey);
    await _prefs.remove(_detectedRegionsKey);
    await _prefs.remove(_detectionDoneKey);
  }
}
