import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/data/effect_types.dart';

void main() {
  group('TowerArchetype', () {
    test('fromString parses valid values', () {
      expect(TowerArchetype.fromString('melee'), TowerArchetype.melee);
      expect(TowerArchetype.fromString('Ranged'), TowerArchetype.ranged);
      expect(TowerArchetype.fromString('SUPPORT'), TowerArchetype.support);
      expect(TowerArchetype.fromString('aoe'), TowerArchetype.aoe);
    });

    test('fromString defaults to melee for unknown', () {
      expect(TowerArchetype.fromString('unknown'), TowerArchetype.melee);
      expect(TowerArchetype.fromString(''), TowerArchetype.melee);
    });
  });

  group('EffectDef', () {
    test('fromJson parses type and params', () {
      final effect = EffectDef.fromJson({
        'type': 'extra_targets',
        'value': 2,
      });
      expect(effect.type, 'extra_targets');
      expect(effect.value, 2.0);
    });

    test('fromJson handles missing type', () {
      final effect = EffectDef.fromJson({});
      expect(effect.type, 'unknown');
    });

    test('fromJson preserves all params', () {
      final effect = EffectDef.fromJson({
        'type': 'dot',
        'percentDamage': 0.3,
        'duration': 3.0,
        'ticks': 3,
      });
      expect(effect.params['percentDamage'], 0.3);
      expect(effect.params['duration'], 3.0);
      expect(effect.params['ticks'], 3);
    });

    test('convenience getters return correct values', () {
      final effect = EffectDef.fromJson({
        'type': 'test',
        'value': 5.0,
        'duration': 2.5,
        'chance': 0.7,
        'radius': 3.0,
        'multiplier': 1.5,
        'stacks': 4,
        'target': 'enemy',
      });
      expect(effect.value, 5.0);
      expect(effect.duration, 2.5);
      expect(effect.chance, 0.7);
      expect(effect.radius, 3.0);
      expect(effect.multiplier, 1.5);
      expect(effect.stacks, 4);
      expect(effect.target, 'enemy');
    });

    test('convenience getters return defaults for missing params', () {
      final effect = EffectDef.fromJson({'type': 'empty'});
      expect(effect.value, 0);
      expect(effect.duration, 0);
      expect(effect.chance, 0);
      expect(effect.radius, 0);
      expect(effect.multiplier, 1);
      expect(effect.stacks, 0);
      expect(effect.target, '');
    });
  });

  group('PassiveDef', () {
    test('fromJson parses all fields', () {
      final passive = PassiveDef.fromJson({
        'name': 'Cleave',
        'description': 'Hits 2 closest enemies',
        'trigger': 'on_attack',
        'nth': 3,
        'effects': [
          {'type': 'extra_targets', 'value': 1},
        ],
      });
      expect(passive.name, 'Cleave');
      expect(passive.description, 'Hits 2 closest enemies');
      expect(passive.trigger, 'on_attack');
      expect(passive.nth, 3);
      expect(passive.effects.length, 1);
      expect(passive.effects.first.type, 'extra_targets');
    });

    test('fromJson handles missing fields with defaults', () {
      final passive = PassiveDef.fromJson({});
      expect(passive.name, 'Unknown');
      expect(passive.description, '');
      expect(passive.trigger, 'passive');
      expect(passive.nth, 0);
      expect(passive.effects, isEmpty);
    });
  });

  group('TdClassDef', () {
    test('fromJson parses warrior correctly', () {
      final def = TdClassDef.fromJson('warrior', {
        'archetype': 'melee',
        'passive': {
          'name': 'Cleave',
          'description': 'Hits 2 closest enemies',
          'trigger': 'on_attack',
          'effects': [
            {'type': 'extra_targets', 'value': 1},
          ],
        },
        'attack_color': '#C69B6D',
      });
      expect(def.name, 'warrior');
      expect(def.archetype, TowerArchetype.melee);
      expect(def.passive.name, 'Cleave');
      expect(def.passive.trigger, 'on_attack');
      expect(def.passive.effects.length, 1);
      expect(def.passive.effects.first.type, 'extra_targets');
    });

    test('fromJson handles missing fields gracefully', () {
      final def = TdClassDef.fromJson('unknown', {});
      expect(def.archetype, TowerArchetype.melee);
      expect(def.passive.effects, isEmpty);
      expect(def.passive.name, 'None');
    });

    test('fromJson parses different archetypes', () {
      for (final arch in ['melee', 'ranged', 'support', 'aoe']) {
        final def = TdClassDef.fromJson('test', {'archetype': arch});
        expect(def.archetype, TowerArchetype.fromString(arch));
      }
    });
  });

  group('LanePatternDef', () {
    test('fromJson parses type and params', () {
      final lp = LanePatternDef.fromJson({
        'type': 'drift',
        'bias': 0.6,
      });
      expect(lp.type, 'drift');
      expect(lp.params['bias'], 0.6);
    });

    test('fromJson defaults to spread', () {
      final lp = LanePatternDef.fromJson({});
      expect(lp.type, 'spread');
    });
  });

  group('TdDungeonDef', () {
    test('fromJson parses dungeon with modifiers', () {
      final def = TdDungeonDef.fromJson('test_dungeon', {
        'name': 'Test Dungeon',
        'short_name': 'TD',
        'theme': 'A test dungeon',
        'enemy_color': '#FF0000',
        'boss_color': '#00FF00',
        'enemy_icon': 'ghost',
        'boss_icon': 'fire',
        'hp_multiplier': 1.5,
        'speed_multiplier': 0.8,
        'enemy_count_modifier': 2,
        'lane_pattern': {'type': 'spread'},
        'enemy_modifiers': [
          {'type': 'shield', 'hits': 2, 'chance': 0.3},
        ],
        'boss_modifiers': [
          {'type': 'enrage', 'hpThreshold': 0.3, 'speedMultiplier': 2.0},
        ],
      });
      expect(def.key, 'test_dungeon');
      expect(def.name, 'Test Dungeon');
      expect(def.shortName, 'TD');
      expect(def.hpMultiplier, 1.5);
      expect(def.speedMultiplier, 0.8);
      expect(def.enemyCountModifier, 2);
      expect(def.enemyModifiers.length, 1);
      expect(def.enemyModifiers.first.type, 'shield');
      expect(def.bossModifiers.length, 1);
      expect(def.bossModifiers.first.type, 'enrage');
      expect(def.lanePattern.type, 'spread');
    });

    test('fromJson handles empty/missing fields', () {
      final def = TdDungeonDef.fromJson('empty', {});
      expect(def.key, 'empty');
      expect(def.name, 'empty');
      expect(def.hpMultiplier, 1.0);
      expect(def.speedMultiplier, 1.0);
      expect(def.enemyCountModifier, 0);
      expect(def.enemyModifiers, isEmpty);
      expect(def.bossModifiers, isEmpty);
      expect(def.lanePattern.type, 'spread');
    });
  });

  group('TdRotationDef', () {
    test('fromJson parses rotation', () {
      final rot = TdRotationDef.fromJson({
        'version': 1,
        'season': 'Test Season',
        'dungeon_keys': ['dungeon_a', 'dungeon_b'],
      });
      expect(rot.version, 1);
      expect(rot.season, 'Test Season');
      expect(rot.dungeonKeys, ['dungeon_a', 'dungeon_b']);
    });

    test('fromJson handles missing fields', () {
      final rot = TdRotationDef.fromJson({});
      expect(rot.version, 1);
      expect(rot.season, '');
      expect(rot.dungeonKeys, isEmpty);
    });
  });
}
