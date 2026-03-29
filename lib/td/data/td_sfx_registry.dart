import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'effect_types.dart';

/// Registry that loads SFX definitions from sfx.json and resolves sound paths
/// with a fallback chain: dungeon override → category default → null.
class TdSfxRegistry {
  // Defaults
  TdClassSfxDef _defaultClass = const TdClassSfxDef();
  TdDungeonSfxDef _defaultDungeon = const TdDungeonSfxDef();
  TdUiSfxDef _defaultUi = const TdUiSfxDef();

  // Per-key overrides
  final Map<String, TdClassSfxDef> _classes = {};
  final Map<String, TdDungeonSfxDef> _dungeons = {};
  final Map<String, TdAffixSfxDef> _affixes = {};
  final Map<String, TdBossMechanicSfxDef> _bossMechanics = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Load SFX definitions from assets/td/sfx.json.
  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/td/sfx.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Parse defaults
      final defaults = data['defaults'] as Map<String, dynamic>? ?? {};
      if (defaults['class'] != null) {
        _defaultClass = TdClassSfxDef.fromJson(
            Map<String, dynamic>.from(defaults['class'] as Map));
      }
      if (defaults['dungeon'] != null) {
        _defaultDungeon = TdDungeonSfxDef.fromJson(
            Map<String, dynamic>.from(defaults['dungeon'] as Map));
      }
      if (defaults['ui'] != null) {
        _defaultUi = TdUiSfxDef.fromJson(
            Map<String, dynamic>.from(defaults['ui'] as Map));
      }

      // Parse per-class overrides
      final classes = data['classes'] as Map<String, dynamic>? ?? {};
      for (final entry in classes.entries) {
        _classes[entry.key] = TdClassSfxDef.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
      }

      // Parse per-dungeon overrides
      final dungeons = data['dungeons'] as Map<String, dynamic>? ?? {};
      for (final entry in dungeons.entries) {
        _dungeons[entry.key] = TdDungeonSfxDef.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
      }

      // Parse affix SFX
      final affixes = data['affixes'] as Map<String, dynamic>? ?? {};
      for (final entry in affixes.entries) {
        _affixes[entry.key] = TdAffixSfxDef.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
      }

      // Parse boss mechanic SFX
      final bossMechanics =
          data['bossMechanics'] as Map<String, dynamic>? ?? {};
      for (final entry in bossMechanics.entries) {
        _bossMechanics[entry.key] = TdBossMechanicSfxDef.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
      }

      _loaded = true;
    } catch (e) {
      _loaded = true; // fail silently — game works without sounds
    }
  }

  // -------------------------------------------------------------------------
  // Resolution methods — each returns an asset path or null
  // -------------------------------------------------------------------------

  /// Resolve a class sound. Checks class-specific → default.
  String? resolveClassSound(String className, String eventKey) {
    final classOverride = _classes[className.toLowerCase()]?[eventKey];
    if (classOverride != null) return classOverride;
    return _defaultClass[eventKey];
  }

  /// Resolve a dungeon sound. Checks dungeon-specific → default.
  String? resolveDungeonSound(String dungeonKey, String eventKey) {
    final dungeonOverride = _dungeons[dungeonKey]?[eventKey];
    if (dungeonOverride != null) return dungeonOverride;
    return _defaultDungeon[eventKey];
  }

  /// Resolve a UI sound. Checks dungeon UI override → default UI.
  String? resolveUiSound(String eventKey, {String? dungeonKey}) {
    if (dungeonKey != null) {
      final dungeonUiOverride = _dungeons[dungeonKey]?.ui?[eventKey];
      if (dungeonUiOverride != null) return dungeonUiOverride;
    }
    return _defaultUi[eventKey];
  }

  /// Resolve an affix sound.
  String? resolveAffixSound(String affixKey) {
    return _affixes[affixKey]?.trigger;
  }

  /// Resolve a boss mechanic sound by mechanic type and sub-event.
  /// [subEvent] is one of: 'trigger', 'spawn', 'tick', 'on', 'off'.
  String? resolveBossMechanicSound(String mechanicType, String subEvent) {
    final def = _bossMechanics[mechanicType];
    if (def == null) return null;
    switch (subEvent) {
      case 'trigger': return def.trigger;
      case 'spawn': return def.spawn;
      case 'tick': return def.tick;
      case 'on': return def.on;
      case 'off': return def.off;
      default: return def.trigger;
    }
  }

  /// Resolve a [TdSfxEvent] to an asset path. Returns null if no sound is
  /// configured for this event.
  String? resolveEvent(TdSfxEvent event) {
    switch (event.type) {
      // Class sounds
      case TdSfxEventType.attackHit:
        return resolveClassSound(event.className ?? '', 'attackHit');
      case TdSfxEventType.attackCrit:
        return resolveClassSound(event.className ?? '', 'attackCrit');
      case TdSfxEventType.chargeAttack:
        return resolveClassSound(event.className ?? '', 'chargeAttack');
      case TdSfxEventType.chainDamage:
        return resolveClassSound(event.className ?? '', 'chainDamage');
      case TdSfxEventType.dotApply:
        return resolveClassSound(event.className ?? '', 'dotApply');
      case TdSfxEventType.slowApply:
        return resolveClassSound(event.className ?? '', 'slowApply');
      case TdSfxEventType.buffApply:
        return resolveClassSound(event.className ?? '', 'buffApply');
      case TdSfxEventType.cleanseApply:
        return resolveClassSound(event.className ?? '', 'cleanseApply');

      // Dungeon sounds
      case TdSfxEventType.enemyDeath:
        return resolveDungeonSound(event.dungeonKey ?? '', 'enemyDeath');
      case TdSfxEventType.enemySpawn:
        return resolveDungeonSound(event.dungeonKey ?? '', 'enemySpawn');
      case TdSfxEventType.bossDeath:
        return resolveDungeonSound(event.dungeonKey ?? '', 'bossDeath');
      case TdSfxEventType.bossSpawn:
        return resolveDungeonSound(event.dungeonKey ?? '', 'bossSpawn');
      case TdSfxEventType.waveStart:
        return resolveDungeonSound(event.dungeonKey ?? '', 'waveStart');
      case TdSfxEventType.waveComplete:
        return resolveDungeonSound(event.dungeonKey ?? '', 'waveComplete');
      case TdSfxEventType.enemyLeak:
        return resolveDungeonSound(event.dungeonKey ?? '', 'enemyLeak');
      case TdSfxEventType.shieldBreak:
        return resolveDungeonSound(event.dungeonKey ?? '', 'shieldBreak');
      case TdSfxEventType.phaseShift:
        return resolveDungeonSound(event.dungeonKey ?? '', 'phaseShift');
      case TdSfxEventType.resurrect:
        return resolveDungeonSound(event.dungeonKey ?? '', 'resurrect');
      case TdSfxEventType.laneSwitch:
        return resolveDungeonSound(event.dungeonKey ?? '', 'laneSwitch');
      case TdSfxEventType.victory:
        return resolveDungeonSound(event.dungeonKey ?? '', 'victory');
      case TdSfxEventType.defeat:
        return resolveDungeonSound(event.dungeonKey ?? '', 'defeat');

      // Affix sounds
      case TdSfxEventType.burstingTrigger:
        return resolveAffixSound('bursting');
      case TdSfxEventType.sanguineTrigger:
        return resolveAffixSound('sanguine');
      case TdSfxEventType.bolsteringTrigger:
        return resolveAffixSound('bolstering');

      // Boss mechanic sounds
      case TdSfxEventType.fireZoneSpawn:
        return resolveBossMechanicSound('fire_zone', 'spawn');
      case TdSfxEventType.fireZoneTick:
        return resolveBossMechanicSound('fire_zone', 'tick');
      case TdSfxEventType.bossTeleport:
        return resolveBossMechanicSound('teleport_lanes', 'trigger');
      case TdSfxEventType.bossEnrage:
        return resolveBossMechanicSound('enrage', 'trigger');
      case TdSfxEventType.summonAdds:
        return resolveBossMechanicSound('summon_adds', 'trigger');
      case TdSfxEventType.reflectDamageOn:
        return resolveBossMechanicSound('reflect_damage', 'on');
      case TdSfxEventType.reflectDamageOff:
        return resolveBossMechanicSound('reflect_damage', 'off');
      case TdSfxEventType.knockbackTower:
        return resolveBossMechanicSound('knockback_tower', 'trigger');
      case TdSfxEventType.windPush:
        return resolveBossMechanicSound('wind_push', 'trigger');
      case TdSfxEventType.stackingDamageTick:
        return resolveBossMechanicSound('stacking_damage', 'tick');
      case TdSfxEventType.splitOnDeath:
        return resolveBossMechanicSound('split_on_death', 'trigger');

      // UI sounds
      case TdSfxEventType.towerPlace:
        return resolveUiSound('towerPlace', dungeonKey: event.dungeonKey);
      case TdSfxEventType.towerMove:
        return resolveUiSound('towerMove', dungeonKey: event.dungeonKey);
      case TdSfxEventType.upgradePurchase:
        return resolveUiSound('upgradePurchase', dungeonKey: event.dungeonKey);
      case TdSfxEventType.buttonTap:
        return resolveUiSound('buttonTap', dungeonKey: event.dungeonKey);
      case TdSfxEventType.gameStart:
        return resolveUiSound('gameStart', dungeonKey: event.dungeonKey);
      case TdSfxEventType.nextWave:
        return resolveUiSound('nextWave', dungeonKey: event.dungeonKey);
      case TdSfxEventType.rouletteTick:
        return resolveUiSound('rouletteTick', dungeonKey: event.dungeonKey);
      case TdSfxEventType.rouletteReveal:
        return resolveUiSound('rouletteReveal', dungeonKey: event.dungeonKey);
      case TdSfxEventType.compSelect:
        return resolveUiSound('compSelect', dungeonKey: event.dungeonKey);
      case TdSfxEventType.compDeselect:
        return resolveUiSound('compDeselect', dungeonKey: event.dungeonKey);
      case TdSfxEventType.keystoneInsert:
        return resolveUiSound('keystoneInsert', dungeonKey: event.dungeonKey);

      // Dungeon (additional)
      case TdSfxEventType.sanguineHeal:
        return resolveDungeonSound(event.dungeonKey ?? '', 'sanguineHeal');
      case TdSfxEventType.enemyAccelerate:
        return resolveDungeonSound(event.dungeonKey ?? '', 'enemyAccelerate');

      // Combat (additional)
      case TdSfxEventType.chargeRelease:
        return resolveClassSound(event.className ?? '', 'chargeRelease');
    }
  }
}
