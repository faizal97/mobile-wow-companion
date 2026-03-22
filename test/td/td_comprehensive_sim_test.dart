// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/models/td_models.dart';
import 'td_sim.dart';

void main() {
  late TdSim sim;

  setUpAll(() {
    sim = TdSim();
  });

  test('comprehensive balance — all dungeons +2 to +10 (no affixes)', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final levels = [2, 3, 4, 5, 6, 7, 8, 9, 10];

    print('\n${'=' * 100}');
    print('COMPREHENSIVE BALANCE — All dungeons × +2 to +10, NO AFFIXES');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 100}');

    final header = StringBuffer('Dungeon'.padRight(28));
    for (final lvl in levels) {
      header.write('+$lvl'.padLeft(8));
    }
    print(header);
    print('-' * 100);

    for (final key in sim.allDungeonKeys) {
      final dung = sim.dungeons[key]!;
      final row = StringBuffer(dung.name.padRight(28));
      for (final level in levels) {
        final r = sim.batch(
            comp: comp, dungeon: key, level: level, affixes: [], runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(8));
      }
      print(row);
    }
  });

  test('comprehensive balance — all dungeons +2 to +10 (with affixes)', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final levels = [2, 3, 4, 5, 6, 7, 8, 9, 10];

    print('\n${'=' * 100}');
    print('COMPREHENSIVE BALANCE — All dungeons × +2 to +10, WITH AFFIXES');
    print('Affixes: +2-3 none, +4-6 [Fort], +7-10 [Fort,Burst]');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 100}');

    final header = StringBuffer('Dungeon'.padRight(28));
    for (final lvl in levels) {
      header.write('+$lvl'.padLeft(8));
    }
    print(header);
    print('-' * 100);

    for (final key in sim.allDungeonKeys) {
      final dung = sim.dungeons[key]!;
      final row = StringBuffer(dung.name.padRight(28));
      for (final level in levels) {
        final affixes = level >= 7
            ? [TdAffix.fortified, TdAffix.bursting]
            : level >= 4
                ? [TdAffix.fortified]
                : <TdAffix>[];
        final r = sim.batch(
            comp: comp, dungeon: key, level: level, affixes: affixes, runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(8));
      }
      print(row);
    }
  });

  test('comprehensive balance — class power at +5 and +8', () {
    print('\n${'=' * 80}');
    print('CLASS POWER — 5x same class, no affixes');
    print('${'=' * 80}');
    print('${'Class'.padRight(18)} ${'Archetype'.padRight(10)} '
        '${'  +2'.padRight(8)} ${'  +5'.padRight(8)} ${'  +8'.padRight(8)}');
    print('-' * 80);

    for (final className in sim.allClasses) {
      final classDef = sim.classRegistry.getClass(className);
      final row = StringBuffer(className.padRight(18));
      row.write(classDef.archetype.name.padRight(10));

      for (final level in [2, 5, 8]) {
        final r = sim.batch(
          comp: List.filled(5, className),
          dungeon: 'windrunner_spire',
          level: level,
          affixes: [],
          runs: 10,
        );
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(8));
      }
      print(row);
    }
  });

  test('comprehensive balance — comp diversity at +7', () {
    final comps = {
      'All Melee':
          ['warrior', 'monk', 'rogue', 'death knight', 'demon hunter'],
      'All Ranged': ['mage', 'hunter', 'warlock', 'evoker', 'hunter'],
      'Balanced': ['warrior', 'mage', 'priest', 'monk', 'hunter'],
      'Support Meta': ['monk', 'priest', 'warrior', 'druid', 'hunter'],
      'AOE Heavy': ['shaman', 'warrior', 'hunter', 'priest', 'mage'],
      'Control': ['death knight', 'monk', 'priest', 'hunter', 'paladin'],
      'Burst': ['rogue', 'evoker', 'priest', 'mage', 'warrior'],
      '6-Tower (if +5)':
          ['warrior', 'monk', 'priest', 'hunter', 'mage', 'rogue'],
    };

    print('\n${'=' * 90}');
    print('COMP DIVERSITY — +7, no affixes, across 4 dungeons');
    print('${'=' * 90}');

    final dungeons = ['windrunner_spire', 'murder_row', 'magisters_terrace', 'pit_of_saron'];

    final header = StringBuffer('Comp'.padRight(20));
    for (final d in dungeons) {
      header.write(sim.findDungeon(d).shortName.padLeft(8));
    }
    print(header);
    print('-' * 90);

    for (final entry in comps.entries) {
      final row = StringBuffer(entry.key.padRight(20));
      for (final d in dungeons) {
        final r = sim.batch(
            comp: entry.value, dungeon: d, level: 7, affixes: [], runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(8));
      }
      print(row);
    }
  });

  test('comprehensive balance — affix combinations at +7', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final dungeon = 'windrunner_spire';

    final affixSets = {
      'None': <TdAffix>[],
      'Fort': [TdAffix.fortified],
      'Tyran': [TdAffix.tyrannical],
      'Bolster': [TdAffix.bolstering],
      'Burst': [TdAffix.bursting],
      'Sang': [TdAffix.sanguine],
      'Fort+Burst': [TdAffix.fortified, TdAffix.bursting],
      'Fort+Bolst': [TdAffix.fortified, TdAffix.bolstering],
      'Fort+Sang': [TdAffix.fortified, TdAffix.sanguine],
      'Tyran+Burst': [TdAffix.tyrannical, TdAffix.bursting],
      'Tyran+Sang': [TdAffix.tyrannical, TdAffix.sanguine],
    };

    print('\n${'=' * 60}');
    print('AFFIX COMBINATIONS — +7, Windrunner Spire');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 60}');
    print('${'Affixes'.padRight(16)} ${'Clear%'.padRight(8)} ${'AvgLives'.padRight(10)} ${'AvgWaves'.padRight(10)}');
    print('-' * 60);

    for (final entry in affixSets.entries) {
      final r = sim.batch(
          comp: comp, dungeon: dungeon, level: 7, affixes: entry.value, runs: 20);
      print('${entry.key.padRight(16)} ${r.clearRateStr.padRight(8)} '
          '${r.avgLives.toStringAsFixed(1).padRight(10)} '
          '${r.avgWaves.toStringAsFixed(1).padRight(10)}');
    }
  });
}
