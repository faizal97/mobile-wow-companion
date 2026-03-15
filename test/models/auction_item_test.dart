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
        },
      };
      final item = AuctionItem.fromSearchResult(json, 'en_US');
      expect(item.id, 210796);
      expect(item.name, 'Mycbloom');
      expect(item.subclass, 'Herb');
      expect(item.mediaId, 210796);
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
    });

    test('copyWith creates updated copy', () {
      const item = AuctionItem(id: 1, name: 'Test');
      final updated = item.copyWith(price: 5000, totalQuantity: 100);
      expect(updated.price, 5000);
      expect(updated.totalQuantity, 100);
      expect(updated.id, 1);
      expect(updated.name, 'Test');
    });
  });
}
