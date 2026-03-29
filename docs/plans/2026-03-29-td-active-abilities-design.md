# TD Tower Active Abilities Design

## Overview

Add **1 active ability** and **1 ultimate ability** per WoW class tower. Players manually activate abilities during waves via an **Ability Dock** UI at the bottom of the game screen. All ability definitions, charge configs, targeting, cooldowns, and effects are **fully data-driven** in `classes.json`.

## Core Mechanics

### Ability Types

- **Active Ability**: Short cooldown, tactical. Starts 33% on cooldown at wave start to prevent turn-1 dumps.
- **Ultimate Ability**: Powerful, charges up during combat via a per-class data-driven charge system.

### Targeting System

- **Instant abilities** (`"targeting": "instant"`): Tap the button, fires immediately using smart-cast logic. Game continues running.
- **Targeted abilities** (`"targeting": "enemy"`, `"lane"`, or `"tower"`): Tap the button, game PAUSES, valid targets highlighted, player taps target, cast, game resumes. Cancel button to back out. Supports both mobile and web equally.

### Ultimate Charge System (Data-Driven)

Each class defines its own charge configuration in JSON:

**Available charge triggers:**

| Trigger | Description |
|---|---|
| `on_attack` | Charges each time the tower attacks |
| `on_kill` | Charges when the tower gets a killing blow |
| `on_crit` | Charges when the tower lands a critical hit |
| `on_nth_attack` | Charges on every Nth attack (uses existing nth tracking) |
| `on_buff_ally` | Charges when the tower buffs/shields/cleanses an ally |
| `on_enemy_debuffed` | Charges when the tower applies a debuff (slow, DoT) to an enemy |
| `on_time` | Charges passively over time (amount per tick, with configurable `interval`) |
| `on_wave_start` | Grants flat charge at the start of each wave |

---

## Ability Dock UI

### Layout

A horizontal bar at the bottom of the game screen with up to 6 **ability cells** (one per placed tower).

```
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│ icon │ │ icon │ │ icon │ │ icon │ │ icon │ │ icon │
│  Q   │ │  Q   │ │  Q   │ │  Q   │ │  Q   │ │  Q   │
│──────│ │──────│ │──────│ │──────│ │──────│ │──────│
│  ✦ R │ │  ✦ R │ │  ✦ R │ │  ✦ R │ │  ✦ R │ │  ✦ R │
└──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘
```

### Each Cell (~56dp wide x 72dp tall)

- **Top portion (44dp)**: Active ability icon + radial cooldown sweep overlay
- **Divider**: Thin line in the tower's class color
- **Bottom portion (28dp)**: Ultimate icon + charge ring that fills progressively
- **Border**: Glows in class color when abilities are ready

### Interactions

| Element | Gesture | Behavior |
|---|---|---|
| Active ability | Tap | Activates (instant) or enters targeting mode (targeted) |
| Ultimate ability | Swipe up on cell | Activates when fully charged. Swipe-up prevents accidental activation |
| Cancel targeting | Tap cancel button | Exits targeting mode without casting, game resumes |

### Visual Feedback

| State | Visual |
|---|---|
| Ready | Subtle pulsing glow in class color |
| On cooldown | Darkened icon + radial clockwise sweep + seconds counter |
| Ultimate charging | Ring around ult icon fills progressively in class color |
| Ultimate ready | Golden glow + pulse animation + "READY" shimmer |
| Cast | Shockwave ripple (active) or screen-edge flash in class color (ultimate) |
| Tower debuffed | Cell border flickers red, icons desaturated |
| Targeting mode | Game paused, dark overlay, valid targets glow/pulse, casting tower highlighted |

---

## Targeting Mode Details

### Pause Behavior
When a targeted ability is activated:
1. Game loop pauses (`dt = 0` — all timers, movement, and attacks freeze)
2. Dark overlay (50% opacity) dims the game field
3. Valid targets highlighted with a pulsing glow
4. Casting tower gets a visual indicator (aura/highlight)
5. Player taps a valid target to cast
6. Ability fires, overlay clears, game resumes
7. Cancel button in corner to back out without casting

### Target Types
| Target type | Valid targets | Used by |
|---|---|---|
| `enemy` | Individual enemy units (glowing highlight) | Execute, Death Grip, Aimed Shot, Chaos Bolt, Touch of Death |
| `lane` | Entire lane (lane strip glows) | Eye Beam, Fire Breath, Deep Breath, Army of the Dead, Summon Infernal |
| `tower` | Allied tower slots (tower glow) | Blessing of Protection, Power Infusion |

---

## Class Ability Definitions (Aligned with Actual classes.json)

### Warrior — Melee, Passive: Cleave (extra_targets +1)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Execute | `enemy` | Deal 3x damage to a single enemy below 30% HP. Instant kill below 10%. |
| **Ultimate** | Bladestorm | `instant` | Deal heavy damage to ALL enemies in ALL lanes for 4s. |

- Active cooldown: 10s
- Ult charge: `on_attack`, amount: 1, max: 15
- Synergy: Cleave feeds steady on_attack charge. Execute picks off weakened enemies Cleave softened.

### Rogue — Melee, Passive: Ambush (every 4th attack deals 3.5x damage)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Vanish | `instant` | Disappear 3s: immune to enemy ranged attacks and debuffs. Next attack is a guaranteed Ambush: 4x damage + 1.5s stun on target. |
| **Ultimate** | Shadow Blades | `instant` | For 8s: all attacks deal 2x damage and build combo points. At 5 combo points, auto-Eviscerate the current target for 6x damage, then reset. |

- Active cooldown: 10s
- Ult charge: `on_nth_attack`, amount: 3, max: 15 (triggers on the Ambush hit — every 4th attack)
- Synergy: Ambush passive feeds ult charge directly. Vanish guarantees the next Ambush for burst + stun.

### Death Knight — Melee, Passive: Frost Fever (slow 30% + DoT)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Death Grip | `enemy` | Pull target enemy back to the start of its lane. |
| **Ultimate** | Army of the Dead | `lane` | Summon ghouls that block all enemy movement in a lane for 6s. Enemies take DoT while blocked. |

- Active cooldown: 15s
- Ult charge: `on_enemy_debuffed`, amount: 1, max: 18
- Synergy: Every attack applies Frost Fever (slow + DoT = 2 debuffs), feeding ult charge naturally.

### Paladin — Melee, Passive: Divine Shield (immune_to_debuff)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Blessing of Protection | `tower` | Grant an allied tower immunity to damage and debuffs for 5s. Can target self or any ally. |
| **Ultimate** | Avenging Wrath | `instant` | Golden wings for 10s: ALL towers gain +25% damage and immunity to debuffs. |

- Active cooldown: 18s
- Ult charge: `on_buff_ally`, amount: 2, max: 20
- Synergy: Blessing of Protection triggers on_buff_ally charge. Empowered cleanse_adjacent also feeds it.

### Monk — Melee, Passive: Flurry (attack_speed_multiplier 0.625, ~60% faster)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Fists of Fury | `instant` | Channel rapid attacks for 3s: 5 hits on current target at 0.6x damage each (3x total). Tower immune to debuffs during channel. |
| **Ultimate** | Touch of Death | `enemy` | Instantly kill any non-boss enemy. Deal 30% max HP to bosses. |

- Active cooldown: 12s
- Ult charge: `on_attack`, amount: 1, max: 12
- Synergy: Flurry's fast attack speed means on_attack charges quickly. Lower max (12) compensates — the fastest ult in the game.

### Demon Hunter — Melee, Passive: Fel Rush (cross_lane_attack +1)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Eye Beam | `lane` | Channel a fel beam down an entire lane for 3s, dealing continuous damage to all enemies. |
| **Ultimate** | Metamorphosis | `instant` | Transform for 8s: +50% damage, +50% attack speed, cross_lane_attack extends to ALL lanes. |

- Active cooldown: 14s
- Ult charge: `on_kill`, amount: 2, max: 20
- Synergy: Cross-lane passive means more kills across lanes, feeding Metamorphosis charge.

### Mage — Ranged, Passive: Hot Streak (30% crit, 2.5x multiplier)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Meteor | `lane` | Call down a meteor on a lane dealing 4x AoE damage to all enemies. Leaves a burn zone for 4s dealing DoT. |
| **Ultimate** | Combustion | `instant` | For 8s: ALL attacks auto-crit (100% crit, 2.5x damage using Hot Streak multiplier) and splash to nearby enemies in the same lane. |

- Active cooldown: 14s
- Ult charge: `on_crit`, amount: 2, max: 20
- Synergy: Hot Streak crits feed Combustion charge. Combustion guarantees crits, creating a burst window.

### Hunter — Ranged, Passive: Multi-Shot (extra_targets +1)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Aimed Shot | `enemy` | Precise shot dealing 4x damage to a single target. Ignores shield and phase enemy modifiers. |
| **Ultimate** | Bestial Wrath | `instant` | Summon a spirit beast for 8s that attacks the furthest enemy in any lane every 0.5s at 1.5x tower damage. Tower also gains +30% attack speed. |

- Active cooldown: 10s
- Ult charge: `on_attack`, amount: 1, max: 14
- Synergy: Multi-Shot hits 2 targets per attack, but ult charges once per attack action. Aimed Shot provides single-target burst to complement the AoE passive.

### Warlock — Ranged, Passive: Corruption (DoT 50% over 4s)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Chaos Bolt | `enemy` | Fire chaotic energy dealing 4x damage, always crits. Spreads all active DoTs on the target to 2 nearby enemies. |
| **Ultimate** | Summon Infernal | `lane` | Call down an Infernal that crashes into a lane, stunning all enemies 2s on impact, then pulses AoE damage for 8s. |

- Active cooldown: 14s
- Ult charge: `on_enemy_debuffed`, amount: 1, max: 22
- Synergy: Every Corruption tick applies a debuff, steadily feeding Infernal charge. Chaos Bolt spreading DoTs accelerates it.

### Evoker — Ranged, Passive: Charged Blast (3s charge, 5x damage)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Fire Breath | `lane` | Breathe fire down an entire lane dealing damage to all enemies + burn DoT. Damage scales with current charge level (1x at 0 charge, up to 3x at full charge). |
| **Ultimate** | Deep Breath | `lane` | Fly over a lane dealing massive damage to ALL enemies and knocking them back toward the start. 50% slow for 4s. |

- Active cooldown: 10s
- Ult charge: `on_attack`, amount: 3, max: 24
- Synergy: Slow charge attack rate (one hit per 3s) compensated by amount: 3 per hit. Fire Breath consumes current charge for a lane-wide AoE alternative.

### Priest — Support, Passive: Power Word: Fortitude (buff_adjacent_damage +35%)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Power Infusion | `tower` | Grant a tower +50% attack speed for 6s. |
| **Ultimate** | Voidform | `instant` | Transform for 10s: switches to Ranged archetype, attacks highest-HP enemy in any lane with shadow damage. Each consecutive hit on same target deals +10% stacking damage. |

- Active cooldown: 15s
- Ult charge: `on_buff_ally`, amount: 1, max: 20
- Synergy: Fortitude passive constantly buffs adjacent towers, slowly feeding ult charge. Power Infusion gives a burst of on_buff_ally charge. Voidform transforms the support into a DPS threat.

### Druid — Support, Passive: Nature's Swiftness (buff_adjacent_speed +30%)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Shapeshift | `instant` | Toggle between forms: **Bear Form** (switches to Melee archetype, +50% fortify effect) / **Cat Form** (switches to Melee archetype, +40% attack speed, gains 20% crit). Resets attack cooldown on shift. Reverts to Support form after 6s. |
| **Ultimate** | Convoke the Spirits | `instant` | Channel 4s: rapidly casts 16 random effects — damage bursts, DoTs, debuff cleanses, and buffs — across ALL lanes. |

- Active cooldown: 8s (short, encourages frequent shifting)
- Ult charge: `on_time`, amount: 1, interval: 2.0, max: 30
- Synergy: In support form, Druid buffs allies. Shapeshift lets it temporarily deal damage when needed. Convoke is the chaotic burst that touches everything.

### Shaman — AoE, Passive: Chain Lightning (chain_damage bounces to 4 enemies)

| | Name | Targeting | Description |
|---|---|---|---|
| **Active** | Lava Burst | `enemy` | Hurl a guaranteed-crit lava bolt at a target dealing 4x damage. If the target has any active DoT, deal 6x instead. |
| **Ultimate** | Bloodlust | `instant` | ALL towers gain +30% attack speed for 10s. All active ability cooldowns reduced by 50%. |

- Active cooldown: 12s
- Ult charge: `on_time`, amount: 1, interval: 2.0, max: 30
- Synergy: Chain Lightning passive already provides AoE. Lava Burst adds single-target burst (rewards pairing Shaman with DoT towers). Bloodlust is the ultimate team buff, just like in WoW raids.

---

## Full Data Schema

### classes.json Extension

Each class entry gains two new top-level keys: `activeAbility` and `ultimateAbility`. All ability behavior is defined through the effects array — the game engine processes effects generically.

```json
{
  "warrior": {
    "archetype": "melee",
    "passive": { "..." : "existing passive definition" },
    "empoweredPassive": { "..." : "existing empowered passive" },
    "attackColor": "#C69B6D",
    "activeAbility": {
      "name": "Execute",
      "description": "Deal 3x damage to an enemy below 30% HP. Instant kill below 10%.",
      "targeting": "enemy",
      "cooldown": 10.0,
      "initialCooldownPct": 0.33,
      "effects": [
        {
          "type": "damage_multiplier",
          "value": 3.0,
          "condition": { "target_hp_below_pct": 0.30 }
        },
        {
          "type": "instant_kill",
          "condition": { "target_hp_below_pct": 0.10 }
        }
      ]
    },
    "ultimateAbility": {
      "name": "Bladestorm",
      "description": "Deal heavy damage to ALL enemies in ALL lanes for 4s.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_attack",
        "amount": 1,
        "max": 15
      },
      "duration": 4.0,
      "effects": [
        {
          "type": "damage_all_lanes",
          "damage_multiplier": 1.5,
          "tick_interval": 0.5
        }
      ]
    }
  },
  "rogue": {
    "archetype": "melee",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#FFF468",
    "activeAbility": {
      "name": "Vanish",
      "description": "Disappear for 3s: immune to enemy attacks and debuffs. Next attack is Ambush: 4x damage + 1.5s stun.",
      "targeting": "instant",
      "cooldown": 10.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "stealth", "duration": 3.0 },
        {
          "type": "empower_next_attack",
          "damage_multiplier": 4.0,
          "apply_stun": 1.5
        }
      ]
    },
    "ultimateAbility": {
      "name": "Shadow Blades",
      "description": "For 8s: attacks deal 2x damage and build combo points. At 5 points, auto-Eviscerate for 6x damage.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_nth_attack",
        "amount": 3,
        "max": 15
      },
      "duration": 8.0,
      "effects": [
        { "type": "damage_multiplier", "value": 2.0 },
        {
          "type": "combo_points",
          "gain_per_attack": 1,
          "threshold": 5,
          "finisher": { "type": "damage_multiplier", "value": 6.0 }
        }
      ]
    }
  },
  "death knight": {
    "archetype": "melee",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#C41E3A",
    "activeAbility": {
      "name": "Death Grip",
      "description": "Pull target enemy back to the start of its lane.",
      "targeting": "enemy",
      "cooldown": 15.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "pull_to_start" }
      ]
    },
    "ultimateAbility": {
      "name": "Army of the Dead",
      "description": "Summon ghouls that block all enemy movement in a lane for 6s. Blocked enemies take DoT.",
      "targeting": "lane",
      "charge": {
        "trigger": "on_enemy_debuffed",
        "amount": 1,
        "max": 18
      },
      "duration": 6.0,
      "effects": [
        { "type": "block_lane", "duration": 6.0 },
        { "type": "dot", "damageType": "percentDamage", "value": 0.15, "duration": 6.0, "ticks": 6 }
      ]
    }
  },
  "paladin": {
    "archetype": "melee",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#F48CBA",
    "activeAbility": {
      "name": "Blessing of Protection",
      "description": "Grant an allied tower immunity to damage and debuffs for 5s.",
      "targeting": "tower",
      "cooldown": 18.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "buff_tower", "buff": "immune_to_debuff", "duration": 5.0 },
        { "type": "buff_tower", "buff": "immune_to_damage", "duration": 5.0 }
      ]
    },
    "ultimateAbility": {
      "name": "Avenging Wrath",
      "description": "Golden wings for 10s: ALL towers gain +25% damage and immunity to debuffs.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_buff_ally",
        "amount": 2,
        "max": 20
      },
      "duration": 10.0,
      "effects": [
        { "type": "buff_all_towers", "buff": "damage_multiplier", "value": 1.25, "duration": 10.0 },
        { "type": "buff_all_towers", "buff": "immune_to_debuff", "duration": 10.0 }
      ]
    }
  },
  "monk": {
    "archetype": "melee",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#00FF98",
    "activeAbility": {
      "name": "Fists of Fury",
      "description": "Channel rapid attacks for 3s: 5 hits at 0.6x damage each. Immune to debuffs during channel.",
      "targeting": "instant",
      "cooldown": 12.0,
      "initialCooldownPct": 0.33,
      "effects": [
        {
          "type": "channel_attack",
          "duration": 3.0,
          "hits": 5,
          "damage_per_hit": 0.6,
          "immune_during": true
        }
      ]
    },
    "ultimateAbility": {
      "name": "Touch of Death",
      "description": "Instantly kill any non-boss enemy. Deal 30% max HP to bosses.",
      "targeting": "enemy",
      "charge": {
        "trigger": "on_attack",
        "amount": 1,
        "max": 12
      },
      "effects": [
        {
          "type": "instant_kill",
          "condition": { "not_boss": true }
        },
        {
          "type": "percent_hp_damage",
          "value": 0.30,
          "condition": { "is_boss": true }
        }
      ]
    }
  },
  "demon hunter": {
    "archetype": "melee",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#A330C9",
    "activeAbility": {
      "name": "Eye Beam",
      "description": "Channel a fel beam down an entire lane for 3s, dealing continuous damage to all enemies.",
      "targeting": "lane",
      "cooldown": 14.0,
      "initialCooldownPct": 0.33,
      "effects": [
        {
          "type": "damage_lane",
          "damage_multiplier": 0.5,
          "tick_interval": 0.3,
          "duration": 3.0
        }
      ]
    },
    "ultimateAbility": {
      "name": "Metamorphosis",
      "description": "Transform for 8s: +50% damage, +50% attack speed, attacks hit ALL lanes.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_kill",
        "amount": 2,
        "max": 20
      },
      "duration": 8.0,
      "effects": [
        { "type": "damage_multiplier", "value": 1.5 },
        { "type": "attack_speed_multiplier", "value": 0.667 },
        { "type": "cross_lane_attack", "value": 99 }
      ]
    }
  },
  "mage": {
    "archetype": "ranged",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#3FC7EB",
    "activeAbility": {
      "name": "Meteor",
      "description": "Call down a meteor on a lane dealing 4x AoE damage. Leaves a burn zone for 4s.",
      "targeting": "lane",
      "cooldown": 14.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "damage_lane", "damage_multiplier": 4.0, "tick_interval": 0, "duration": 0 },
        { "type": "burn_zone", "damage_per_tick": 0.3, "tick_interval": 1.0, "duration": 4.0 }
      ]
    },
    "ultimateAbility": {
      "name": "Combustion",
      "description": "For 8s: ALL attacks auto-crit at 2.5x and splash to nearby enemies in the same lane.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_crit",
        "amount": 2,
        "max": 20
      },
      "duration": 8.0,
      "effects": [
        { "type": "guaranteed_crit", "multiplier": 2.5 },
        { "type": "splash_damage", "radius": "same_lane", "splash_pct": 0.5 }
      ]
    }
  },
  "hunter": {
    "archetype": "ranged",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#AAD372",
    "activeAbility": {
      "name": "Aimed Shot",
      "description": "Precise shot dealing 4x damage. Ignores shield and phase enemy modifiers.",
      "targeting": "enemy",
      "cooldown": 10.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "damage_multiplier", "value": 4.0 },
        { "type": "ignore_modifiers", "modifiers": ["shield", "phase"] }
      ]
    },
    "ultimateAbility": {
      "name": "Bestial Wrath",
      "description": "Summon a spirit beast for 8s that attacks the furthest enemy in any lane every 0.5s at 1.5x damage. Tower gains +30% attack speed.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_attack",
        "amount": 1,
        "max": 14
      },
      "duration": 8.0,
      "effects": [
        {
          "type": "summon_pet",
          "targeting": "furthest_any_lane",
          "attack_interval": 0.5,
          "damage_multiplier": 1.5,
          "duration": 8.0
        },
        { "type": "attack_speed_multiplier", "value": 0.77 }
      ]
    }
  },
  "warlock": {
    "archetype": "ranged",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#8788EE",
    "activeAbility": {
      "name": "Chaos Bolt",
      "description": "Fire chaotic energy dealing 4x damage, always crits. Spreads DoTs on target to 2 nearby enemies.",
      "targeting": "enemy",
      "cooldown": 14.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "damage_multiplier", "value": 4.0 },
        { "type": "guaranteed_crit" },
        { "type": "dot_spread", "count": 2 }
      ]
    },
    "ultimateAbility": {
      "name": "Summon Infernal",
      "description": "Call down an Infernal that stuns enemies 2s on impact, then pulses AoE damage for 8s.",
      "targeting": "lane",
      "charge": {
        "trigger": "on_enemy_debuffed",
        "amount": 1,
        "max": 22
      },
      "duration": 8.0,
      "effects": [
        { "type": "stun_enemies", "duration": 2.0, "scope": "lane" },
        {
          "type": "summon_pet",
          "targeting": "all_in_lane",
          "attack_interval": 1.0,
          "damage_multiplier": 1.0,
          "duration": 8.0
        }
      ]
    }
  },
  "evoker": {
    "archetype": "ranged",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#33937F",
    "activeAbility": {
      "name": "Fire Breath",
      "description": "Breathe fire down a lane dealing damage to all enemies + burn DoT. Damage scales with charge (1x-3x).",
      "targeting": "lane",
      "cooldown": 10.0,
      "initialCooldownPct": 0.33,
      "effects": [
        {
          "type": "damage_lane",
          "damage_multiplier_from_charge": true,
          "min_multiplier": 1.0,
          "max_multiplier": 3.0
        },
        { "type": "dot", "damageType": "percentDamage", "value": 0.2, "duration": 3.0, "ticks": 3 }
      ]
    },
    "ultimateAbility": {
      "name": "Deep Breath",
      "description": "Fly over a lane dealing massive damage and knocking enemies back. 50% slow for 4s.",
      "targeting": "lane",
      "charge": {
        "trigger": "on_attack",
        "amount": 3,
        "max": 24
      },
      "effects": [
        { "type": "damage_lane", "damage_multiplier": 6.0 },
        { "type": "knockback", "value": 0.3 },
        { "type": "slow_enemy", "value": 0.5, "duration": 4.0 }
      ]
    }
  },
  "priest": {
    "archetype": "support",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#E0E0E0",
    "activeAbility": {
      "name": "Power Infusion",
      "description": "Grant a tower +50% attack speed for 6s.",
      "targeting": "tower",
      "cooldown": 15.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "buff_tower", "buff": "attack_speed_multiplier", "value": 0.667, "duration": 6.0 }
      ]
    },
    "ultimateAbility": {
      "name": "Voidform",
      "description": "Transform for 10s: switch to Ranged archetype, attack highest-HP enemy in any lane. +10% stacking damage per consecutive hit.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_buff_ally",
        "amount": 1,
        "max": 20
      },
      "duration": 10.0,
      "effects": [
        {
          "type": "transform",
          "archetype": "ranged",
          "targeting": "highest_hp_any_lane",
          "stacking_damage_per_hit": 0.10
        }
      ]
    }
  },
  "druid": {
    "archetype": "support",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#FF7C0A",
    "activeAbility": {
      "name": "Shapeshift",
      "description": "Toggle forms. Bear: melee archetype +50% fortify. Cat: melee archetype +40% attack speed +20% crit. Reverts to Support after 6s.",
      "targeting": "instant",
      "cooldown": 8.0,
      "initialCooldownPct": 0.33,
      "duration": 6.0,
      "effects": [
        {
          "type": "shapeshift",
          "forms": {
            "bear": {
              "archetype": "melee",
              "effects": [
                { "type": "fortify_multiplier", "value": 1.5 }
              ]
            },
            "cat": {
              "archetype": "melee",
              "effects": [
                { "type": "attack_speed_multiplier", "value": 0.714 },
                { "type": "crit_chance", "chance": 0.2, "multiplier": 2.0 }
              ]
            }
          },
          "revert_after": 6.0
        }
      ]
    },
    "ultimateAbility": {
      "name": "Convoke the Spirits",
      "description": "Channel 4s: cast 16 random effects — damage, DoTs, cleanses, buffs — across ALL lanes.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_time",
        "amount": 1,
        "interval": 2.0,
        "max": 30
      },
      "duration": 4.0,
      "effects": [
        {
          "type": "random_cast",
          "count": 16,
          "interval": 0.25,
          "pool": [
            { "type": "damage_random_enemy", "damage_multiplier": 2.0, "weight": 4 },
            { "type": "dot_random_enemy", "value": 0.3, "duration": 3.0, "ticks": 3, "weight": 3 },
            { "type": "cleanse_random_tower", "weight": 3 },
            { "type": "buff_random_tower", "buff": "damage_multiplier", "value": 1.2, "duration": 4.0, "weight": 3 },
            { "type": "buff_random_tower", "buff": "attack_speed_multiplier", "value": 0.8, "duration": 4.0, "weight": 3 }
          ]
        }
      ]
    }
  },
  "shaman": {
    "archetype": "aoe",
    "passive": { "..." : "existing" },
    "empoweredPassive": { "..." : "existing" },
    "attackColor": "#0070DD",
    "activeAbility": {
      "name": "Lava Burst",
      "description": "Guaranteed-crit lava bolt dealing 4x damage. If target has active DoT, deal 6x instead.",
      "targeting": "enemy",
      "cooldown": 12.0,
      "initialCooldownPct": 0.33,
      "effects": [
        { "type": "guaranteed_crit" },
        {
          "type": "damage_multiplier",
          "value": 4.0,
          "value_if_dotted": 6.0
        }
      ]
    },
    "ultimateAbility": {
      "name": "Bloodlust",
      "description": "ALL towers gain +30% attack speed for 10s. All active ability cooldowns reduced by 50%.",
      "targeting": "instant",
      "charge": {
        "trigger": "on_time",
        "amount": 1,
        "interval": 2.0,
        "max": 30
      },
      "duration": 10.0,
      "effects": [
        { "type": "buff_all_towers", "buff": "attack_speed_multiplier", "value": 0.77, "duration": 10.0 },
        { "type": "reduce_all_cooldowns", "reduction_pct": 0.5 }
      ]
    }
  }
}
```

---

## New Effect Types

All effect types are strings processed by the game engine. Adding new types requires only a JSON entry and a handler in the effect processor.

| Effect Type | Parameters | Description |
|---|---|---|
| `instant_kill` | `condition` | Kill target (condition: `target_hp_below_pct`, `not_boss`, etc.) |
| `percent_hp_damage` | `value`, `condition` | Deal % of target's max HP as damage |
| `damage_all_lanes` | `damage_multiplier`, `tick_interval` | Periodic damage to all enemies in all lanes |
| `damage_lane` | `damage_multiplier`, `tick_interval`, `duration` | Periodic damage to all enemies in a specific lane |
| `pull_to_start` | — | Reset enemy position to lane start |
| `block_lane` | `duration` | Summon blockers that prevent movement in a lane |
| `summon_pet` | `targeting`, `attack_interval`, `damage_multiplier`, `duration` | Spawn autonomous attacking entity |
| `buff_all_towers` | `buff`, `value`, `duration` | Apply timed buff to all towers |
| `buff_tower` | `buff`, `value`, `duration` | Apply timed buff to a single tower |
| `transform` | `archetype`, `targeting`, per-transform stats | Temporarily change tower archetype and behavior |
| `shapeshift` | `forms` (map of form configs), `revert_after` | Toggle between predefined form configurations |
| `dot_spread` | `count` | Copy all DoTs from target to N nearby enemies |
| `stun_enemies` | `duration`, `scope` | Freeze enemy movement |
| `knockback` | `value` (position amount) | Push enemies backward |
| `random_cast` | `count`, `interval`, `pool` (weighted list) | Cast N random effects from weighted pool |
| `combo_points` | `gain_per_attack`, `threshold`, `finisher` | Builder/spender resource system |
| `stealth` | `duration` | Tower becomes immune to enemy targeting |
| `empower_next_attack` | `damage_multiplier`, `apply_stun` | Buff the next auto-attack |
| `channel_attack` | `duration`, `hits`, `damage_per_hit`, `immune_during` | Multi-hit channel |
| `guaranteed_crit` | `multiplier` (optional, uses passive if omitted) | Next/all attacks auto-crit |
| `splash_damage` | `radius`, `splash_pct` | Attacks deal splash to nearby enemies |
| `ignore_modifiers` | `modifiers` (list of modifier names) | Attack bypasses specific enemy modifiers |
| `burn_zone` | `damage_per_tick`, `tick_interval`, `duration` | Persistent ground zone dealing periodic damage |
| `reduce_all_cooldowns` | `reduction_pct` | Reduce all active ability cooldowns by percentage |
| `fortify_multiplier` | `value` | Multiply the tower's fortify effect |
| `damage_multiplier_from_charge` | `min_multiplier`, `max_multiplier` | Scale damage based on Evoker charge level |

---

## Balance Levers

| Lever | Purpose |
|---|---|
| `cooldown` per ability | How often actives can be used |
| `initialCooldownPct` | Prevents turn-1 ability dumps (default 0.33) |
| `charge.trigger` | What action builds ultimate charge |
| `charge.amount` | How much charge per trigger |
| `charge.max` | Total charge needed (higher = slower ultimate) |
| `charge.interval` | For `on_time` trigger: seconds between charge ticks |
| `duration` on timed effects | How long buffs/transforms/summons last |
| `damage_multiplier` on effects | Scales ability damage relative to base tower damage |
| Archetype attack speed | Indirectly affects on_attack and on_crit charge rates |
| Effect-specific params | Every numeric value in effects is tunable |

---

## Summary

- **13 classes** each with 1 active + 1 ultimate, entirely data-driven in `classes.json`
- **5 instant actives, 8 targeted actives** — good tactical variety
- **9 instant ultimates, 4 targeted ultimates** — ultimates are power moments
- **7 unique charge triggers** — each class charges its ult thematically
- **Pause-on-target** supports mobile and web equally
- **Ability Dock UI** — 6 compact cells with class-colored theming, cooldown sweeps, and charge rings
- **All ability behavior defined through composable effect types** — adding a new ability means adding JSON, not code (unless a new effect type is needed)
- **Every numeric value is configurable** — cooldowns, charge amounts, damage multipliers, durations, all in JSON
