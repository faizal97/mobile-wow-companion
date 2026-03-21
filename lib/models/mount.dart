import 'package:flutter/material.dart';

/// Broad source groups for filtering (mapped from granular SimpleArmory subcategories).
enum MountSourceGroup {
  drops,
  vendor,
  quest,
  achievement,
  reputation,
  exploration,
  promotion,
  events;

  static const _mapping = <String, MountSourceGroup>{
    // Drops
    'Raid Drop': drops,
    'Dungeon Drop': drops,
    'World Boss': drops,
    'Zone Drop': drops,
    'Rare Spawn': drops,
    'Prey': drops,
    // Vendor
    'Vendor': vendor,
    'Mark of Honor': vendor,
    'Honor': vendor,
    'Dubloons': vendor,
    'Medals': vendor,
    'BMAH': vendor,
    'Guild Vendor': vendor,
    // Quest
    'Quest': quest,
    'Campaign': quest,
    'Allied Race': quest,
    'Allied Races': quest,
    'Pre-Launch Event': quest,
    'Class Hall': quest,
    // Achievement
    'Achievement': achievement,
    'Challenge Mode': achievement,
    'Feats of Strength': achievement,
    'Collect': achievement,
    'Gladiator': achievement,
    'Mage Tower': achievement,
    // Reputation
    'Reputation': reputation,
    'Paragon Reputation': reputation,
    'Renown': reputation,
    'Raid Renown': reputation,
    'Cenarion Expedition': reputation,
    "Kurenai/The Mag'har": reputation,
    'Netherwing': reputation,
    "Sha'tari Skyguard": reputation,
    'Argent Tournament': reputation,
    'Golden Lotus': reputation,
    'Order of the Cloud Serpent': reputation,
    'Shado-Pan': reputation,
    'The Tillers': reputation,
    'Halaa': reputation,
    "Talon's Vengeance": reputation,
    'Reputations': reputation,
    // Exploration
    'Treasure': exploration,
    'Riddle': exploration,
    'Discovery': exploration,
    'Zone Feature': exploration,
    'Primal Eggs': exploration,
    'Zskera Vaults': exploration,
    'Visions': exploration,
    'Visions Revisited': exploration,
    'Obsidian Citadel': exploration,
    'Ritual Sites': exploration,
    'Torghast': exploration,
    'Island Expedition': exploration,
    'Secrets of Azeroth': exploration,
    'Archives': exploration,
    'Lucid Nightmare': exploration,
    // Promotion
    'Blizzard Store': promotion,
    'Blizzcon': promotion,
    "Collector's Edition": promotion,
    'Recruit-A-Friend': promotion,
    'Trading Card Game / Auction House': promotion,
    'Annual Subscription': promotion,
    'Twitch Drops': promotion,
    'Promotions': promotion,
    'Player Vote': promotion,
    'WoW Classic': promotion,
    'Blizzard Anniversary': promotion,
    '20th Anniversary': promotion,
    'HotS': promotion,
    'Hearthstone': promotion,
    'Warcraft III Reforged': promotion,
    'Diablo IV': promotion,
    'Mountain Dew': promotion,
    'Razer': promotion,
    'Azeroth Choppers': promotion,
    'Make-A-Wish': promotion,
    // Events
    'Daily Activities': events,
    'Timewalking': events,
    'Brewfest': events,
    "Hallow's End": events,
    'Love is in the Air': events,
    'Noblegarden': events,
    'Winter Veil': events,
    'Lunar Festival': events,
    "Brawler's Guild": events,
    'Darkmoon Faire': events,
    'Anniversary': events,
    'Plunderstorm': events,
    'Dastardly Duos': events,
    'Greedy Emissary': events,
    'Remix: Pandaria': events,
    'Remix: Legion': events,
    'Time Rifts': events,
    'Events': events,
    'Tormentors': events,
    'Maw Assaults': events,
    'Emerald Bounty': events,
    'Dream Infusion': events,
    'Timeless Isle': events,
    'Warfront: Arathi': events,
    'Warfront: Darkshore': events,
    'Assault: Vale of Eternal Blossoms': events,
    'Assault: Uldum': events,
  };

  /// Resolves a SimpleArmory subcategory to a broad source group.
  static MountSourceGroup? fromSubcategory(String? subcategory) {
    if (subcategory == null) return null;
    return _mapping[subcategory];
  }
}

/// Mount type (ground, flying, aquatic, etc.).
enum MountType {
  ground(230, 'Ground', Icons.terrain_rounded),
  flying(424, 'Flying', Icons.flight_rounded),
  aquatic(254, 'Aquatic', Icons.water_rounded),
  dragonriding(402, 'Dragonriding', Icons.air_rounded);

  final int typeId;
  final String label;
  final IconData icon;
  const MountType(this.typeId, this.label, this.icon);

  static MountType? fromTypeId(int? id) {
    if (id == null) return null;
    for (final t in values) {
      if (t.typeId == id) return t;
    }
    // Some uncommon type IDs map to ground/flying
    if (id == 231 || id == 232 || id == 242 || id == 247 || id == 291) {
      return ground;
    }
    if (id == 407 || id == 408 || id == 412 || id == 436 || id == 437) {
      return flying;
    }
    return null;
  }
}

/// Parsed acquisition info from Wago SourceText.
class MountAcquisition {
  final Map<String, String> fields; // e.g. {"Drop": "The Lich King", "Zone": "Icecrown Citadel"}

  const MountAcquisition(this.fields);

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => fields.isNotEmpty;
}

/// A mount from the journal, merging SimpleArmory + Blizzard + Wago data.
class Mount {
  final int id;
  final String name;
  final String? icon; // SimpleArmory spell icon name
  final int? spellId;
  final int? itemId;
  final String? expansion; // SimpleArmory top-level category
  final String? sourceSubcategory; // SimpleArmory subcategory
  int? creatureDisplayId; // from Blizzard search/detail API
  bool isCollected;
  bool isFavorite;

  // Wago DB2 data
  String? description; // lore/flavor text
  MountAcquisition? acquisition; // parsed "how to obtain" info
  MountType? mountType; // ground/flying/aquatic
  String? requirement; // e.g. "Requires Paladin", "Requires Engineering (1)"

  // Journal data (boss/instance enrichment)
  String? bossName;
  String? bossDescription;
  String? instanceName;

  Mount({
    required this.id,
    required this.name,
    this.icon,
    this.spellId,
    this.itemId,
    this.expansion,
    this.sourceSubcategory,
    this.creatureDisplayId,
    this.isCollected = false,
    this.isFavorite = false,
    this.description,
    this.acquisition,
    this.mountType,
    this.requirement,
    this.bossName,
    this.bossDescription,
    this.instanceName,
  });

  /// Broad source group for filtering.
  MountSourceGroup? get sourceGroup =>
      MountSourceGroup.fromSubcategory(sourceSubcategory);

  /// Spell icon URL from Blizzard render server (for list view).
  String? get spellIconUrl => icon != null
      ? 'https://render.worldofwarcraft.com/us/icons/56/$icon.jpg'
      : null;

  /// Creature display zoom render (for grid view + detail sheet).
  String? get zoomImageUrl => creatureDisplayId != null
      ? 'https://render.worldofwarcraft.com/us/npcs/zoom/creature-display-$creatureDisplayId.jpg'
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (icon != null) 'icon': icon,
        if (spellId != null) 'spellId': spellId,
        if (itemId != null) 'itemId': itemId,
        if (expansion != null) 'expansion': expansion,
        if (sourceSubcategory != null) 'sourceSubcategory': sourceSubcategory,
      };

  factory Mount.fromJson(Map<String, dynamic> json) => Mount(
        id: json['id'] as int,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        spellId: json['spellId'] as int?,
        itemId: json['itemId'] as int?,
        expansion: json['expansion'] as String?,
        sourceSubcategory: json['sourceSubcategory'] as String?,
      );
}

/// Detail data fetched lazily from Blizzard API when a mount is tapped.
class MountDetail {
  final int id;
  final String? description;
  final int? creatureDisplayId;
  final String? sourceType; // DROP, VENDOR, QUEST, etc.
  final String? faction; // ALLIANCE, HORDE

  const MountDetail({
    required this.id,
    this.description,
    this.creatureDisplayId,
    this.sourceType,
    this.faction,
  });

  String? get zoomImageUrl => creatureDisplayId != null
      ? 'https://render.worldofwarcraft.com/us/npcs/zoom/creature-display-$creatureDisplayId.jpg'
      : null;
}
