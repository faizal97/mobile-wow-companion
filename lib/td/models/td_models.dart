import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/character.dart';
import '../../theme/wow_class_colors.dart';

// ---------------------------------------------------------------------------
// Tower Archetype
// ---------------------------------------------------------------------------

/// Determines a tower's attack style based on the WoW class it represents.
enum TowerArchetype { melee, ranged, healer, aoe }

/// Maps a WoW class name to its tower archetype.
TowerArchetype archetypeForClass(String characterClass) {
  switch (characterClass.toLowerCase()) {
    case 'warrior':
    case 'rogue':
    case 'death knight':
    case 'paladin':
    case 'monk':
    case 'demon hunter':
      return TowerArchetype.melee;
    case 'mage':
    case 'hunter':
    case 'warlock':
    case 'evoker':
      return TowerArchetype.ranged;
    case 'priest':
    case 'druid':
      return TowerArchetype.healer;
    case 'shaman':
      return TowerArchetype.aoe;
    default:
      return TowerArchetype.melee;
  }
}

// ---------------------------------------------------------------------------
// TdTower — a WoW character placed in a lane
// ---------------------------------------------------------------------------

/// A tower is a WoW character placed in a lane. Its stats are derived from
/// the character's class and item level.
class TdTower {
  final WowCharacter character;
  final int laneIndex;

  /// Derived from [character.characterClass].
  final TowerArchetype archetype;

  /// Derived from [character.equippedItemLevel] (defaults to 600).
  final double baseDamage;

  /// Derived from [WowClassColors.forClass].
  final Color color;

  /// Whether the tower is currently debuffed (e.g. by Bursting).
  bool isDebuffed = false;

  /// Remaining debuff duration in seconds.
  double debuffTimer = 0;

  TdTower({required this.character, required this.laneIndex})
      : archetype = archetypeForClass(character.characterClass),
        baseDamage = (character.equippedItemLevel ?? 600) / 10.0,
        color = WowClassColors.forClass(character.characterClass);

  /// Returns half damage when debuffed.
  double get effectiveDamage => isDebuffed ? baseDamage / 2 : baseDamage;

  /// Seconds between attacks — varies by archetype.
  double get attackInterval {
    switch (archetype) {
      case TowerArchetype.melee:
        return 0.8;
      case TowerArchetype.ranged:
        return 1.2;
      case TowerArchetype.healer:
        return 2.0;
      case TowerArchetype.aoe:
        return 1.5;
    }
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

  final int laneIndex;
  final bool isBoss;

  /// Multiplier applied to [speed] (e.g. by affixes).
  double speedMultiplier;

  TdEnemy({
    required this.id,
    required this.maxHp,
    required this.speed,
    required this.laneIndex,
    this.isBoss = false,
    this.speedMultiplier = 1.0,
  })  : hp = maxHp,
        position = 0.0;

  bool get isDead => hp <= 0;
  bool get reachedEnd => position >= 1.0;
  double get hpFraction => hp / maxHp;
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
// TdAffix — Mythic+ affixes that modify gameplay
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
  double age; // seconds since creation

  TdHitEvent({
    required this.towerLane,
    required this.towerX,
    required this.enemyId,
    required this.enemyLane,
    required this.enemyX,
    required this.damage,
    this.isAoe = false,
    this.age = 0,
  });

  /// How long the particle lives (seconds).
  static const double lifetime = 0.4;
  bool get isExpired => age >= lifetime;
  /// 0.0 → 1.0 progress through the animation.
  double get progress => (age / lifetime).clamp(0, 1);
}

/// Mythic+ affixes that alter tower-defense gameplay.
enum TdAffix { fortified, tyrannical, bolstering, bursting, sanguine }

// ---------------------------------------------------------------------------
// TdDungeon — dungeon definitions with themed enemy visuals
// ---------------------------------------------------------------------------

/// A dungeon available for tower defense runs.
class TdDungeon {
  final String name;
  final String shortName;
  final Color enemyColor;
  final Color bossColor;
  final IconData enemyIcon;
  final IconData bossIcon;

  const TdDungeon({
    required this.name,
    required this.shortName,
    required this.enemyColor,
    required this.bossColor,
    required this.enemyIcon,
    required this.bossIcon,
  });

  static const List<TdDungeon> all = [
    TdDungeon(
      name: 'Stonevault',
      shortName: 'SV',
      enemyColor: Color(0xFF8B7355), // earthy brown — kobolds/earthen
      bossColor: Color(0xFFFF8000),
      enemyIcon: Icons.terrain_rounded,
      bossIcon: Icons.local_fire_department,
    ),
    TdDungeon(
      name: 'City of Threads',
      shortName: 'CoT',
      enemyColor: Color(0xFF7B68EE), // nerubian purple
      bossColor: Color(0xFFA335EE),
      enemyIcon: Icons.bug_report_rounded,
      bossIcon: Icons.pest_control_rounded,
    ),
    TdDungeon(
      name: 'The Dawnbreaker',
      shortName: 'DB',
      enemyColor: Color(0xFF4169E1), // void blue
      bossColor: Color(0xFF6A0DAD),
      enemyIcon: Icons.dark_mode_rounded,
      bossIcon: Icons.auto_awesome_rounded,
    ),
    TdDungeon(
      name: 'Ara-Kara',
      shortName: 'AK',
      enemyColor: Color(0xFF2E8B57), // swamp green — spiders
      bossColor: Color(0xFF006400),
      enemyIcon: Icons.coronavirus_rounded,
      bossIcon: Icons.pest_control_rounded,
    ),
    TdDungeon(
      name: 'Cinderbrew Meadery',
      shortName: 'CM',
      enemyColor: Color(0xFFCD853F), // amber brew
      bossColor: Color(0xFFB22222),
      enemyIcon: Icons.local_bar_rounded,
      bossIcon: Icons.whatshot_rounded,
    ),
    TdDungeon(
      name: 'Darkflame Cleft',
      shortName: 'DC',
      enemyColor: Color(0xFFB22222), // dark flame red
      bossColor: Color(0xFFFF4500),
      enemyIcon: Icons.whatshot_rounded,
      bossIcon: Icons.local_fire_department,
    ),
    TdDungeon(
      name: 'The Rookery',
      shortName: 'RK',
      enemyColor: Color(0xFF4682B4), // storm blue — stormriders
      bossColor: Color(0xFF1E90FF),
      enemyIcon: Icons.air_rounded,
      bossIcon: Icons.bolt_rounded,
    ),
    TdDungeon(
      name: 'Priory of the Sacred Flame',
      shortName: 'PSF',
      enemyColor: Color(0xFFDAA520), // holy gold — zealots
      bossColor: Color(0xFFFFD700),
      enemyIcon: Icons.shield_rounded,
      bossIcon: Icons.auto_awesome_rounded,
    ),
  ];

  /// Pick a random dungeon.
  static TdDungeon random() {
    return all[Random().nextInt(all.length)];
  }
}

// ---------------------------------------------------------------------------
// KeystoneRun — configuration for a single run
// ---------------------------------------------------------------------------

/// Describes the parameters of a keystone run: level, affixes, and dungeon.
class KeystoneRun {
  final int level;
  final List<TdAffix> affixes;
  final TdDungeon dungeon;

  String get dungeonName => dungeon.name;

  const KeystoneRun({
    required this.level,
    required this.affixes,
    required this.dungeon,
  });

  /// Enemy HP multiplier based on keystone level (scales from level 2+).
  double get hpMultiplier => 1.0 + (level - 2) * 0.15;

  bool get hasFortified => affixes.contains(TdAffix.fortified);
  bool get hasTyrannical => affixes.contains(TdAffix.tyrannical);
  bool get hasBolstering => affixes.contains(TdAffix.bolstering);
  bool get hasBursting => affixes.contains(TdAffix.bursting);
  bool get hasSanguine => affixes.contains(TdAffix.sanguine);

  /// Generates a random keystone run for the given [level] and [dungeon].
  static KeystoneRun generate(int level, {TdDungeon? dungeon}) {
    final rng = Random();
    final allAffixes = List<TdAffix>.from(TdAffix.values)..shuffle(rng);
    final count = level >= 7 ? 2 : 1;
    return KeystoneRun(
      level: level,
      affixes: allAffixes.take(count).toList(),
      dungeon: dungeon ?? TdDungeon.random(),
    );
  }
}
