// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/models/td_models.dart';
import 'td_sim.dart';

// ---------------------------------------------------------------------------
// TD Ability Balance Tests
// ---------------------------------------------------------------------------
//
// These tests measure the impact of active/ultimate abilities on game balance
// and help tune dungeons to accommodate the new power level.
//
// Run all:     flutter test test/td/td_ability_balance_test.dart --reporter expanded
// Run one:     flutter test test/td/td_ability_balance_test.dart --name "ability impact"
// ---------------------------------------------------------------------------

void main() {
  late TdSim sim;

  setUpAll(() {
    sim = TdSim();
    print('\nLoaded ${sim.allClasses.length} classes, '
        '${sim.allDungeonKeys.length} dungeons');
  });

  // ── Ability impact: power comparison ─────────────────────────────────────
  test('ability impact — class power ranking at +2', () {
    print('\n${'=' * 75}');
    print('CLASS POWER RANKING WITH ABILITIES — +2, Windrunner Spire');
    print('${'=' * 75}');
    print('${'Class'.padRight(18)} ${'Archetype'.padRight(10)} '
        '${'Clear%'.padRight(8)} ${'AvgLives'.padRight(10)} ${'AvgWaves'.padRight(10)}');
    print('-' * 75);

    final results = <(String, String, BatchResult)>[];
    for (final className in sim.allClasses) {
      final classDef = sim.classRegistry.getClass(className);
      final r = sim.batch(
        comp: List.filled(5, className),
        dungeon: 'windrunner_spire',
        level: 2,
        affixes: [],
        runs: 20,
      );
      results.add((className, classDef.archetype.name, r));
    }
    results.sort((a, b) {
      final cmp = b.$3.clearRate.compareTo(a.$3.clearRate);
      if (cmp != 0) return cmp;
      return b.$3.avgLives.compareTo(a.$3.avgLives);
    });
    for (final (name, arch, r) in results) {
      print('${name.padRight(18)} ${arch.padRight(10)} ${r.clearRateStr.padRight(8)} '
          '${r.avgLives.toStringAsFixed(1).padRight(10)} '
          '${r.avgWaves.toStringAsFixed(1).padRight(10)}');
    }
  });

  // ── Keystone scaling with abilities ──────────────────────────────────────
  test('ability impact — keystone scaling', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final levels = [2, 4, 6, 8, 10, 12, 15, 20];

    print('\n${'=' * 70}');
    print('KEYSTONE SCALING WITH ABILITIES — Windrunner Spire');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 70}');
    print('${'Level'.padRight(8)} ${'Clear%'.padRight(8)} ${'AvgLives'.padRight(10)} ${'AvgWaves'.padRight(10)}');
    print('-' * 70);

    for (final level in levels) {
      final r = sim.batch(
        comp: comp,
        dungeon: 'windrunner_spire',
        level: level,
        affixes: [],
      );
      print('+$level'.padRight(8) +
          r.clearRateStr.padRight(8) +
          r.avgLives.toStringAsFixed(1).padRight(10) +
          r.avgWaves.toStringAsFixed(1).padRight(10));
    }
  });

  // ── Full dungeon matrix with abilities ───────────────────────────────────
  test('ability impact — full dungeon matrix', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];

    print('\n${'=' * 80}');
    print('DUNGEON MATRIX WITH ABILITIES — Clear rates (%)');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 80}');

    final header = StringBuffer('Dungeon'.padRight(30));
    for (final lvl in [2, 5, 7, 10, 15]) {
      header.write('+$lvl'.padLeft(8));
    }
    print(header);
    print('-' * 80);

    for (final key in sim.allDungeonKeys) {
      final dung = sim.dungeons[key]!;
      final row = StringBuffer(dung.name.padRight(30));
      for (final level in [2, 5, 7, 10, 15]) {
        final r = sim.batch(
            comp: comp, dungeon: key, level: level, affixes: [], runs: 10);
        row.write(r.clearRateStr.padLeft(8));
      }
      print(row);
    }
  });

  // ── Comp comparison with abilities ───────────────────────────────────────
  test('ability impact — comp comparison', () {
    sim.reportCompComparison(
      comps: {
        'All Melee': ['warrior', 'monk', 'rogue', 'death knight', 'demon hunter'],
        'All Ranged': ['mage', 'hunter', 'warlock', 'evoker', 'shaman'],
        'Balanced': ['warrior', 'mage', 'priest', 'monk', 'hunter'],
        'Support Heavy': ['priest', 'druid', 'warrior', 'monk', 'warrior'],
        'AOE Focus': ['shaman', 'warrior', 'hunter', 'priest', 'mage'],
        'Meta Stack': ['monk', 'priest', 'warrior', 'druid', 'hunter'],
      },
      dungeon: 'windrunner_spire',
      level: 5,
      affixes: [TdAffix.fortified],
    );
  });

  // ── Ability class synergy test ───────────────────────────────────────────
  test('ability synergy — support classes value', () {
    print('\n${'=' * 75}');
    print('SUPPORT CLASS VALUE WITH ABILITIES — +5, Windrunner Spire');
    print('${'=' * 75}');
    print('${'Comp'.padRight(40)} ${'Clear%'.padRight(8)} ${'AvgLives'.padRight(10)}');
    print('-' * 60);

    final comps = {
      'No Support': ['warrior', 'monk', 'rogue', 'hunter', 'mage'],
      'With Priest': ['warrior', 'monk', 'priest', 'hunter', 'mage'],
      'With Druid': ['warrior', 'monk', 'druid', 'hunter', 'mage'],
      'With Paladin': ['warrior', 'monk', 'paladin', 'hunter', 'mage'],
      'Double Support': ['warrior', 'monk', 'priest', 'druid', 'hunter'],
    };

    for (final entry in comps.entries) {
      final r = sim.batch(
        comp: entry.value,
        dungeon: 'windrunner_spire',
        level: 5,
        affixes: [],
        runs: 20,
      );
      print('${entry.key.padRight(40)} ${r.clearRateStr.padRight(8)} '
          '${r.avgLives.toStringAsFixed(1).padRight(10)}');
    }
  });

  // ── Dungeon difficulty ranking with abilities ────────────────────────────
  test('ability impact — dungeon ranking at +7', () {
    sim.reportDungeonRanking(
      comp: ['warrior', 'mage', 'priest', 'monk', 'hunter'],
      level: 7,
      affixes: [TdAffix.fortified, TdAffix.bursting],
    );
  });
}
