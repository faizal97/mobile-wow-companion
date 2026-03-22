import 'package:flutter/foundation.dart';
import 'td_balance_config.dart';
import 'effect_types.dart';

// ---------------------------------------------------------------------------
// Upgrade types and per-tower upgrade state
// ---------------------------------------------------------------------------

enum UpgradeType { sharpen, fortify, empower }

/// Tracks upgrades purchased for a single tower (by character ID).
class TowerUpgrades {
  int sharpenStacks = 0;
  bool hasFortify = false;
  bool hasEmpower = false;

  /// Apply an upgrade. Returns false if already maxed or not applicable.
  bool apply(UpgradeType type, TdBalanceConfig config) {
    switch (type) {
      case UpgradeType.sharpen:
        if (sharpenStacks >= config.sharpenMaxStacks) return false;
        sharpenStacks++;
        return true;
      case UpgradeType.fortify:
        if (hasFortify) return false;
        hasFortify = true;
        return true;
      case UpgradeType.empower:
        if (hasEmpower) return false;
        hasEmpower = true;
        return true;
    }
  }

  /// Damage multiplier from sharpen stacks.
  double sharpenMultiplier(TdBalanceConfig config) =>
      1.0 + sharpenStacks * config.sharpenDamageBonus;
}

// ---------------------------------------------------------------------------
// TdRunState — persistent state across a keystone run (+2 → +N)
// ---------------------------------------------------------------------------

/// Tracks valor points, per-tower upgrades, and run progression across
/// multiple keystone runs. Resets when starting a new run from +2.
class TdRunState extends ChangeNotifier {
  int keystoneLevel;
  int valor;
  TdDungeonDef? currentDungeon;
  final Map<int, TowerUpgrades> _towerUpgrades; // characterId → upgrades

  TdRunState({this.keystoneLevel = 2, this.valor = 0})
      : currentDungeon = null,
        _towerUpgrades = {};

  /// Get upgrades for a tower (by character ID). Returns null if none.
  TowerUpgrades? getUpgrades(int characterId) => _towerUpgrades[characterId];

  /// All tower upgrades (read-only view).
  Map<int, TowerUpgrades> get towerUpgrades =>
      Map.unmodifiable(_towerUpgrades);

  /// Award valor based on lives remaining after a clear.
  int computeValorReward(int livesRemaining, TdBalanceConfig config) {
    if (livesRemaining >= config.cleanClearThreshold) {
      return config.cleanClearReward;
    }
    if (livesRemaining >= config.standardClearMin) {
      return config.standardClearReward;
    }
    if (livesRemaining > 0) return config.scrapedByReward;
    return config.depleteReward;
  }

  /// Apply a clear: award valor, advance keystone.
  void onClear(int livesRemaining, int starRating, TdBalanceConfig config) {
    final earned = computeValorReward(livesRemaining, config);
    valor += earned;
    keystoneLevel += starRating;
    currentDungeon = null; // needs new roulette
    notifyListeners();
  }

  /// Apply a depletion: drop key by 1, keep dungeon.
  void onDeplete(TdBalanceConfig config) {
    keystoneLevel = (keystoneLevel - 1).clamp(2, 999);
    // currentDungeon stays the same for retry
    notifyListeners();
  }

  /// Purchase an upgrade for a tower. Returns false if insufficient valor
  /// or upgrade is already maxed.
  bool purchaseUpgrade(
      int characterId, UpgradeType type, TdBalanceConfig config) {
    final cost = switch (type) {
      UpgradeType.sharpen => config.sharpenCost,
      UpgradeType.fortify => config.fortifyCost,
      UpgradeType.empower => config.empowerCost,
    };
    if (valor < cost) return false;

    final upgrades =
        _towerUpgrades.putIfAbsent(characterId, () => TowerUpgrades());
    final success = upgrades.apply(type, config);
    if (success) {
      valor -= cost;
      notifyListeners();
    }
    return success;
  }

  /// Whether the 6th tower slot is unlocked at current level.
  bool isSixthSlotUnlocked(TdBalanceConfig config) =>
      keystoneLevel >= config.sixthTowerLevel;

  /// Max towers allowed at current level.
  int maxTowers(TdBalanceConfig config) =>
      isSixthSlotUnlocked(config) ? 6 : 5;

  /// Reset for a new run from +2.
  void resetRun() {
    keystoneLevel = 2;
    valor = 0;
    currentDungeon = null;
    _towerUpgrades.clear();
    notifyListeners();
  }
}
