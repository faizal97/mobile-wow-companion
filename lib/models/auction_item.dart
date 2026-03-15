import 'package:intl/intl.dart';

/// A commodity item with optional price data from the auction house.
class AuctionItem {
  final int id;
  final String name;
  final String? subclass;
  final String? iconUrl;
  final int? mediaId;
  final int? price; // lowest unit price in copper
  final int? totalQuantity; // total quantity available

  const AuctionItem({
    required this.id,
    required this.name,
    this.subclass,
    this.iconUrl,
    this.mediaId,
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

    return AuctionItem(
      id: data['id'] as int,
      name:
          (nameMap?[locale] ?? nameMap?.values.first ?? 'Unknown') as String,
      subclass:
          (subclassMap?[locale] ?? subclassMap?.values.first) as String?,
      mediaId: data['media']?['id'] as int?,
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
    );
  }

  /// Persist to JSON (watchlist). Price/quantity excluded — they're transient.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (subclass != null) 'subclass': subclass,
        if (iconUrl != null) 'iconUrl': iconUrl,
        if (mediaId != null) 'mediaId': mediaId,
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

  AuctionItem copyWith({
    int? id,
    String? name,
    String? subclass,
    String? iconUrl,
    int? mediaId,
    int? price,
    int? totalQuantity,
  }) {
    return AuctionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      subclass: subclass ?? this.subclass,
      iconUrl: iconUrl ?? this.iconUrl,
      mediaId: mediaId ?? this.mediaId,
      price: price ?? this.price,
      totalQuantity: totalQuantity ?? this.totalQuantity,
    );
  }
}
