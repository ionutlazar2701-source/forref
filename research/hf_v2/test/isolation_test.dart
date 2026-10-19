import 'dart:io';

import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  test('research library does not import production authority', () {
    final root = Directory('lib');
    final forbidden = [
      'forref_match_persistence',
      'forref_match_core',
      'package:match_core',
      'DurableCommitPort',
      'SqliteDurableMatchStore',
      'match_session',
    ];
    final hits = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final token in forbidden) {
        if (text.contains(token)) hits.add('${entity.path}: $token');
      }
    }
    expect(hits, isEmpty);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('forref_match_persistence')));
    expect(pubspec, isNot(contains('forref_match_core')));
  });

  test('reset restores the deterministic opening state', () {
    final instrument = ResearchInstrument()..loadScenario(ScenarioId.s05Y2SendOffContinuation);
    final opening = instrument.behaviorSignature;
    instrument.offerRecordYellow();
    instrument.pointerDown(pointerId: 1, x: 20, y: 190);
    instrument.pointerUp(pointerId: 1, x: 20, y: 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.twoCautionsRecorded, isTrue);
    instrument.reset();
    expect(instrument.behaviorSignature, opening);
    expect(instrument.productionMatchMemoryWrites, isFalse);
    expect(instrument.sendOffs, isEmpty);
  });

  test('a research action writes no production flag', () {
    final instrument = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior);
    instrument.offerRecordYellow();
    _tap(instrument, 20, 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.commitKind, SystemCommitKind.saved);
    expect(instrument.commitLabel, contains('not production D1'));
    expect(instrument.productionMatchMemoryWrites, isFalse);
    expect(instrument.claimsProductionRecovery, isFalse);
  });
}

void _tap(ResearchInstrument instrument, double x, double y) {
  instrument.pointerDown(pointerId: 1, x: x, y: y);
  instrument.pointerUp(pointerId: 1, x: x, y: y);
}
