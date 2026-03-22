// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/models/td_models.dart';
import 'td_sim.dart';

// ---------------------------------------------------------------------------
// TD Balance Simulation Tests
// ---------------------------------------------------------------------------
//
// Run all:     flutter test test/td/td_simulation_test.dart --reporter expanded
// Run one:     flutter test test/td/td_simulation_test.dart --name "dungeon ranking"
//
// The TdSim engine is fully dynamic — we can test any combination:
//   sim.run(comp: [...], dungeon: '...', level: N, affixes: [...])
//   sim.batch(comp: [...], dungeon: '...', level: N, runs: 20)
//   sim.reportDungeonRanking(comp: [...], level: N)
//   sim.reportClassRanking(dungeon: '...', level: N)
//   sim.reportKeystoneScaling(comp: [...], dungeon: '...')
//   sim.reportMatrix(comp: [...], levels: [2, 5, 7, 10])
//   sim.reportCompComparison(comps: {...}, dungeon: '...')
// ---------------------------------------------------------------------------

void main() {
  late TdSim sim;

  setUpAll(() {
    sim = TdSim();
    print('\nLoaded ${sim.allClasses.length} classes: ${sim.allClasses.join(', ')}');
    print('Loaded ${sim.allDungeonKeys.length} dungeons: ${sim.allDungeonNames.join(', ')}');
  });

  // ── Single detailed run ──────────────────────────────────────────────────
  test('single run — verbose trace', () {
    sim.run(
      comp: ['warrior', 'priest', 'monk', 'hunter', 'death knight'],
      dungeon: 'windrunner_spire',
      level: 2,
      affixes: [],
      verbose: true,
    );
  });

  // ── Dungeon difficulty ranking ───────────────────────────────────────────
  test('dungeon ranking at +2', () {
    sim.reportDungeonRanking(
      comp: ['warrior', 'mage', 'priest', 'monk', 'hunter'],
      level: 2,
      affixes: [],
    );
  });

  // ── Class solo power ─────────────────────────────────────────────────────
  test('class power ranking at +2', () {
    sim.reportClassRanking(
      dungeon: 'windrunner_spire',
      level: 2,
      affixes: [],
    );
  });

  // ── Keystone scaling ─────────────────────────────────────────────────────
  test('keystone scaling +2 to +15', () {
    // Use null affixes = random affixes per run (realistic)
    sim.reportKeystoneScaling(
      comp: ['warrior', 'mage', 'priest', 'monk', 'hunter'],
      dungeon: 'windrunner_spire',
    );
  });

  // ── Keystone scaling (no affixes, pure HP test) ──────────────────────────
  test('keystone scaling — no affixes (pure HP curve)', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final levels = [2, 4, 6, 8, 10, 12, 15, 20];

    print('\n${'=' * 70}');
    print('KEYSTONE SCALING — Pure HP (no affixes), Windrunner Spire');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 70}');
    print('${'Level'.padRight(8)} ${'Clear%'.padRight(8)} ${'AvgLives'.padRight(10)} ${'AvgWaves'.padRight(10)}');
    print('-' * 70);

    for (final level in levels) {
      final r = sim.batch(
        comp: comp,
        dungeon: 'windrunner_spire',
        level: level,
        affixes: [], // no affixes
      );
      print('+$level'.padRight(8) +
          r.clearRateStr.padRight(8) +
          r.avgLives.toStringAsFixed(1).padRight(10) +
          r.avgWaves.toStringAsFixed(1).padRight(10));
    }
  });

  // ── Full dungeon × level matrix ──────────────────────────────────────────
  test('full matrix', () {
    sim.reportMatrix(
      comp: ['warrior', 'mage', 'priest', 'monk', 'hunter'],
      levels: [2, 5, 7, 10],
    );
  });

  // ── Comp comparison ──────────────────────────────────────────────────────
  test('comp comparison — Murder Row +5', () {
    sim.reportCompComparison(
      comps: {
        'All Melee': ['warrior', 'monk', 'rogue', 'death knight', 'demon hunter'],
        'All Ranged': ['mage', 'hunter', 'warlock', 'evoker', 'hunter'],
        'Balanced': ['warrior', 'mage', 'priest', 'monk', 'hunter'],
        'Support Heavy': ['priest', 'druid', 'warrior', 'monk', 'warrior'],
        'AOE Focus': ['shaman', 'warrior', 'hunter', 'priest', 'mage'],
        'Meta Stack': ['monk', 'priest', 'warrior', 'druid', 'hunter'],
      },
      dungeon: 'murder_row',
      level: 5,
      affixes: [TdAffix.fortified],
    );
  });

  // ── Affix impact ─────────────────────────────────────────────────────────
  test('affix impact — Magisters Terrace +7', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final dung = 'magisters_terrace';

    final affixSets = {
      'None': <TdAffix>[],
      'Fortified': [TdAffix.fortified],
      'Tyrannical': [TdAffix.tyrannical],
      'Fort+Burst': [TdAffix.fortified, TdAffix.bursting],
      'Fort+Bolster': [TdAffix.fortified, TdAffix.bolstering],
      'Tyran+Sang': [TdAffix.tyrannical, TdAffix.sanguine],
      'Tyran+Burst': [TdAffix.tyrannical, TdAffix.bursting],
    };

    print('\n${'=' * 60}');
    print('AFFIX IMPACT — +7, Magisters\' Terrace');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 60}');
    print('${'Affixes'.padRight(18)} ${'Clear%'.padRight(8)} ${'AvgLives'.padRight(10)} ${'AvgWaves'.padRight(10)}');
    print('-' * 60);

    for (final entry in affixSets.entries) {
      final r = sim.batch(
          comp: comp, dungeon: dung, level: 7, affixes: entry.value);
      print('${entry.key.padRight(18)} ${r.clearRateStr.padRight(8)} '
          '${r.avgLives.toStringAsFixed(1).padRight(10)} '
          '${r.avgWaves.toStringAsFixed(1).padRight(10)}');
    }
  });

  // ── Modifier intensification ──────────────────────────────────────────────
  test('modifier intensification — harder at +7 and +11', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];

    print('\n${'=' * 70}');
    print('MODIFIER INTENSIFICATION — Same dungeon, no affixes, scaling modifiers');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 70}');
    print('${'Dungeon'.padRight(28)} ${'  +2'.padRight(8)} ${'  +7'.padRight(8)} ${'  +11'.padRight(8)}');
    print('-' * 70);

    for (final key in ['magisters_terrace', 'windrunner_spire', 'pit_of_saron', 'seat_of_the_triumvirate']) {
      final row = StringBuffer(sim.findDungeon(key).name.padRight(28));
      for (final level in [2, 7, 11]) {
        final r = sim.batch(comp: comp, dungeon: key, level: level, affixes: [], runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(8));
      }
      print(row);
    }
  });

  // ── Paladin value in bursting ────────────────────────────────────────────
  test('paladin value in bursting weeks', () {
    sim.reportCompComparison(
      comps: {
        'With Paladin': ['warrior', 'paladin', 'priest', 'monk', 'hunter'],
        'Without Paladin': ['warrior', 'rogue', 'priest', 'monk', 'hunter'],
      },
      dungeon: 'windrunner_spire',
      level: 7,
      affixes: [TdAffix.fortified, TdAffix.bursting],
    );
  });
}
