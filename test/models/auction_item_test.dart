import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/models/auction_item.dart';

void main() {
  group('AuctionItem', () {
    test('fromSearchResult parses Blizzard item search response', () {
      final json = {
        'data': {
          'id': 210796,
          'name': {'en_US': 'Mycbloom'},
          'item_subclass': {
            'name': {'en_US': 'Herb'},
          },
          'media': {'id': 210796},
          'quality': {
            'type': 'UNCOMMON',
            'name': {'en_US': 'Uncommon'},
          },
        },
      };
      final item = AuctionItem.fromSearchResult(json, 'en_US');
      expect(item.id, 210796);
      expect(item.name, 'Mycbloom');
      expect(item.subclass, 'Herb');
      expect(item.mediaId, 210796);
      expect(item.quality, ItemQuality.uncommon);
    });

    test('gold/silver/copper breakdown from copper price', () {
      const item = AuctionItem(id: 1, name: 'Test', price: 123456);
      expect(item.gold, 12);
      expect(item.silver, 34);
      expect(item.copper, 56);
    });

    test('formattedPrice formats g/s/c correctly', () {
      const item = AuctionItem(id: 1, name: 'Test', price: 85000);
      expect(item.formattedPrice, '8g 50s 00c');
    });

    test('formattedPrice handles large gold values with commas', () {
      const item = AuctionItem(id: 1, name: 'Test', price: 2450000);
      expect(item.formattedPrice, '245g 00s 00c');
    });

    test('formattedPrice handles zero price', () {
      const item = AuctionItem(id: 1, name: 'Test', price: 0);
      expect(item.formattedPrice, '0g 00s 00c');
    });

    test('toJson and fromJson round-trip for watchlist persistence', () {
      const item = AuctionItem(
        id: 210796,
        name: 'Mycbloom',
        subclass: 'Herb',
        iconUrl: 'https://example.com/icon.jpg',
        mediaId: 210796,
        quality: ItemQuality.uncommon,
        price: 85000,
        totalQuantity: 1247,
      );
      final json = item.toJson();
      final restored = AuctionItem.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.subclass, item.subclass);
      expect(restored.iconUrl, item.iconUrl);
      expect(restored.mediaId, item.mediaId);
      expect(restored.quality, ItemQuality.uncommon);
    });

    test('copyWith creates updated copy', () {
      const item = AuctionItem(id: 1, name: 'Test');
      final updated = item.copyWith(price: 5000, totalQuantity: 100);
      expect(updated.price, 5000);
      expect(updated.totalQuantity, 100);
      expect(updated.id, 1);
      expect(updated.name, 'Test');
    });

    test('assignCraftingTiers assigns tiers by ID order within same group', () {
      const items = [
        AuctionItem(id: 236774, name: 'Azeroot', modifiedCraftingId: 552),
        AuctionItem(id: 242301, name: 'Azeroot Tea'),
        AuctionItem(id: 236775, name: 'Azeroot', modifiedCraftingId: 552),
      ];
      final result = AuctionItem.assignCraftingTiers(items);

      // Same name + mcId → tiers assigned by ID order
      expect(result[0].craftingTier, 1); // id 236774 (lower)
      expect(result[2].craftingTier, 2); // id 236775 (higher)

      // No mcId → no tier assigned
      expect(result[1].craftingTier, isNull);
    });

    test('assignCraftingTiers skips single items in a group', () {
      const items = [
        AuctionItem(id: 100, name: 'Ore', modifiedCraftingId: 10),
        AuctionItem(id: 200, name: 'Herb', modifiedCraftingId: 20),
      ];
      final result = AuctionItem.assignCraftingTiers(items);
      expect(result[0].craftingTier, isNull);
      expect(result[1].craftingTier, isNull);
    });

    test('toJson and fromJson round-trip preserves crafting tier', () {
      const item = AuctionItem(
        id: 236774,
        name: 'Azeroot',
        modifiedCraftingId: 552,
        craftingTier: 1,
      );
      final restored = AuctionItem.fromJson(item.toJson());
      expect(restored.modifiedCraftingId, 552);
      expect(restored.craftingTier, 1);
    });
  });
}
