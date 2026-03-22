import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/data/effect_types.dart';
import 'package:wow_warband_companion/td/effects/enemy_effects.dart';

void main() {
  late Random rng;

  setUp(() {
    rng = Random(42);
  });

  group('initModifierState', () {
    test('initializes shield hits', () {
      final mods = [
        EffectDef.fromJson({'type': 'shield', 'hits': 3}),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);
      expect(state['shield_hits'], 3);
    });

    test('initializes phase state', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'phase',
          'invulnDuration': 0.5,
          'interval': 3.0,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);
      expect(state['phase_timer'], 0.0);
      expect(state['phase_invuln'], false);
    });

    test('initializes resurrect state', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'resurrect',
          'chance': 0.5,
          'hpFraction': 0.4,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);
      expect(state['has_resurrected'], false);
    });

    test('initializes lane_switch state', () {
      final mods = [
        EffectDef.fromJson({'type': 'lane_switch', 'positionThreshold': 0.5}),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);
      expect(state['has_switched'], false);
    });

    test('handles multiple modifiers', () {
      final mods = [
        EffectDef.fromJson({'type': 'shield', 'hits': 2}),
        EffectDef.fromJson({'type': 'resurrect', 'chance': 1.0}),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);
      expect(state['shield_hits'], 2);
      expect(state['has_resurrected'], false);
    });

    test('handles unknown modifier silently', () {
      final mods = [
        EffectDef.fromJson({'type': 'unknown_future_mod'}),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);
      expect(state, isEmpty);
    });
  });

  group('modifyIncomingDamage', () {
    test('spectral reduces damage before position threshold', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'spectral',
          'damageReduction': 0.5,
          'untilPosition': 0.5,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      final damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: mods,
        state: state,
        rawDamage: 100,
        position: 0.3,
      );
      expect(damage, 50); // 50% reduction
    });

    test('spectral full damage after threshold', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'spectral',
          'damageReduction': 0.5,
          'untilPosition': 0.5,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      final damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: mods,
        state: state,
        rawDamage: 100,
        position: 0.7,
      );
      expect(damage, 100);
    });

    test('shield blocks damage and decrements counter', () {
      final mods = [
        EffectDef.fromJson({'type': 'shield', 'hits': 2}),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      // First hit blocked
      var damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: mods,
        state: state,
        rawDamage: 100,
        position: 0.5,
      );
      expect(damage, 0);
      expect(state['shield_hits'], 1);

      // Second hit blocked
      damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: mods,
        state: state,
        rawDamage: 100,
        position: 0.5,
      );
      expect(damage, 0);
      expect(state['shield_hits'], 0);

      // Third hit goes through
      damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: mods,
        state: state,
        rawDamage: 100,
        position: 0.5,
      );
      expect(damage, 100);
    });

    test('phase blocks damage when invulnerable', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'phase',
          'invulnDuration': 0.5,
          'interval': 3.0,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      // Initially vulnerable
      var damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: mods,
        state: state,
        rawDamage: 100,
        position: 0.5,
      );
      expect(damage, 100);

      // Set invulnerable
      state['phase_invuln'] = true;
      damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: mods,
        state: state,
        rawDamage: 100,
        position: 0.5,
      );
      expect(damage, 0);
    });

    test('no modifiers returns raw damage', () {
      final damage = EnemyEffectProcessor.modifyIncomingDamage(
        modifiers: [],
        state: {},
        rawDamage: 75,
        position: 0.5,
      );
      expect(damage, 75);
    });
  });

  group('processTick', () {
    test('phase toggles invulnerability on timer', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'phase',
          'invulnDuration': 0.5,
          'interval': 2.0,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      // Tick past the interval to trigger invulnerable
      EnemyEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        position: 0.5,
        laneIndex: 0,
        dt: 2.0,
        rng: rng,
      );
      expect(state['phase_invuln'], true);

      // Tick past invuln duration to become vulnerable again
      EnemyEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        position: 0.5,
        laneIndex: 0,
        dt: 0.5,
        rng: rng,
      );
      expect(state['phase_invuln'], false);
    });

    test('accelerate returns speed multiplier based on position', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'accelerate',
          'startSpeedMult': 0.5,
          'endSpeedMult': 1.5,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      // At position 0, speed should be startSpeedMult
      var results = EnemyEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        position: 0.0,
        laneIndex: 0,
        dt: 0.1,
        rng: rng,
      );
      expect(results.length, 1);
      expect(results.first, isA<SetSpeedResult>());
      expect((results.first as SetSpeedResult).multiplier, 0.5);

      // At position 1.0, speed should be endSpeedMult
      results = EnemyEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        position: 1.0,
        laneIndex: 0,
        dt: 0.1,
        rng: rng,
      );
      expect((results.first as SetSpeedResult).multiplier, 1.5);
    });

    test('frost_aura slows towers in lane', () {
      final mods = [
        EffectDef.fromJson({'type': 'frost_aura', 'slowPercent': 0.1}),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      final results = EnemyEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        position: 0.5,
        laneIndex: 2,
        dt: 0.1,
        rng: rng,
      );
      expect(results.length, 1);
      expect(results.first, isA<SlowTowersResult>());
      final slow = results.first as SlowTowersResult;
      expect(slow.lane, 2);
      expect(slow.percent, 0.1);
    });

    test('ranged_attack fires at interval', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'ranged_attack',
          'interval': 2.0,
          'damage': 10.0,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      // Not enough time
      var results = EnemyEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        position: 0.5,
        laneIndex: 1,
        dt: 1.0,
        rng: rng,
      );
      expect(results.whereType<AttackTowerResult>(), isEmpty);

      // Enough time
      results = EnemyEffectProcessor.processTick(
        modifiers: mods,
        state: state,
        position: 0.5,
        laneIndex: 1,
        dt: 1.5, // total 2.5 > 2.0
        rng: rng,
      );
      expect(results.whereType<AttackTowerResult>().length, 1);
      final attack = results.whereType<AttackTowerResult>().first;
      expect(attack.lane, 1);
      expect(attack.damage, 10.0);
    });
  });

  group('processOnDeath', () {
    test('resurrect triggers with chance 1.0', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'resurrect',
          'chance': 1.0,
          'hpFraction': 0.4,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);

      final result = EnemyEffectProcessor.processOnDeath(
        modifiers: mods,
        state: state,
        position: 0.5,
        laneIndex: 1,
        maxHp: 200,
        rng: rng,
      );
      expect(result, isA<EnemyResurrectResult>());
      final res = result as EnemyResurrectResult;
      expect(res.hp, 80); // 200 * 0.4
      expect(res.position, 0.5);
      expect(res.laneIndex, 1);
    });

    test('resurrect only happens once', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'resurrect',
          'chance': 1.0,
          'hpFraction': 0.4,
        }),
      ];
      final state = EnemyEffectProcessor.initModifierState(mods);
      state['has_resurrected'] = true;

      final result = EnemyEffectProcessor.processOnDeath(
        modifiers: mods,
        state: state,
        position: 0.5,
        laneIndex: 1,
        maxHp: 200,
        rng: rng,
      );
      expect(result, isA<EnemyDiedResult>());
    });

    test('no resurrect modifier means normal death', () {
      final result = EnemyEffectProcessor.processOnDeath(
        modifiers: [],
        state: {},
        position: 0.5,
        laneIndex: 0,
        maxHp: 100,
        rng: rng,
      );
      expect(result, isA<EnemyDiedResult>());
    });
  });

  group('rollSpawnModifiers', () {
    test('always applies modifiers without chance param', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'spectral',
          'damageReduction': 0.5,
        }),
      ];
      final result = EnemyEffectProcessor.rollSpawnModifiers(mods, rng);
      expect(result.length, 1);
    });

    test('chance-based modifier with 0.0 never applies', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'shield',
          'hits': 2,
          'chance': 0.0,
        }),
      ];
      final result = EnemyEffectProcessor.rollSpawnModifiers(mods, rng);
      expect(result, isEmpty); // 0% chance = never applies
    });

    test('chance 1.0 always applies', () {
      final mods = [
        EffectDef.fromJson({
          'type': 'shield',
          'hits': 2,
          'chance': 1.0,
        }),
      ];
      final result = EnemyEffectProcessor.rollSpawnModifiers(mods, rng);
      expect(result.length, 1); // chance >= 1.0 always applies
    });

    test('multiple modifiers roll independently', () {
      // chance=1.0 should always apply, chance=0.0 never
      final mods = [
        EffectDef.fromJson({'type': 'spectral', 'damageReduction': 0.5}),
        EffectDef.fromJson({'type': 'shield', 'hits': 2, 'chance': 0.0}),
      ];
      final result = EnemyEffectProcessor.rollSpawnModifiers(mods, rng);
      expect(result.length, 1); // only spectral (no chance param = always)
      expect(result.first.type, 'spectral');
    });
  });
}
