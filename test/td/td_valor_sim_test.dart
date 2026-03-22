// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:wow_warband_companion/td/models/td_models.dart';
import 'td_sim.dart';

void main() {
  late TdSim sim;

  setUpAll(() {
    sim = TdSim();
  });

  test('valor upgrades impact — sharpen progression', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final levels = [2, 4, 6, 7, 8, 9, 10];

    print('\n${'=' * 95}');
    print('SHARPEN UPGRADE IMPACT — Windrunner Spire, no affixes');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 95}');

    final header = StringBuffer('Upgrade'.padRight(20));
    for (final lvl in levels) {
      header.write('+$lvl'.padLeft(9));
    }
    print(header);
    print('-' * 95);

    final configs = {
      'No upgrades': 0,
      'Sharpen x1 (+15%)': 1,
      'Sharpen x2 (+30%)': 2,
      'Sharpen x3 (+45%)': 3,
    };

    for (final entry in configs.entries) {
      final row = StringBuffer(entry.key.padRight(20));
      for (final level in levels) {
        final runState = entry.value > 0
            ? sim.makeRunState(comp: comp, level: level, sharpenAll: entry.value)
            : null;
        final r = sim.batch(
            comp: comp, dungeon: 'windrunner_spire', level: level,
            affixes: [], runState: runState, runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(9));
      }
      print(row);
    }
  });

  test('valor upgrades impact — fortify saves lives', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];

    print('\n${'=' * 80}');
    print('FORTIFY UPGRADE IMPACT — +8, no affixes, across dungeons');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 80}');
    print('${'Dungeon'.padRight(28)} ${'No Fort'.padRight(12)} ${'With Fort'.padRight(12)} ${'Diff'.padRight(8)}');
    print('-' * 80);

    for (final key in sim.allDungeonKeys) {
      final dung = sim.dungeons[key]!;
      final rNone = sim.batch(comp: comp, dungeon: key, level: 8, affixes: [], runs: 10);
      final runState = sim.makeRunState(comp: comp, level: 8, fortifyAll: true);
      final rFort = sim.batch(comp: comp, dungeon: key, level: 8, affixes: [], runState: runState, runs: 10);
      final diff = rFort.avgLives - rNone.avgLives;
      print('${dung.name.padRight(28)} '
          '${rNone.avgLives.toStringAsFixed(1).padRight(12)} '
          '${rFort.avgLives.toStringAsFixed(1).padRight(12)} '
          '${diff >= 0 ? "+${diff.toStringAsFixed(1)}" : diff.toStringAsFixed(1)}');
    }
  });

  test('valor upgrades impact — empower passive enhancement', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final levels = [6, 7, 8, 9, 10];

    print('\n${'=' * 80}');
    print('EMPOWER UPGRADE IMPACT — Windrunner Spire, no affixes');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 80}');

    final header = StringBuffer('Upgrade'.padRight(22));
    for (final lvl in levels) {
      header.write('+$lvl'.padLeft(10));
    }
    print(header);
    print('-' * 80);

    final configs = {
      'No upgrades': (s: 0, f: false, e: false),
      'Empower only': (s: 0, f: false, e: true),
      'Sharpen x3 only': (s: 3, f: false, e: false),
      'Sharpen x3 + Empower': (s: 3, f: false, e: true),
      'All upgrades (S3+F+E)': (s: 3, f: true, e: true),
    };

    for (final entry in configs.entries) {
      final cfg = entry.value;
      final row = StringBuffer(entry.key.padRight(22));
      for (final level in levels) {
        final runState = (cfg.s > 0 || cfg.f || cfg.e)
            ? sim.makeRunState(comp: comp, level: level,
                sharpenAll: cfg.s, fortifyAll: cfg.f, empowerAll: cfg.e)
            : null;
        final r = sim.batch(
            comp: comp, dungeon: 'windrunner_spire', level: level,
            affixes: [], runState: runState, runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(10));
      }
      print(row);
    }
  });

  test('valor upgrades — can upgrades push through the +7 affix wall?', () {
    final comp = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final affixes = [TdAffix.fortified, TdAffix.bursting];

    print('\n${'=' * 90}');
    print('CAN UPGRADES BREAK THE +7 AFFIX WALL? — [Fortified, Bursting]');
    print('Comp: ${comp.join(', ')}');
    print('${'=' * 90}');
    print('${'Upgrade'.padRight(24)} ${'WS'.padRight(10)} ${'MR'.padRight(10)} '
        '${'MC'.padRight(10)} ${'PS'.padRight(10)} ${'SR'.padRight(10)}');
    print('-' * 90);

    final dungeons = ['windrunner_spire', 'murder_row', 'maisara_caverns', 'pit_of_saron', 'skyreach'];
    final configs = {
      'No upgrades': (s: 0, f: false, e: false),
      'Sharpen x1': (s: 1, f: false, e: false),
      'Sharpen x2': (s: 2, f: false, e: false),
      'Sharpen x3': (s: 3, f: false, e: false),
      'S3 + Fortify': (s: 3, f: true, e: false),
      'S3 + Empower': (s: 3, f: false, e: true),
      'S3 + Fort + Empower': (s: 3, f: true, e: true),
    };

    for (final entry in configs.entries) {
      final cfg = entry.value;
      final row = StringBuffer(entry.key.padRight(24));
      for (final d in dungeons) {
        final runState = (cfg.s > 0 || cfg.f || cfg.e)
            ? sim.makeRunState(comp: comp, level: 7,
                sharpenAll: cfg.s, fortifyAll: cfg.f, empowerAll: cfg.e)
            : null;
        final r = sim.batch(
            comp: comp, dungeon: d, level: 7,
            affixes: affixes, runState: runState, runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(10));
      }
      print(row);
    }
  });

  test('valor upgrades — 6 towers + upgrades at +7 and +10', () {
    final comp5 = ['warrior', 'mage', 'priest', 'monk', 'hunter'];
    final comp6 = ['warrior', 'mage', 'priest', 'monk', 'hunter', 'rogue'];

    print('\n${'=' * 80}');
    print('6TH TOWER + UPGRADES — Windrunner Spire, no affixes');
    print('${'=' * 80}');
    print('${'Setup'.padRight(30)} ${'  +7'.padRight(10)} ${'  +8'.padRight(10)} '
        '${'  +9'.padRight(10)} ${'  +10'.padRight(10)}');
    print('-' * 80);

    final configs = <String, (List<String>, int, bool, bool)>{
      '5 towers, no upgrades': (comp5, 0, false, false),
      '5 towers, S3+F+E': (comp5, 3, true, true),
      '6 towers, no upgrades': (comp6, 0, false, false),
      '6 towers, S3': (comp6, 3, false, false),
      '6 towers, S3+F+E': (comp6, 3, true, true),
    };

    for (final entry in configs.entries) {
      final (comp, sharpen, fort, emp) = entry.value;
      final row = StringBuffer(entry.key.padRight(30));
      for (final level in [7, 8, 9, 10]) {
        final runState = (sharpen > 0 || fort || emp)
            ? sim.makeRunState(comp: comp, level: level,
                sharpenAll: sharpen, fortifyAll: fort, empowerAll: emp)
            : null;
        final r = sim.batch(
            comp: comp, dungeon: 'windrunner_spire', level: level,
            affixes: [], runState: runState, runs: 10);
        row.write('${r.avgLives.toStringAsFixed(0)}hp'.padLeft(10));
      }
      print(row);
    }
  });
}
