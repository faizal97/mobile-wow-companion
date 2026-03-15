import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wow_warband_companion/models/battlenet_region.dart';
import 'package:wow_warband_companion/services/region_service.dart';

void main() {
  group('RegionService', () {
    late RegionService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = RegionService(prefs);
    });

    test('activeRegion defaults to US when nothing stored', () {
      expect(service.activeRegion, BattleNetRegion.us);
    });

    test('setActiveRegion persists and returns the region', () async {
      await service.setActiveRegion(BattleNetRegion.eu);
      expect(service.activeRegion, BattleNetRegion.eu);
    });

    test('detectedRegions is empty initially', () {
      expect(service.detectedRegions, isEmpty);
    });

    test('saveDetectedRegions persists region-count map', () async {
      await service.saveDetectedRegions({
        BattleNetRegion.us: 5,
        BattleNetRegion.eu: 12,
      });
      expect(service.detectedRegions[BattleNetRegion.us], 5);
      expect(service.detectedRegions[BattleNetRegion.eu], 12);
    });

    test('isRegionDetectionDone is false initially', () {
      expect(service.isRegionDetectionDone, false);
    });

    test('markRegionDetectionDone sets flag', () async {
      await service.markRegionDetectionDone();
      expect(service.isRegionDetectionDone, true);
    });

    test('clearAll removes all region data', () async {
      await service.setActiveRegion(BattleNetRegion.eu);
      await service.saveDetectedRegions({BattleNetRegion.eu: 3});
      await service.markRegionDetectionDone();
      await service.clearAll();
      expect(service.activeRegion, BattleNetRegion.us);
      expect(service.detectedRegions, isEmpty);
      expect(service.isRegionDetectionDone, false);
    });
  });
}
