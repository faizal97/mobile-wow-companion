import 'dart:math';

import '../data/effect_types.dart';
import '../models/td_models.dart';
import 'tower_effects.dart';

// ---------------------------------------------------------------------------
// AbilityResult — outcome of executing an ability
// ---------------------------------------------------------------------------

class AbilityResult {
  final List<TowerHit> hits;
  final List<EnemyStatusEffect> statusEffects;
  final List<TowerAbilityBuff> towerBuffs;
  final List<TowerAbilityBuff> allTowerBuffs; // applied to ALL towers
  final List<SummonedPet> summonedPets;
  final List<String> killedEnemyIds;
  final Map<String, double> enemyPositionResets; // enemyId -> new position
  final List<LaneBlock> laneBlocks;
  final List<BurnZone> burnZones;
  final List<int> stunnedLanes; // lanes where enemies are stunned
  final double stunDuration;
  final bool reduceCooldowns;
  final double cooldownReductionPct;
  final bool isChanneled;
  final double channelDuration;
  final int channelHits;
  final double channelDamagePerHit;
  final bool immuneDuringChannel;
  final bool applyStealthToTower;
  final double stealthDuration;
  final double? empowerNextAttackMult;
  final double? empowerNextAttackStun;
  // Shapeshift
  final String? shapeshiftForm;
  final double shapeshiftDuration;
  // Transform (Voidform)
  final bool isTransform;
  final String? transformArchetype;
  final String? transformTargeting;
  final double transformDuration;
  final double stackingDamagePerHit;
  // Random cast (Convoke)
  final bool isRandomCast;
  final int randomCastCount;
  final double randomCastInterval;
  // Combo points (Shadow Blades)
  final bool enableComboPoints;
  final int comboThreshold;
  final double comboFinisherMult;

  const AbilityResult({
    this.hits = const [],
    this.statusEffects = const [],
    this.towerBuffs = const [],
    this.allTowerBuffs = const [],
    this.summonedPets = const [],
    this.killedEnemyIds = const [],
    this.enemyPositionResets = const {},
    this.laneBlocks = const [],
    this.burnZones = const [],
    this.stunnedLanes = const [],
    this.stunDuration = 0,
    this.reduceCooldowns = false,
    this.cooldownReductionPct = 0,
    this.isChanneled = false,
    this.channelDuration = 0,
    this.channelHits = 0,
    this.channelDamagePerHit = 0,
    this.immuneDuringChannel = false,
    this.applyStealthToTower = false,
    this.stealthDuration = 0,
    this.empowerNextAttackMult,
    this.empowerNextAttackStun,
    this.shapeshiftForm,
    this.shapeshiftDuration = 0,
    this.isTransform = false,
    this.transformArchetype,
    this.transformTargeting,
    this.transformDuration = 0,
    this.stackingDamagePerHit = 0,
    this.isRandomCast = false,
    this.randomCastCount = 0,
    this.randomCastInterval = 0,
    this.enableComboPoints = false,
    this.comboThreshold = 5,
    this.comboFinisherMult = 6.0,
  });
}

// ---------------------------------------------------------------------------
// AbilityEffectProcessor — processes ability effects
// ---------------------------------------------------------------------------

class AbilityEffectProcessor {
  /// Execute an ability's effects and return the combined result.
  static AbilityResult execute({
    required AbilityDef ability,
    required TdTower caster,
    required List<TdEnemy> allEnemies,
    required List<TdTower> allTowers,
    required double baseDamage,
    String? targetEnemyId,
    int? targetLane,
    int? targetTowerIndex,
    required Random rng,
  }) {
    final hits = <TowerHit>[];
    final statusEffects = <EnemyStatusEffect>[];
    final towerBuffs = <TowerAbilityBuff>[];
    final allTowerBuffs = <TowerAbilityBuff>[];
    final pets = <SummonedPet>[];
    final killedIds = <String>[];
    final posResets = <String, double>{};
    final laneBlocks = <LaneBlock>[];
    final burnZones = <BurnZone>[];
    final stunnedLanes = <int>[];
    double stunDuration = 0;
    bool reduceCooldowns = false;
    double cooldownReductionPct = 0;
    bool isChanneled = false;
    double channelDuration = 0;
    int channelHits = 0;
    double channelDamagePerHit = 0;
    bool immuneDuringChannel = false;
    bool applyStealthToTower = false;
    double stealthDuration = 0;
    double? empowerNextAttackMult;
    double? empowerNextAttackStun;
    String? shapeshiftForm;
    double shapeshiftDuration = 0;
    bool isTransform = false;
    String? transformArchetype;
    String? transformTargeting;
    double transformDuration = 0;
    double stackingDamagePerHit = 0;
    bool isRandomCast = false;
    int randomCastCount = 0;
    double randomCastInterval = 0;
    bool enableComboPoints = false;
    int comboThreshold = 5;
    double comboFinisherMult = 6.0;

    final liveEnemies =
        allEnemies.where((e) => !e.isDead && e.position >= 0).toList();

    for (final effect in ability.effects) {
      switch (effect.type) {
        // -- Damage effects --
        case 'damage_multiplier':
          if (ability.duration > 0 && targetEnemyId == null && targetLane == null) {
            // Duration-based buff (Metamorphosis, Shadow Blades)
            towerBuffs.add(TowerAbilityBuff(
              type: 'damage_multiplier',
              value: (effect.params['value'] as num?)?.toDouble() ?? 1.5,
              remaining: ability.duration,
            ));
          } else {
            // Instant damage multiplier (Execute, Aimed Shot, etc.)
            _processDamageMultiplier(
              effect, caster, baseDamage, liveEnemies, targetEnemyId,
              targetLane, hits, killedIds,
            );
          }

        case 'instant_kill':
          _processInstantKill(
            effect, liveEnemies, targetEnemyId, killedIds,
          );

        case 'percent_hp_damage':
          _processPercentHpDamage(
            effect, liveEnemies, targetEnemyId, hits,
          );

        case 'damage_all_lanes':
          _processDamageAllLanes(
            effect, baseDamage, liveEnemies, caster, hits,
          );

        case 'damage_lane':
          final lane = targetLane ?? caster.laneIndex;
          _processDamageLane(
            effect, baseDamage, liveEnemies, lane, caster, hits,
          );

        // -- Positional effects --
        case 'pull_to_start':
          if (targetEnemyId != null) {
            posResets[targetEnemyId] = 0.0;
          }

        case 'knockback':
          final lane = targetLane ?? caster.laneIndex;
          final amount = (effect.params['value'] as num?)?.toDouble() ?? 0.3;
          for (final e in liveEnemies) {
            if (e.laneIndex == lane) {
              posResets[e.id] = (e.position - amount).clamp(0.0, 1.0);
            }
          }

        case 'block_lane':
          final lane = targetLane ?? caster.laneIndex;
          final dur = (effect.params['duration'] as num?)?.toDouble() ??
              ability.duration;
          laneBlocks.add(LaneBlock(laneIndex: lane, remaining: dur));

        case 'stun_enemies':
          final lane = targetLane ?? caster.laneIndex;
          final dur = (effect.params['duration'] as num?)?.toDouble() ?? 2.0;
          stunnedLanes.add(lane);
          stunDuration = dur;

        // -- Tower buff effects --
        case 'buff_tower':
          final buffType = effect.params['buff'] as String? ?? 'damage_multiplier';
          final val = (effect.params['value'] as num?)?.toDouble() ?? 1.0;
          final dur = (effect.params['duration'] as num?)?.toDouble() ??
              ability.duration;
          towerBuffs.add(TowerAbilityBuff(
            type: buffType,
            value: val,
            remaining: dur,
          ));

        case 'buff_all_towers':
          final buffType = effect.params['buff'] as String? ?? 'damage_multiplier';
          final val = (effect.params['value'] as num?)?.toDouble() ?? 1.0;
          final dur = (effect.params['duration'] as num?)?.toDouble() ??
              ability.duration;
          allTowerBuffs.add(TowerAbilityBuff(
            type: buffType,
            value: val,
            remaining: dur,
          ));

        // -- Summoned pets --
        case 'summon_pet':
          final petTargeting =
              effect.params['targeting'] as String? ?? 'furthest_any_lane';
          final interval =
              (effect.params['attack_interval'] as num?)?.toDouble() ?? 0.5;
          final dmgMult =
              (effect.params['damage_multiplier'] as num?)?.toDouble() ?? 1.0;
          final dur = (effect.params['duration'] as num?)?.toDouble() ??
              ability.duration;
          final towerIdx = allTowers.indexOf(caster);
          pets.add(SummonedPet(
            ownerTowerIndex: towerIdx >= 0 ? towerIdx : 0,
            targeting: petTargeting,
            attackInterval: interval,
            damageMultiplier: dmgMult,
            baseDamage: baseDamage,
            remaining: dur,
            laneIndex: targetLane,
          ));

        // -- Status effects on enemies --
        case 'slow_enemy':
          final slowVal = (effect.params['value'] as num?)?.toDouble() ?? 0.3;
          final dur = (effect.params['duration'] as num?)?.toDouble() ?? 4.0;
          final lane = targetLane ?? caster.laneIndex;
          for (final e in liveEnemies) {
            if (e.laneIndex == lane) {
              statusEffects.add(EnemyStatusEffect(
                type: 'slow',
                sourceId: e.id,
                params: {'value': slowVal},
                remaining: dur,
              ));
            }
          }

        case 'dot':
          final dotVal = (effect.params['value'] as num?)?.toDouble() ?? 0.15;
          final dur = (effect.params['duration'] as num?)?.toDouble() ?? 3.0;
          final ticks = (effect.params['ticks'] as num?)?.toInt() ?? 3;
          final lane = targetLane ?? caster.laneIndex;
          final tickInterval = dur / ticks;
          final dotDamage = baseDamage * dotVal;
          for (final e in liveEnemies) {
            if (e.laneIndex == lane) {
              statusEffects.add(EnemyStatusEffect(
                type: 'dot',
                sourceId: e.id,
                params: {
                  'dotDamage': dotDamage,
                  'tickInterval': tickInterval,
                },
                remaining: dur,
              ));
            }
          }

        case 'dot_spread':
          // Handled at game state level (spread existing DoTs)
          break;

        // -- Crit effects --
        case 'guaranteed_crit':
          final mult =
              (effect.params['multiplier'] as num?)?.toDouble() ?? 2.5;
          final dur = ability.duration > 0 ? ability.duration : 0.1;
          if (ability.duration > 0) {
            // Duration-based guaranteed crit buff (Combustion)
            towerBuffs.add(TowerAbilityBuff(
              type: 'guaranteed_crit',
              value: mult,
              remaining: dur,
            ));
          }
          // For single-use (Chaos Bolt, Lava Burst), crit is applied as damage mult
          if (ability.duration <= 0) {
            // Apply crit to the hits already calculated for this ability
            for (var i = 0; i < hits.length; i++) {
              hits[i] = TowerHit(
                enemyId: hits[i].enemyId,
                damage: hits[i].damage * mult,
                enemyLane: hits[i].enemyLane,
                enemyPosition: hits[i].enemyPosition,
              );
            }
          }

        case 'splash_damage':
          final dur = ability.duration > 0 ? ability.duration : 0.1;
          towerBuffs.add(TowerAbilityBuff(
            type: 'splash_damage',
            value: (effect.params['splash_pct'] as num?)?.toDouble() ?? 0.5,
            remaining: dur,
          ));

        case 'ignore_modifiers':
          // Handled at the game state level when applying damage
          break;

        // -- Tower state effects --
        case 'stealth':
          applyStealthToTower = true;
          stealthDuration =
              (effect.params['duration'] as num?)?.toDouble() ?? 3.0;

        case 'empower_next_attack':
          empowerNextAttackMult =
              (effect.params['damage_multiplier'] as num?)?.toDouble() ?? 4.0;
          empowerNextAttackStun =
              (effect.params['apply_stun'] as num?)?.toDouble();

        case 'channel_attack':
          isChanneled = true;
          channelDuration =
              (effect.params['duration'] as num?)?.toDouble() ?? 3.0;
          channelHits = (effect.params['hits'] as num?)?.toInt() ?? 5;
          channelDamagePerHit =
              (effect.params['damage_per_hit'] as num?)?.toDouble() ?? 0.6;
          immuneDuringChannel =
              effect.params['immune_during'] as bool? ?? false;

        // -- Duration-based buffs (applied to caster) --
        case 'attack_speed_multiplier':
          towerBuffs.add(TowerAbilityBuff(
            type: 'attack_speed_multiplier',
            value: (effect.params['value'] as num?)?.toDouble() ?? 0.667,
            remaining: ability.duration,
          ));

        case 'cross_lane_attack':
          towerBuffs.add(TowerAbilityBuff(
            type: 'cross_lane_attack',
            value: (effect.params['value'] as num?)?.toDouble() ?? 99,
            remaining: ability.duration,
          ));

        // -- Burn zones --
        case 'burn_zone':
          final lane = targetLane ?? caster.laneIndex;
          burnZones.add(BurnZone(
            laneIndex: lane,
            damagePerTick:
                baseDamage * ((effect.params['damage_per_tick'] as num?)?.toDouble() ?? 0.3),
            tickInterval:
                (effect.params['tick_interval'] as num?)?.toDouble() ?? 1.0,
            remaining:
                (effect.params['duration'] as num?)?.toDouble() ?? 4.0,
          ));

        // -- Cooldown reduction --
        case 'reduce_all_cooldowns':
          reduceCooldowns = true;
          cooldownReductionPct =
              (effect.params['reduction_pct'] as num?)?.toDouble() ?? 0.5;

        // -- Shapeshift --
        case 'shapeshift':
          // Pick cat form by default for auto-cast (more offensive)
          shapeshiftForm = 'cat';
          shapeshiftDuration =
              (effect.params['revert_after'] as num?)?.toDouble() ??
              ability.duration;

        // -- Transform (Voidform) --
        case 'transform':
          isTransform = true;
          transformArchetype =
              effect.params['archetype'] as String? ?? 'ranged';
          transformTargeting =
              effect.params['targeting'] as String?;
          transformDuration = ability.duration;
          stackingDamagePerHit =
              (effect.params['stacking_damage_per_hit'] as num?)?.toDouble() ??
              0;

        // -- Random cast (Convoke) --
        case 'random_cast':
          isRandomCast = true;
          randomCastCount =
              (effect.params['count'] as num?)?.toInt() ?? 16;
          randomCastInterval =
              (effect.params['interval'] as num?)?.toDouble() ?? 0.25;

        // -- Combo points (Shadow Blades) --
        case 'combo_points':
          enableComboPoints = true;
          comboThreshold =
              (effect.params['threshold'] as num?)?.toInt() ?? 5;
          comboFinisherMult =
              (effect.params['finisher_damage_multiplier'] as num?)
                  ?.toDouble() ??
              6.0;

        default:
          // Unknown effect type — skip silently
          break;
      }
    }

    return AbilityResult(
      hits: hits,
      statusEffects: statusEffects,
      towerBuffs: towerBuffs,
      allTowerBuffs: allTowerBuffs,
      summonedPets: pets,
      killedEnemyIds: killedIds,
      enemyPositionResets: posResets,
      laneBlocks: laneBlocks,
      burnZones: burnZones,
      stunnedLanes: stunnedLanes,
      stunDuration: stunDuration,
      reduceCooldowns: reduceCooldowns,
      cooldownReductionPct: cooldownReductionPct,
      isChanneled: isChanneled,
      channelDuration: channelDuration,
      channelHits: channelHits,
      channelDamagePerHit: channelDamagePerHit,
      immuneDuringChannel: immuneDuringChannel,
      applyStealthToTower: applyStealthToTower,
      stealthDuration: stealthDuration,
      empowerNextAttackMult: empowerNextAttackMult,
      empowerNextAttackStun: empowerNextAttackStun,
      shapeshiftForm: shapeshiftForm,
      shapeshiftDuration: shapeshiftDuration,
      isTransform: isTransform,
      transformArchetype: transformArchetype,
      transformTargeting: transformTargeting,
      transformDuration: transformDuration,
      stackingDamagePerHit: stackingDamagePerHit,
      isRandomCast: isRandomCast,
      randomCastCount: randomCastCount,
      randomCastInterval: randomCastInterval,
      enableComboPoints: enableComboPoints,
      comboThreshold: comboThreshold,
      comboFinisherMult: comboFinisherMult,
    );
  }

  // -------------------------------------------------------------------------
  // Damage multiplier (Execute, Aimed Shot, etc.)
  // -------------------------------------------------------------------------

  static void _processDamageMultiplier(
    EffectDef effect,
    TdTower caster,
    double baseDamage,
    List<TdEnemy> enemies,
    String? targetEnemyId,
    int? targetLane,
    List<TowerHit> hits,
    List<String> killedIds,
  ) {
    final mult = (effect.params['value'] as num?)?.toDouble() ?? 1.0;
    final condition = effect.params['condition'] as Map<String, dynamic>?;

    // Single target
    if (targetEnemyId != null) {
      final enemy =
          enemies.where((e) => e.id == targetEnemyId).firstOrNull;
      if (enemy == null) return;

      if (condition != null) {
        final hpThreshold =
            (condition['target_hp_below_pct'] as num?)?.toDouble();
        if (hpThreshold != null && enemy.hpFraction > hpThreshold) return;
      }

      // Check value_if_dotted (Lava Burst)
      var finalMult = mult;
      final dottedMult = (effect.params['value_if_dotted'] as num?)?.toDouble();
      if (dottedMult != null && enemy.statusEffects.any((s) => s.type == 'dot')) {
        finalMult = dottedMult;
      }

      hits.add(TowerHit(
        enemyId: enemy.id,
        damage: baseDamage * finalMult,
        enemyLane: enemy.laneIndex,
        enemyPosition: enemy.position,
      ));
    }
  }

  // -------------------------------------------------------------------------
  // Instant kill (Execute <10%, Touch of Death)
  // -------------------------------------------------------------------------

  static void _processInstantKill(
    EffectDef effect,
    List<TdEnemy> enemies,
    String? targetEnemyId,
    List<String> killedIds,
  ) {
    final condition = effect.params['condition'] as Map<String, dynamic>?;

    if (targetEnemyId != null) {
      final enemy =
          enemies.where((e) => e.id == targetEnemyId).firstOrNull;
      if (enemy == null) return;

      if (condition != null) {
        if (condition['not_boss'] == true && enemy.isBoss) return;
        final hpThreshold =
            (condition['target_hp_below_pct'] as num?)?.toDouble();
        if (hpThreshold != null && enemy.hpFraction > hpThreshold) return;
      }

      killedIds.add(enemy.id);
    }
  }

  // -------------------------------------------------------------------------
  // Percent HP damage (Touch of Death vs bosses)
  // -------------------------------------------------------------------------

  static void _processPercentHpDamage(
    EffectDef effect,
    List<TdEnemy> enemies,
    String? targetEnemyId,
    List<TowerHit> hits,
  ) {
    final pct = (effect.params['value'] as num?)?.toDouble() ?? 0.3;
    final condition = effect.params['condition'] as Map<String, dynamic>?;

    if (targetEnemyId != null) {
      final enemy =
          enemies.where((e) => e.id == targetEnemyId).firstOrNull;
      if (enemy == null) return;

      if (condition != null) {
        if (condition['is_boss'] == true && !enemy.isBoss) return;
      }

      hits.add(TowerHit(
        enemyId: enemy.id,
        damage: enemy.maxHp * pct,
        enemyLane: enemy.laneIndex,
        enemyPosition: enemy.position,
      ));
    }
  }

  // -------------------------------------------------------------------------
  // Damage all lanes (Bladestorm)
  // -------------------------------------------------------------------------

  static void _processDamageAllLanes(
    EffectDef effect,
    double baseDamage,
    List<TdEnemy> enemies,
    TdTower caster,
    List<TowerHit> hits,
  ) {
    final mult =
        (effect.params['damage_multiplier'] as num?)?.toDouble() ?? 1.5;
    final damage = baseDamage * mult;

    for (final e in enemies) {
      hits.add(TowerHit(
        enemyId: e.id,
        damage: damage,
        enemyLane: e.laneIndex,
        enemyPosition: e.position,
      ));
    }
  }

  // -------------------------------------------------------------------------
  // Damage lane (Eye Beam, Meteor, Fire Breath, Deep Breath)
  // -------------------------------------------------------------------------

  static void _processDamageLane(
    EffectDef effect,
    double baseDamage,
    List<TdEnemy> enemies,
    int lane,
    TdTower caster,
    List<TowerHit> hits,
  ) {
    var mult = (effect.params['damage_multiplier'] as num?)?.toDouble() ?? 1.0;

    // Fire Breath: scale with charge
    if (effect.params['damage_multiplier_from_charge'] == true) {
      final minMult =
          (effect.params['min_multiplier'] as num?)?.toDouble() ?? 1.0;
      final maxMult =
          (effect.params['max_multiplier'] as num?)?.toDouble() ?? 3.0;
      // chargeTimer is 0-3s for Evoker with 3s charge time
      final chargeTime = caster.classDef.passive.effects
          .where((e) => e.type == 'charge_attack')
          .map((e) => (e.params['chargeTime'] as num?)?.toDouble() ?? 3.0)
          .firstOrNull ?? 3.0;
      final chargePct = (caster.chargeTimer / chargeTime).clamp(0.0, 1.0);
      mult = minMult + (maxMult - minMult) * chargePct;
    }

    final damage = baseDamage * mult;
    for (final e in enemies) {
      if (e.laneIndex == lane) {
        hits.add(TowerHit(
          enemyId: e.id,
          damage: damage,
          enemyLane: e.laneIndex,
          enemyPosition: e.position,
        ));
      }
    }
  }
}
