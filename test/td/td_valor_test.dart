import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/data/td_balance_config.dart';
import 'package:wow_warband_companion/td/data/td_run_state.dart';

void main() {
  const config = TdBalanceConfig.defaults;

  group('Valor rewards', () {
    test('clean clear (20+ lives) gives 3 valor', () {
      final state = TdRunState();
      expect(state.computeValorReward(22, config), 3);
    });

    test('standard clear (10-19 lives) gives 2 valor', () {
      final state = TdRunState();
      expect(state.computeValorReward(15, config), 2);
    });

    test('scraped by (1-9 lives) gives 1 valor', () {
      final state = TdRunState();
      expect(state.computeValorReward(3, config), 1);
    });

    test('deplete gives 0 valor', () {
      final state = TdRunState();
      expect(state.computeValorReward(0, config), 0);
    });
  });

  group('Run progression', () {
    test('clear advances key by star rating', () {
      final state = TdRunState(keystoneLevel: 2);
      state.onClear(22, 3, config); // 3 stars
      expect(state.keystoneLevel, 5);
      expect(state.valor, 3);
      expect(state.currentDungeon, isNull);
    });

    test('deplete drops key by 1, keeps dungeon', () {
      final state = TdRunState(keystoneLevel: 5);
      state.onDeplete(config);
      expect(state.keystoneLevel, 4);
    });

    test('deplete at +2 stays at +2', () {
      final state = TdRunState(keystoneLevel: 2);
      state.onDeplete(config);
      expect(state.keystoneLevel, 2);
    });

    test('reset clears everything', () {
      final state = TdRunState(keystoneLevel: 8, valor: 15);
      state.purchaseUpgrade(1, UpgradeType.sharpen, config);
      state.resetRun();
      expect(state.keystoneLevel, 2);
      expect(state.valor, 0);
      expect(state.towerUpgrades, isEmpty);
    });
  });

  group('Sharpen upgrade', () {
    test('+15% damage per stack', () {
      final upgrades = TowerUpgrades();
      upgrades.apply(UpgradeType.sharpen, config);
      expect(upgrades.sharpenMultiplier(config), closeTo(1.15, 0.001));
    });

    test('stacks up to 3', () {
      final upgrades = TowerUpgrades();
      expect(upgrades.apply(UpgradeType.sharpen, config), isTrue);
      expect(upgrades.apply(UpgradeType.sharpen, config), isTrue);
      expect(upgrades.apply(UpgradeType.sharpen, config), isTrue);
      expect(upgrades.apply(UpgradeType.sharpen, config), isFalse); // maxed
      expect(upgrades.sharpenStacks, 3);
      expect(upgrades.sharpenMultiplier(config), closeTo(1.45, 0.001));
    });
  });

  group('Fortify upgrade', () {
    test('can only purchase once', () {
      final upgrades = TowerUpgrades();
      expect(upgrades.apply(UpgradeType.fortify, config), isTrue);
      expect(upgrades.apply(UpgradeType.fortify, config), isFalse);
      expect(upgrades.hasFortify, isTrue);
    });
  });

  group('Empower upgrade', () {
    test('can only purchase once', () {
      final upgrades = TowerUpgrades();
      expect(upgrades.apply(UpgradeType.empower, config), isTrue);
      expect(upgrades.apply(UpgradeType.empower, config), isFalse);
      expect(upgrades.hasEmpower, isTrue);
    });
  });

  group('Purchasing upgrades', () {
    test('deducts valor on purchase', () {
      final state = TdRunState(valor: 5);
      expect(state.purchaseUpgrade(1, UpgradeType.sharpen, config), isTrue);
      expect(state.valor, 4); // cost 1
    });

    test('empower costs 2 valor', () {
      final state = TdRunState(valor: 2);
      expect(state.purchaseUpgrade(1, UpgradeType.empower, config), isTrue);
      expect(state.valor, 0);
    });

    test('fails if insufficient valor', () {
      final state = TdRunState(valor: 0);
      expect(state.purchaseUpgrade(1, UpgradeType.sharpen, config), isFalse);
      expect(state.valor, 0);
    });

    test('fails if upgrade maxed even with sufficient valor', () {
      final state = TdRunState(valor: 10);
      state.purchaseUpgrade(1, UpgradeType.fortify, config);
      expect(state.purchaseUpgrade(1, UpgradeType.fortify, config), isFalse);
      expect(state.valor, 9); // only 1 deducted for first purchase
    });
  });

  group('6th tower slot', () {
    test('unlocked at level 5', () {
      expect(TdRunState(keystoneLevel: 4).isSixthSlotUnlocked(config), isFalse);
      expect(TdRunState(keystoneLevel: 5).isSixthSlotUnlocked(config), isTrue);
      expect(TdRunState(keystoneLevel: 10).isSixthSlotUnlocked(config), isTrue);
    });

    test('maxTowers returns 5 or 6', () {
      expect(TdRunState(keystoneLevel: 3).maxTowers(config), 5);
      expect(TdRunState(keystoneLevel: 5).maxTowers(config), 6);
    });
  });
}
