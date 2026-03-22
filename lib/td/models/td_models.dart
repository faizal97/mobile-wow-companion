import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/character.dart';
import '../../theme/wow_class_colors.dart';
import '../data/effect_types.dart';
import '../data/td_balance_config.dart';
import '../effects/tower_effects.dart';

// ---------------------------------------------------------------------------
// TdTower — a WoW character placed in a lane
// ---------------------------------------------------------------------------

/// A tower is a WoW character placed in a lane. Its stats are derived from
/// the character's class definition and item level.
class TdTower {
  final WowCharacter character;
  final TdClassDef classDef;
  int laneIndex;

  /// Position slot within the lane: 0=front (near spawn), 1=mid, 2=back (near goal).
  /// -1 means unassigned.
  int slotIndex;

  /// Slot positions along the lane (0.0=spawn, 1.0=goal).
  static const List<double> slotPositions = [0.25, 0.55, 0.85];

  /// The tower's position along the lane based on its slot.
  double get slotPosition =>
      slotIndex >= 0 && slotIndex < slotPositions.length
          ? slotPositions[slotIndex]
          : 0.85; // default to back if unassigned

  // Derived from classDef
  TowerArchetype get archetype => classDef.archetype;
  Color get color => WowClassColors.forClass(character.characterClass);
  Color get attackColor => classDef.attackColor;
  String get passiveName => classDef.passive.name;
  String get passiveDescription => classDef.passive.description;

  /// Derived from [character.equippedItemLevel] (defaults to 600).
  final double baseDamage;

  // Mutable combat state

  /// Whether the tower is currently debuffed (e.g. by Bursting).
  bool isDebuffed = false;

  /// Remaining debuff duration in seconds.
  double debuffTimer = 0;

  /// Total attacks this tower has made (for on_nth_attack tracking).
  int attackCount = 0;

  /// Seconds elapsed since last charge began (for charge_attack effect).
  double chargeTimer = 0;

  TdTower({
    required this.character,
    required this.classDef,
    required this.laneIndex,
    this.slotIndex = -1,
  }) : baseDamage = _normalizedDamage(character.equippedItemLevel);

  /// Normalize ilvl to a consistent damage value regardless of stat squish.
  /// Pre-Midnight ilvl ~560-640 and post-Midnight ilvl ~80-120 both map
  /// to a 40-70 damage range. Higher ilvl = more damage within the range.
  static double _normalizedDamage(int? ilvl) {
    final raw = ilvl ?? 100;
    if (raw > 300) {
      // Pre-squish: 560-640 maps to 40-70
      return 40 + ((raw - 500).clamp(0, 200) / 200) * 30;
    } else {
      // Post-squish (Midnight): 80-120 maps to 40-70
      return 40 + ((raw - 60).clamp(0, 80) / 80) * 30;
    }
  }

  /// Returns half damage when debuffed.
  double get effectiveDamage => isDebuffed ? baseDamage / 2 : baseDamage;

  /// Seconds between attacks — varies by archetype, modified by passive effects.
  /// Uses values from [TdBalanceConfig] if provided.
  double attackIntervalWith(TdBalanceConfig config) {
    double base;
    switch (archetype) {
      case TowerArchetype.melee:
        base = config.meleeAttackInterval;
      case TowerArchetype.ranged:
        base = config.rangedAttackInterval;
      case TowerArchetype.support:
        base = config.supportAttackInterval;
      case TowerArchetype.aoe:
        base = config.aoeAttackInterval;
    }
    for (final effect in classDef.passive.effects) {
      if (effect.type == 'attack_speed_multiplier') {
        base *= effect.value;
      }
    }
    return base;
  }

  /// Convenience getter using default config.
  double get attackInterval => attackIntervalWith(TdBalanceConfig.defaults);

  /// Check if this tower is immune to a specific affix.
  bool isImmuneToAffix(String affixName) {
    for (final effect in classDef.passive.effects) {
      // immune_to_debuff = immune to ALL tower debuffs (Paladin)
      if (effect.type == 'immune_to_debuff') return true;
      if (effect.type == 'immune_to_affix' &&
          effect.params['affix'] == affixName) {
        return true;
      }
    }
    return false;
  }

  /// Check if this tower is immune to all debuffs (e.g. Paladin).
  bool get isImmuneToDebuff {
    for (final effect in classDef.passive.effects) {
      if (effect.type == 'immune_to_debuff') return true;
    }
    return false;
  }
}

// ---------------------------------------------------------------------------
// TdEnemy — an enemy moving across a lane
// ---------------------------------------------------------------------------

/// An enemy that spawns at position 0.0 and moves toward 1.0 (the goal).
class TdEnemy {
  final String id;
  final double maxHp;
  double hp;

  /// Progress along the lane: 0.0 = spawn, 1.0 = goal reached.
  double position;

  /// Movement speed in position-units per second.
  final double speed;

  /// The lane this enemy is in. Mutable because lane_switch modifier can
  /// change it mid-run.
  int laneIndex;

  final bool isBoss;

  /// Multiplier applied to [speed] (e.g. by affixes).
  double speedMultiplier;

  // Effect system additions

  /// Modifiers from dungeon definition (e.g. shield, phase, lane_switch).
  final List<EffectDef> modifiers;

  /// Mutable state for modifiers (e.g. shield_hits, phase_invuln).
  final Map<String, dynamic> modifierState;

  /// Active slows, dots, and other debuffs on this enemy.
  List<EnemyStatusEffect> statusEffects;

  TdEnemy({
    required this.id,
    required this.maxHp,
    required this.speed,
    required this.laneIndex,
    this.isBoss = false,
    this.speedMultiplier = 1.0,
    this.modifiers = const [],
    Map<String, dynamic>? modifierState,
  })  : hp = maxHp,
        position = 0.0,
        modifierState = modifierState ?? {},
        statusEffects = [];

  bool get isDead => hp <= 0;
  bool get reachedEnd => position >= 1.0;
  double get hpFraction => (hp / maxHp).clamp(0, 1);

  /// Whether the enemy is currently invulnerable (phase modifier).
  bool get isInvulnerable => modifierState['phase_invuln'] == true;

  /// Remaining shield hits (shield modifier).
  int get shieldHits => (modifierState['shield_hits'] as int?) ?? 0;
}

// ---------------------------------------------------------------------------
// SanguinePool — heal zone left behind by a dying enemy
// ---------------------------------------------------------------------------

/// A healing pool dropped by the Sanguine affix. Heals nearby enemies until
/// the timer expires.
class SanguinePool {
  final int laneIndex;
  final double position;

  /// Time remaining in seconds before the pool disappears.
  double timer;

  SanguinePool({
    required this.laneIndex,
    required this.position,
    this.timer = 4.0,
  });

  bool get isExpired => timer <= 0;
}

// ---------------------------------------------------------------------------
// TdHitEvent — visual hit event for rendering
// ---------------------------------------------------------------------------

/// A visual hit event emitted when a tower attacks an enemy.
class TdHitEvent {
  final int towerLane;
  final double towerX; // 0.0–1.0 normalized position
  final String enemyId;
  final int enemyLane;
  final double enemyX;
  final double damage;
  final bool isAoe;
  final TowerArchetype archetype; // for per-archetype visual
  final Color attackColor; // class-colored attack
  final bool isCrit; // for crit visual
  double age; // seconds since creation

  TdHitEvent({
    required this.towerLane,
    required this.towerX,
    required this.enemyId,
    required this.enemyLane,
    required this.enemyX,
    required this.damage,
    this.isAoe = false,
    this.archetype = TowerArchetype.melee,
    this.attackColor = const Color(0xFFFFD700),
    this.isCrit = false,
    this.age = 0,
  });

  /// How long the particle lives (seconds).
  static const double lifetime = 0.4;
  bool get isExpired => age >= lifetime;

  /// 0.0 → 1.0 progress through the animation.
  double get progress => (age / lifetime).clamp(0, 1);
}

// ---------------------------------------------------------------------------
// TdAffix — Mythic+ affixes that modify gameplay
// ---------------------------------------------------------------------------

/// Mythic+ affixes that alter tower-defense gameplay.
enum TdAffix { fortified, tyrannical, bolstering, bursting, sanguine }

// ---------------------------------------------------------------------------
// FireZone — fire_zone boss mechanic
// ---------------------------------------------------------------------------

/// A fire zone spawned by a boss ability. Damages towers in the lane until
/// the timer expires.
class FireZone {
  final int laneIndex;
  double timer;

  FireZone({required this.laneIndex, required this.timer});

  bool get isExpired => timer <= 0;
}

// ---------------------------------------------------------------------------
// KeystoneRun — configuration for a single run
// ---------------------------------------------------------------------------

/// Describes the parameters of a keystone run: level, affixes, and dungeon.
class KeystoneRun {
  final int level;
  final List<TdAffix> affixes;
  final TdDungeonDef dungeon;

  String get dungeonName => dungeon.name;

  const KeystoneRun({
    required this.level,
    required this.affixes,
    required this.dungeon,
  });

  /// Enemy HP multiplier based on keystone level.
  /// Uses config for scaling coefficients.
  double hpMultiplierWith(TdBalanceConfig config) {
    if (level <= config.linearPhaseEnd) {
      return 1.0 + (level - 2) * config.linearRate;
    }
    final over = level - config.linearPhaseEnd;
    return config.exponentialBase + over * config.exponentialLinear + over * over * config.exponentialQuadratic;
  }

  /// Convenience getter using default config.
  double get hpMultiplier => hpMultiplierWith(TdBalanceConfig.defaults);

  bool get hasFortified => affixes.contains(TdAffix.fortified);
  bool get hasTyrannical => affixes.contains(TdAffix.tyrannical);
  bool get hasBolstering => affixes.contains(TdAffix.bolstering);
  bool get hasBursting => affixes.contains(TdAffix.bursting);
  bool get hasSanguine => affixes.contains(TdAffix.sanguine);

  /// Generates a random keystone run for the given [level] and [dungeon].
  static KeystoneRun generate(int level, {
    required TdDungeonDef dungeon,
    TdBalanceConfig config = TdBalanceConfig.defaults,
  }) {
    final rng = Random();
    final allAffixes = List<TdAffix>.from(TdAffix.values)..shuffle(rng);
    final count = level >= config.threeAffixLevel
        ? 3
        : level >= config.twoAffixLevel
            ? 2
            : level >= config.oneAffixLevel
                ? 1
                : 0;
    return KeystoneRun(
      level: level,
      affixes: allAffixes.take(count).toList(),
      dungeon: dungeon,
    );
  }
}
