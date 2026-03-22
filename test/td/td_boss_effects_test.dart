import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/data/effect_types.dart';
import 'package:wow_warband_companion/td/effects/boss_effects.dart';

void main() {
  late Random rng;

  setUp(() {
    rng = Random(42);
  });

  group('initBossState', () {
    test('initializes fire_zone timer', () {
      final mods = [
        EffectDef.fromJson({'type': 'fire_zone', 'duration': 3.0, 'interval': 5.0}),
      ];
      final state = BossEffectProcessor.initBossState(mods);
      expect(state['fire_zone_timer'], 0.0);
    });

    test('initializes enrage state', () {
      final mods = [
        EffectDef.fromJson({'type': 'enrage', 'hpThreshold': 0.3}),
      ];
      final state = BossEffectProcessor.initBossState(mods);
      expect(state['enraged'], false);
    });

    test('initializes multiple modifiers', () {
      final mods = [
        EffectDef.fromJson({'type': 'fire_zone', 'interval': 5.0}),
        EffectDef.fromJson({'type': 'enrage', 'hpThreshold': 0.3}),
        EffectDef.fromJson({'type': 'teleport_lanes', 'interval': 4.0}),
        EffectDef.fromJson({'type': 'reflect_damage', 'interval': 6.0}),
      ];
      final state = BossEffectProcessor.initBossState(mods);
      expect(state['fire_zone_timer'], 0.0);
      expect(state['enraged'], false);
      expect(state['teleport_timer'], 0.0);
      expect(state['reflect_timer'], 0.0);
      expect(state['reflect_active'], false);
    });
  });

  group('processTick', () {
    test('fire_zone emits event at interval', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'fire_zone',
          'duration': 3.0,
          'interval': 5.0,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      // Not enough time
      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 4.0,
        rng: rng,
      );
      expect(events.whereType<FireZoneEvent>(), isEmpty);

      // Enough time (cumulative 6.0 > 5.0)
      events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 2.0,
        rng: rng,
      );
      expect(events.whereType<FireZoneEvent>().length, 1);
      final fireZone = events.whereType<FireZoneEvent>().first;
      expect(fireZone.duration, 3.0);
    });

    test('enrage triggers below threshold', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'enrage',
          'hpThreshold': 0.3,
          'speedMultiplier': 2.0,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      // Above threshold - no enrage
      BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 0.5,
        bossLane: 0,
        towerCount: 3,
        dt: 0.1,
        rng: rng,
      );
      expect(state['enraged'], false);

      // Below threshold - enrage
      BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 0.2,
        bossLane: 0,
        towerCount: 3,
        dt: 0.1,
        rng: rng,
      );
      expect(state['enraged'], true);
      expect(state['enrage_speed_mult'], 2.0);
    });

    test('enrage at exactly threshold triggers', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'enrage',
          'hpThreshold': 0.3,
          'speedMultiplier': 2.0,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 0.3, // exactly at threshold
        bossLane: 0,
        towerCount: 3,
        dt: 0.1,
        rng: rng,
      );
      expect(state['enraged'], true);
    });

    test('enrage only triggers once', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'enrage',
          'hpThreshold': 0.3,
          'speedMultiplier': 2.0,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      // Trigger enrage
      BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 0.1,
        bossLane: 0,
        towerCount: 3,
        dt: 0.1,
        rng: rng,
      );
      expect(state['enraged'], true);

      // Already enraged - shouldn't change
      state['enrage_speed_mult'] = 2.0;
      BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 0.05,
        bossLane: 0,
        towerCount: 3,
        dt: 0.1,
        rng: rng,
      );
      expect(state['enraged'], true);
    });

    test('teleport_lanes emits teleport event at interval', () {
      final mods = [
        EffectDef.fromJson({'type': 'teleport_lanes', 'interval': 4.0}),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 4.0,
        rng: rng,
      );
      expect(events.whereType<BossTeleportEvent>().length, 1);
      final teleport = events.whereType<BossTeleportEvent>().first;
      expect(teleport.newLane, isNot(0)); // should teleport to different lane
    });

    test('summon_adds emits spawn events at interval', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'summon_adds',
          'interval': 6.0,
          'count': 2,
          'hpFraction': 0.2,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 6.0,
        rng: rng,
      );
      expect(events.whereType<SpawnAddEvent>().length, 2);
    });

    test('reflect_damage toggles on and off', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'reflect_damage',
          'interval': 6.0,
          'duration': 2.0,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      // Activate reflect
      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 6.0,
        rng: rng,
      );
      expect(events.whereType<ReflectDamageToggleEvent>().length, 1);
      expect(
        events.whereType<ReflectDamageToggleEvent>().first.active,
        true,
      );
      expect(state['reflect_active'], true);

      // Deactivate reflect after duration
      events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 2.0,
        rng: rng,
      );
      expect(events.whereType<ReflectDamageToggleEvent>().length, 1);
      expect(
        events.whereType<ReflectDamageToggleEvent>().first.active,
        false,
      );
      expect(state['reflect_active'], false);
    });

    test('knockback_tower emits event at interval', () {
      final mods = [
        EffectDef.fromJson({'type': 'knockback_tower', 'interval': 5.0}),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 4,
        dt: 5.0,
        rng: rng,
      );
      expect(events.whereType<KnockbackTowerEvent>().length, 1);
      final kb = events.whereType<KnockbackTowerEvent>().first;
      expect(kb.towerIndex, lessThan(4));
    });

    test('knockback_tower skipped when no towers', () {
      final mods = [
        EffectDef.fromJson({'type': 'knockback_tower', 'interval': 5.0}),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 0, // no towers
        dt: 5.0,
        rng: rng,
      );
      expect(events.whereType<KnockbackTowerEvent>(), isEmpty);
    });

    test('stacking_damage emits tick every frame', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'stacking_damage',
          'damagePerSecond': 2.0,
          'rampRate': 1.5,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 1.0,
        rng: rng,
      );
      expect(events.whereType<StackingDamageTickEvent>().length, 1);
      final tick1 = events.whereType<StackingDamageTickEvent>().first;
      expect(tick1.damagePerTower, greaterThan(0));

      // Second tick should do more damage (ramp)
      events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 1.0,
        rng: rng,
      );
      final tick2 = events.whereType<StackingDamageTickEvent>().first;
      expect(tick2.damagePerTower, greaterThan(tick1.damagePerTower));
    });

    test('wind_push emits event at interval', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'wind_push',
          'interval': 4.0,
          'pushAmount': 0.3,
        }),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      var events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 4.0,
        rng: rng,
      );
      expect(events.whereType<WindPushEvent>().length, 1);
      expect(events.whereType<WindPushEvent>().first.pushAmount, 0.3);
    });

    test('unknown modifier type is silently skipped', () {
      final mods = [
        EffectDef.fromJson({'type': 'future_boss_mechanic', 'power': 999}),
      ];
      final state = BossEffectProcessor.initBossState(mods);

      final events = BossEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        bossHpFraction: 1.0,
        bossLane: 0,
        towerCount: 3,
        dt: 1.0,
        rng: rng,
      );
      expect(events, isEmpty); // no crash, no events
    });
  });

  group('processOnDeath', () {
    test('split_on_death returns split event', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'split_on_death',
          'count': 3,
          'hpFraction': 0.3,
        }),
      ];

      final result = BossEffectProcessor.processOnDeath(
        modifiers: mods,
        bossMaxHp: 1000,
        bossSpeed: 0.04,
        bossLane: 1,
        bossPosition: 0.5,
      );
      expect(result, isNotNull);
      expect(result!.count, 3);
      expect(result.hpEach, 300); // 1000 * 0.3
      expect(result.speed, 0.06); // 0.04 * 1.5
      expect(result.laneIndex, 1);
      expect(result.position, 0.5);
    });

    test('no split_on_death returns null', () {
      final mods = [
        EffectDef.fromJson({'type': 'enrage', 'hpThreshold': 0.3}),
      ];

      final result = BossEffectProcessor.processOnDeath(
        modifiers: mods,
        bossMaxHp: 1000,
        bossSpeed: 0.04,
        bossLane: 0,
        bossPosition: 0.3,
      );
      expect(result, isNull);
    });

    test('empty modifiers returns null', () {
      final result = BossEffectProcessor.processOnDeath(
        modifiers: [],
        bossMaxHp: 1000,
        bossSpeed: 0.04,
        bossLane: 0,
        bossPosition: 0.3,
      );
      expect(result, isNull);
    });
  });
}
