import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Standard WoW item quality tiers with their iconic colors.
enum ItemQuality {
  poor(Color(0xFF9D9D9D), 'Poor'),
  common(Color(0xFFFFFFFF), 'Common'),
  uncommon(Color(0xFF1EFF00), 'Uncommon'),
  rare(Color(0xFF0070DD), 'Rare'),
  epic(Color(0xFFA335EE), 'Epic'),
  legendary(Color(0xFFFF8000), 'Legendary'),
  artifact(Color(0xFFE6CC80), 'Artifact'),
  heirloom(Color(0xFF00CCFF), 'Heirloom');

  final Color color;
  final String label;
  const ItemQuality(this.color, this.label);

  static ItemQuality fromType(String? type) {
    switch (type?.toUpperCase()) {
      case 'POOR':
        return ItemQuality.poor;
      case 'COMMON':
        return ItemQuality.common;
      case 'UNCOMMON':
        return ItemQuality.uncommon;
      case 'RARE':
        return ItemQuality.rare;
      case 'EPIC':
        return ItemQuality.epic;
      case 'LEGENDARY':
        return ItemQuality.legendary;
      case 'ARTIFACT':
        return ItemQuality.artifact;
      case 'HEIRLOOM':
        return ItemQuality.heirloom;
      default:
        return ItemQuality.common;
    }
  }
}

/// A commodity item with optional price data from the auction house.
class AuctionItem {
  final int id;
  final String name;
  final String? subclass;
  final String? iconUrl;
  final int? mediaId;
  final ItemQuality? quality;
  final int? modifiedCraftingId;
  final int? craftingTier; // 1 = Silver, 2 = Gold (Midnight)
  final int? price; // lowest unit price in copper
  final int? totalQuantity; // total quantity available

  const AuctionItem({
    required this.id,
    required this.name,
    this.subclass,
    this.iconUrl,
    this.mediaId,
    this.quality,
    this.modifiedCraftingId,
    this.craftingTier,
    this.price,
    this.totalQuantity,
  });

  /// Parse from Blizzard Item Search API result entry.
  factory AuctionItem.fromSearchResult(
    Map<String, dynamic> result,
    String locale,
  ) {
    final data = result['data'] as Map<String, dynamic>;
    final nameMap = data['name'] as Map<String, dynamic>?;
    final subclassMap =
        data['item_subclass']?['name'] as Map<String, dynamic>?;

    final qualityType = data['quality']?['type'] as String?;
    final mcId = data['modified_crafting']?['id'] as int?;

    return AuctionItem(
      id: data['id'] as int,
      name:
          (nameMap?[locale] ?? nameMap?.values.first ?? 'Unknown') as String,
      subclass:
          (subclassMap?[locale] ?? subclassMap?.values.first) as String?,
      mediaId: data['media']?['id'] as int?,
      quality: qualityType != null ? ItemQuality.fromType(qualityType) : null,
      modifiedCraftingId: mcId,
    );
  }

  /// Restore from persisted JSON (watchlist).
  factory AuctionItem.fromJson(Map<String, dynamic> json) {
    return AuctionItem(
      id: json['id'] as int,
      name: json['name'] as String,
      subclass: json['subclass'] as String?,
      iconUrl: json['iconUrl'] as String?,
      mediaId: json['mediaId'] as int?,
      quality: json['quality'] != null
          ? ItemQuality.fromType(json['quality'] as String)
          : null,
      modifiedCraftingId: json['modifiedCraftingId'] as int?,
      craftingTier: json['craftingTier'] as int?,
    );
  }

  /// Persist to JSON (watchlist). Price/quantity excluded — they're transient.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (subclass != null) 'subclass': subclass,
        if (iconUrl != null) 'iconUrl': iconUrl,
        if (mediaId != null) 'mediaId': mediaId,
        if (quality != null) 'quality': quality!.name,
        if (modifiedCraftingId != null)
          'modifiedCraftingId': modifiedCraftingId,
        if (craftingTier != null) 'craftingTier': craftingTier,
      };

  int get gold => (price ?? 0) ~/ 10000;
  int get silver => ((price ?? 0) % 10000) ~/ 100;
  int get copper => (price ?? 0) % 100;

  String get formattedPrice {
    final g = NumberFormat('#,##0').format(gold);
    final s = silver.toString().padLeft(2, '0');
    final c = copper.toString().padLeft(2, '0');
    return '${g}g ${s}s ${c}c';
  }

  String get formattedQuantity {
    if (totalQuantity == null) return '';
    return NumberFormat('#,###').format(totalQuantity);
  }

  /// Assigns crafting tiers to items that share the same name and
  /// modified_crafting group, using sequential item ID ordering.
  static List<AuctionItem> assignCraftingTiers(List<AuctionItem> items) {
    // Group items by (name, modifiedCraftingId) — only for items that
    // actually have a modifiedCraftingId (i.e. crafting reagents).
    final groups = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.modifiedCraftingId == null) continue;
      final key = '${item.name}::${item.modifiedCraftingId}';
      (groups[key] ??= []).add(i);
    }

    final result = List<AuctionItem>.from(items);
    for (final indices in groups.values) {
      if (indices.length < 2) continue; // no ambiguity, skip
      // Sort indices by item ID ascending → lower ID = lower tier
      indices.sort((a, b) => result[a].id.compareTo(result[b].id));
      for (var tier = 0; tier < indices.length; tier++) {
        result[indices[tier]] =
            result[indices[tier]].copyWith(craftingTier: tier + 1);
      }
    }
    return result;
  }

  AuctionItem copyWith({
    int? id,
    String? name,
    String? subclass,
    String? iconUrl,
    int? mediaId,
    ItemQuality? quality,
    int? modifiedCraftingId,
    int? craftingTier,
    int? price,
    int? totalQuantity,
  }) {
    return AuctionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      subclass: subclass ?? this.subclass,
      iconUrl: iconUrl ?? this.iconUrl,
      mediaId: mediaId ?? this.mediaId,
      quality: quality ?? this.quality,
      modifiedCraftingId: modifiedCraftingId ?? this.modifiedCraftingId,
      craftingTier: craftingTier ?? this.craftingTier,
      price: price ?? this.price,
      totalQuantity: totalQuantity ?? this.totalQuantity,
    );
  }
}
