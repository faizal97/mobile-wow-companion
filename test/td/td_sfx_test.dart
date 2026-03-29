import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/data/effect_types.dart';
import 'package:wow_warband_companion/td/data/td_sfx_registry.dart';

void main() {
  group('TdSfxRegistry', () {
    late TdSfxRegistry registry;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      registry = TdSfxRegistry();
      await registry.load();
    });

    test('loads successfully', () {
      expect(registry.isLoaded, true);
    });

    // -- Class sound resolution --

    test('resolves default class attack hit', () {
      final path = registry.resolveClassSound('unknown_class', 'attackHit');
      expect(path, 'td/sfx/class/default_hit.mp3');
    });

    test('resolves warrior-specific attack hit', () {
      final path = registry.resolveClassSound('warrior', 'attackHit');
      expect(path, 'td/sfx/class/warrior_hit.mp3');
    });

    test('resolves warrior-specific crit', () {
      final path = registry.resolveClassSound('warrior', 'attackCrit');
      expect(path, 'td/sfx/class/warrior_crit.mp3');
    });

    test('resolves mage-specific attack hit', () {
      final path = registry.resolveClassSound('mage', 'attackHit');
      expect(path, 'td/sfx/class/mage_hit.mp3');
    });

    test('warrior falls back to default for chargeAttack', () {
      final path = registry.resolveClassSound('warrior', 'chargeAttack');
      expect(path, 'td/sfx/class/default_charge.mp3');
    });

    test('all 13 classes have custom attack hit', () {
      final classes = [
        'warrior', 'rogue', 'death knight', 'paladin', 'monk',
        'demon hunter', 'mage', 'hunter', 'warlock', 'evoker',
        'priest', 'druid', 'shaman',
      ];
      for (final cls in classes) {
        final path = registry.resolveClassSound(cls, 'attackHit');
        expect(path, isNot('td/sfx/class/default_hit.mp3'),
            reason: '$cls should have custom attack hit');
        expect(path, contains('class/'), reason: '$cls path should be in class/');
      }
    });

    // -- Dungeon sound resolution --

    test('resolves default dungeon enemy death', () {
      final path = registry.resolveDungeonSound('unknown_dungeon', 'enemyDeath');
      expect(path, 'td/sfx/dungeon/default_enemy_death.mp3');
    });

    test('resolves windrunner_spire dungeon override', () {
      final path = registry.resolveDungeonSound('windrunner_spire', 'enemyDeath');
      expect(path, 'td/sfx/dungeon/ws_enemy_death.mp3');
    });

    test('windrunner_spire falls back for non-overridden sounds', () {
      final path = registry.resolveDungeonSound('windrunner_spire', 'victory');
      expect(path, 'td/sfx/dungeon/default_victory.mp3');
    });

    test('resolves murder_row dungeon override', () {
      final path = registry.resolveDungeonSound('murder_row', 'enemyDeath');
      expect(path, 'td/sfx/dungeon/mr_enemy_death.mp3');
    });

    test('all default dungeon sounds are defined', () {
      final events = [
        'enemyDeath', 'enemySpawn', 'bossDeath', 'bossSpawn',
        'waveStart', 'waveComplete', 'enemyLeak', 'shieldBreak',
        'phaseShift', 'resurrect', 'laneSwitch', 'victory', 'defeat',
      ];
      for (final event in events) {
        final path = registry.resolveDungeonSound('nonexistent', event);
        expect(path, isNotNull, reason: 'Default for $event should exist');
        expect(path, contains('dungeon/default_'));
      }
    });

    // -- UI sound resolution --

    test('resolves default UI sounds', () {
      expect(registry.resolveUiSound('towerPlace'), 'td/sfx/ui/tower_place.mp3');
      expect(registry.resolveUiSound('buttonTap'), 'td/sfx/ui/button_tap.mp3');
      expect(registry.resolveUiSound('gameStart'), 'td/sfx/ui/game_start.mp3');
    });

    test('UI sounds with no dungeon override fall back to default', () {
      final path = registry.resolveUiSound('towerPlace', dungeonKey: 'windrunner_spire');
      // windrunner_spire doesn't define UI overrides in our config
      expect(path, 'td/sfx/ui/tower_place.mp3');
    });

    // -- Affix sound resolution --

    test('resolves affix sounds', () {
      expect(registry.resolveAffixSound('bursting'), 'td/sfx/affix/bursting.mp3');
      expect(registry.resolveAffixSound('sanguine'), 'td/sfx/affix/sanguine.mp3');
      expect(registry.resolveAffixSound('bolstering'), 'td/sfx/affix/bolstering.mp3');
    });

    test('unknown affix returns null', () {
      expect(registry.resolveAffixSound('unknown'), isNull);
    });

    // -- Boss mechanic sound resolution --

    test('resolves boss fire zone sounds', () {
      expect(registry.resolveBossMechanicSound('fire_zone', 'spawn'),
          'td/sfx/boss/fire_zone_spawn.mp3');
      expect(registry.resolveBossMechanicSound('fire_zone', 'tick'),
          'td/sfx/boss/fire_zone_tick.mp3');
    });

    test('resolves boss teleport sound', () {
      expect(registry.resolveBossMechanicSound('teleport_lanes', 'trigger'),
          'td/sfx/boss/teleport.mp3');
    });

    test('resolves boss reflect on/off', () {
      expect(registry.resolveBossMechanicSound('reflect_damage', 'on'),
          'td/sfx/boss/reflect_on.mp3');
      expect(registry.resolveBossMechanicSound('reflect_damage', 'off'),
          'td/sfx/boss/reflect_off.mp3');
    });

    test('unknown mechanic returns null', () {
      expect(registry.resolveBossMechanicSound('unknown', 'trigger'), isNull);
    });

    // -- Event resolution --

    test('resolves TdSfxEvent for class attack', () {
      final event = TdSfxEvent(
        type: TdSfxEventType.attackHit,
        className: 'warrior',
        dungeonKey: 'windrunner_spire',
      );
      expect(registry.resolveEvent(event), 'td/sfx/class/warrior_hit.mp3');
    });

    test('resolves TdSfxEvent for dungeon event', () {
      final event = TdSfxEvent(
        type: TdSfxEventType.enemyDeath,
        dungeonKey: 'windrunner_spire',
      );
      expect(registry.resolveEvent(event), 'td/sfx/dungeon/ws_enemy_death.mp3');
    });

    test('resolves TdSfxEvent for affix', () {
      final event = TdSfxEvent(type: TdSfxEventType.burstingTrigger);
      expect(registry.resolveEvent(event), 'td/sfx/affix/bursting.mp3');
    });

    test('resolves TdSfxEvent for boss mechanic', () {
      final event = TdSfxEvent(type: TdSfxEventType.fireZoneSpawn);
      expect(registry.resolveEvent(event), 'td/sfx/boss/fire_zone_spawn.mp3');
    });

    test('resolves TdSfxEvent for UI', () {
      final event = TdSfxEvent(
        type: TdSfxEventType.towerPlace,
        dungeonKey: 'windrunner_spire',
      );
      expect(registry.resolveEvent(event), 'td/sfx/ui/tower_place.mp3');
    });

    test('resolves all event types without errors', () {
      for (final type in TdSfxEventType.values) {
        final event = TdSfxEvent(
          type: type,
          className: 'warrior',
          dungeonKey: 'windrunner_spire',
        );
        // Should not throw
        final path = registry.resolveEvent(event);
        expect(path, isNotNull, reason: '$type should resolve to a path');
      }
    });
  });

  group('SFX model parsing', () {
    test('TdClassSfxDef.fromJson parses correctly', () {
      final def = TdClassSfxDef.fromJson({
        'attackHit': 'hit.mp3',
        'attackCrit': 'crit.mp3',
      });
      expect(def.attackHit, 'hit.mp3');
      expect(def.attackCrit, 'crit.mp3');
      expect(def.chargeAttack, isNull);
    });

    test('TdClassSfxDef [] operator works', () {
      final def = TdClassSfxDef.fromJson({'attackHit': 'hit.mp3'});
      expect(def['attackHit'], 'hit.mp3');
      expect(def['unknown'], isNull);
    });

    test('TdDungeonSfxDef.fromJson with UI override', () {
      final def = TdDungeonSfxDef.fromJson({
        'enemyDeath': 'death.mp3',
        'ui': {'towerPlace': 'tp.mp3'},
      });
      expect(def.enemyDeath, 'death.mp3');
      expect(def.ui, isNotNull);
      expect(def.ui!.towerPlace, 'tp.mp3');
    });

    test('TdAffixSfxDef.fromJson', () {
      final def = TdAffixSfxDef.fromJson({'trigger': 'boom.mp3'});
      expect(def.trigger, 'boom.mp3');
    });

    test('TdBossMechanicSfxDef.fromJson', () {
      final def = TdBossMechanicSfxDef.fromJson({
        'spawn': 'spawn.mp3',
        'tick': 'tick.mp3',
        'on': 'on.mp3',
        'off': 'off.mp3',
      });
      expect(def.spawn, 'spawn.mp3');
      expect(def.tick, 'tick.mp3');
      expect(def.on, 'on.mp3');
      expect(def.off, 'off.mp3');
      expect(def.trigger, isNull);
    });
  });

  group('Game state SFX events', () {
    test('TdSfxEvent creation', () {
      final event = TdSfxEvent(
        type: TdSfxEventType.attackHit,
        className: 'warrior',
        dungeonKey: 'windrunner_spire',
      );
      expect(event.type, TdSfxEventType.attackHit);
      expect(event.className, 'warrior');
      expect(event.dungeonKey, 'windrunner_spire');
    });

    test('TdSfxEventType has all expected values', () {
      // Verify key event types exist
      expect(TdSfxEventType.values, contains(TdSfxEventType.attackHit));
      expect(TdSfxEventType.values, contains(TdSfxEventType.enemyDeath));
      expect(TdSfxEventType.values, contains(TdSfxEventType.victory));
      expect(TdSfxEventType.values, contains(TdSfxEventType.defeat));
      expect(TdSfxEventType.values, contains(TdSfxEventType.burstingTrigger));
      expect(TdSfxEventType.values, contains(TdSfxEventType.fireZoneSpawn));
      expect(TdSfxEventType.values, contains(TdSfxEventType.towerPlace));
      expect(TdSfxEventType.values, contains(TdSfxEventType.bossEnrage));
    });
  });
}
