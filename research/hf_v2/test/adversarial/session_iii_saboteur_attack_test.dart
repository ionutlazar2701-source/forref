import 'dart:io';

import 'package:hf_v2/hf_v2.dart';
import 'package:test/test.dart';

void main() {
  test('BANK H isolation: saves do not write production memory', () {
    final yellow = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior);
    yellow.offerRecordYellow();
    _tap(yellow, 20, 190);
    yellow.resolveSimulatedCommit();
    expect(yellow.commitKind, SystemCommitKind.saved);
    expect(yellow.cautions, hasLength(1));
    expect(yellow.productionMatchMemoryWrites, isFalse);
    expect(yellow.claimsProductionRecovery, isFalse);

    final direct = ResearchInstrument()
      ..loadScenario(ScenarioId.s08DirectRedWithPriorYellow);
    direct.offerDirectSendOff();
    _tap(direct, 230, 190);
    direct.resolveSimulatedCommit();
    expect(direct.sendOffs, hasLength(1));
    expect(direct.productionMatchMemoryWrites, isFalse);
    expect(direct.claimsProductionRecovery, isFalse);

    final second = ResearchInstrument()
      ..loadScenario(ScenarioId.s05Y2SendOffContinuation);
    second.offerRecordYellow();
    _tap(second, 20, 190);
    second.resolveSimulatedCommit();
    second.accessibilityInvoke(FinalActionKind.recordSecondCautionSendOff);
    second.resolveSimulatedCommit();
    expect(second.sendOffs, hasLength(1));
    expect(second.productionMatchMemoryWrites, isFalse);
    expect(second.claimsProductionRecovery, isFalse);

    final restart = ResearchInstrument()
      ..loadScenario(ScenarioId.s17FinishLaterSimulatedRestart);
    expect(restart.recoveryBanner, 'SIMULATED RECOVERY BEHAVIOR');
    expect(restart.commitKind, SystemCommitKind.saveNotVerified);
    expect(restart.commitKind, isNot(SystemCommitKind.saved));
    expect(restart.commitKind, isNot(SystemCommitKind.notSaved));
    expect(restart.claimsProductionRecovery, isFalse);
    expect(restart.productionMatchMemoryWrites, isFalse);
    expect(restart.simulatedRecoveryDisclaimer, isTrue);

    final forbidden = [
      'forref_match_persistence',
      'forref_match_core',
      'package:match_core',
      'DurableCommitPort',
      'SqliteDurableMatchStore',
    ];
    final hits = <String>[];
    for (final root in [Directory('lib'), Directory('../hf_prototype/lib')]) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        for (final token in forbidden) {
          if (text.contains(token)) hits.add('${entity.path}: $token');
        }
      }
    }
    expect(hits, isEmpty);
    final phone = Directory('../../apps/referee_phone/lib');
    final phoneHits = <String>[];
    for (final entity in phone.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (text.contains('hf_v2') || text.contains('hf_prototype')) {
        phoneHits.add(entity.path);
      }
    }
    expect(phoneHits, isEmpty);
  });

  test('BANK I state: identity, caution knowledge, pathway, scope', () {
    final homeAway = ResearchInstrument()
      ..loadScenario(ScenarioId.s09Home14ThenAway14);
    expect(homeAway.selectedParticipantId, 'p-home-14');
    homeAway.setTeam(ResearchTeamSide.away);
    expect(homeAway.selectionKind, SubjectSelectionKind.invalidated);
    expect(homeAway.selectedParticipantId, isNull);
    homeAway.selectParticipant('p-away-14');
    expect(homeAway.selectedParticipantId, 'p-away-14');
    expect(homeAway.selectedParticipantId, isNot('p-home-14'));
    expect(homeAway.selectedParticipant!.shirtLabel, '14');
    final homeShirt = homeAway.roster
        .firstWhere((person) => person.id == 'p-home-14')
        .shirtLabel;
    expect(homeShirt, homeAway.selectedParticipant!.shirtLabel);
    expect(homeAway.cautions, isEmpty);
    expect(homeAway.sendOffs, isEmpty);

    final unavailable = ResearchInstrument()
      ..loadScenario(ScenarioId.s03YellowPriorUnavailable);
    expect(unavailable.priorCaution, PriorCautionKnowledge.unavailable);
    expect(unavailable.priorCautionLabel, isNot('Known verified absence'));
    expect(
      unavailable.priorCautionLabel.toLowerCase(),
      isNot(contains('verified absence')),
    );

    final conflicted = ResearchInstrument()
      ..loadScenario(ScenarioId.s04YellowPriorConflicted);
    expect(conflicted.priorCaution, PriorCautionKnowledge.conflicted);
    expect(conflicted.priorCautionLabel, isNot('Known verified absence'));
    expect(
      conflicted.priorCautionLabel.toLowerCase(),
      isNot(contains('verified absence')),
    );

    final secondYellow = ResearchInstrument()
      ..loadScenario(ScenarioId.s02YellowOnePrior);
    expect(secondYellow.cautions, hasLength(1));
    secondYellow.offerRecordYellow();
    expect(secondYellow.twoCautionsRecorded, isFalse);
    expect(secondYellow.sendOffs, isEmpty);
    _tap(secondYellow, 20, 190);
    secondYellow.resolveSimulatedCommit();
    expect(secondYellow.twoCautionsRecorded, isTrue);
    expect(secondYellow.cautions, hasLength(2));
    expect(secondYellow.sendOffs, isEmpty);

    final direct = ResearchInstrument()
      ..loadScenario(ScenarioId.s08DirectRedWithPriorYellow);
    expect(direct.cautions, hasLength(1));
    _tap(direct, 230, 190);
    direct.resolveSimulatedCommit();
    expect(direct.sendOffs, isEmpty);
    direct.offerDirectSendOff();
    _tap(direct, 230, 190);
    direct.resolveSimulatedCommit();
    expect(direct.sendOffs, hasLength(1));
    expect(direct.sendOffs.single.pathway, SendOffPathwayLabel.direct);
    expect(
      direct.sendOffs
          .where((item) => item.pathway == SendOffPathwayLabel.secondCaution),
      isEmpty,
    );
    expect(direct.cautions, hasLength(1));

    final continuation = ResearchInstrument()
      ..loadScenario(ScenarioId.s05Y2SendOffContinuation);
    continuation.offerRecordYellow();
    _tap(continuation, 20, 190);
    continuation.resolveSimulatedCommit();
    expect(continuation.sendOffs, isEmpty);
    continuation.accessibilityInvoke(
      FinalActionKind.recordSecondCautionSendOff,
    );
    continuation.resolveSimulatedCommit();
    expect(continuation.sendOffs.single.pathway, SendOffPathwayLabel.secondCaution);

    final substitution = ResearchInstrument()
      ..loadScenario(ScenarioId.s12SubstitutionInFirst);
    substitution.selectIn('p-home-7');
    expect(substitution.substitutionRecorded, isFalse);
    expect(substitution.substitutionStage, SubstitutionStage.inOnly);
    expect(substitution.outId, isNull);
    expect(substitution.inId, 'p-home-7');
    substitution.selectOut('p-home-9');
    expect(substitution.substitutionRecorded, isFalse);
    expect(substitution.outId, 'p-home-9');
    expect(substitution.inId, 'p-home-7');
    substitution.interrupt();
    substitution.reorderRoster(['p-home-7', 'p-home-9', 'p-away-14']);
    expect(substitution.outId, 'p-home-9');
    expect(substitution.inId, 'p-home-7');
    expect(substitution.substitutionRecorded, isFalse);
    expect(substitution.substitutions, isEmpty);

    final unknown = ResearchInstrument()
      ..loadScenario(ScenarioId.s16SaveNotVerified);
    unknown.offerRecordYellow();
    _tap(unknown, 20, 190);
    unknown.resolveSimulatedCommit();
    expect(unknown.commitKind, SystemCommitKind.saveNotVerified);
    expect(unknown.commitKind, isNot(SystemCommitKind.saved));
    expect(unknown.commitKind, isNot(SystemCommitKind.notSaved));
    expect(unknown.cautions, isEmpty);
    expect(unknown.submitWhileUnverified(), isFalse);
    expect(unknown.cautions, isEmpty);
    expect(unknown.sendOffs, isEmpty);

    final shootout = ResearchInstrument()
      ..loadScenario(ScenarioId.s18MatchToShootout);
    final matchCount = shootout.savedCautionCount(
      'p-home-9',
      SubjectKind.participant,
      ResearchScope.match,
    );
    expect(matchCount, 1);
    shootout.setScope(ResearchScope.shootout);
    expect(
      shootout.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.match,
      ),
      matchCount,
    );
    expect(
      shootout.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.shootout,
      ),
      0,
    );
    expect(shootout.cautions, hasLength(1));
    expect(shootout.twoCautionsRecorded, isFalse);
  });

  test('BANK J safety: pointer reuse does not create a sending-off', () {
    final phone = ResearchLayout.phone;
    expect(phone.yellow.left, 16);
    expect(phone.yellow.top, 180);
    expect(phone.yellow.width, 150);
    expect(phone.yellow.height, 48);
    expect(phone.yellow.contains(20, 190), isTrue);
    expect(phone.sendOff.left, 220);
    expect(phone.sendOff.top, 180);
    expect(phone.sendOff.width, 160);
    expect(phone.sendOff.height, 48);
    expect(phone.sendOff.contains(230, 190), isTrue);
    expect(phone.yellow.overlaps(phone.sendOff), isFalse);

    final rapid = _ready();
    _tap(rapid, 20, 190);
    rapid.resolveSimulatedCommit();
    _tap(rapid, 20, 190, pointerId: 2);
    rapid.resolveSimulatedCommit();
    expect(rapid.twoCautionsRecorded, isTrue);
    expect(rapid.sendOffs, isEmpty);
    expect(
      rapid.log.where(
        (event) =>
            event.kind == ResearchLogKind.finalActionActivated &&
            event.detail.contains('SendOff'),
      ),
      isEmpty,
    );

    final oldPosition = _ready();
    _tap(oldPosition, 20, 190);
    oldPosition.resolveSimulatedCommit();
    expect(oldPosition.sendOffContinuationVisible, isTrue);
    _tap(oldPosition, 20, 190, pointerId: 2);
    oldPosition.resolveSimulatedCommit();
    expect(oldPosition.sendOffs, isEmpty);
    expect(oldPosition.lastActivated, FinalActionKind.recordYellow);

    final held = _ready();
    held.pointerDown(pointerId: 1, x: 20, y: 190);
    held.commitCapturedActionWhileHeld(1);
    held.resolveSimulatedCommit();
    expect(held.twoCautionsRecorded, isTrue);
    held.pointerUp(pointerId: 1, x: 230, y: 190);
    held.resolveSimulatedCommit();
    expect(held.sendOffs, isEmpty);

    final carried = _ready();
    carried.pointerDown(pointerId: 1, x: 20, y: 190);
    carried.pointerDown(pointerId: 2, x: 230, y: 190);
    carried.commitCapturedActionWhileHeld(1);
    carried.resolveSimulatedCommit();
    carried.pointerUp(pointerId: 2, x: 230, y: 190);
    carried.pointerUp(pointerId: 1, x: 20, y: 190);
    carried.resolveSimulatedCommit();
    expect(carried.twoCautionsRecorded, isTrue);
    expect(carried.sendOffs, isEmpty);

    final focus = _ready();
    focus.pointerDown(pointerId: 1, x: 20, y: 190);
    focus.focusLost();
    focus.pointerUp(pointerId: 1, x: 230, y: 190);
    focus.resolveSimulatedCommit();
    expect(focus.lastActivated, isNull);
    expect(focus.commitKind, SystemCommitKind.idle);
    expect(focus.sendOffs, isEmpty);
    expect(focus.cautions, hasLength(1));

    final still = _ready();
    still.relayout(ResearchLayout.phone);
    expect(still.lastActivated, isNull);
    expect(still.sendOffs, isEmpty);
    still.pointerDown(pointerId: 1, x: 20, y: 190);
    still.relayout(
      const ResearchLayout(
        yellow: ResearchRect(16, 180, 150, 48),
        sendOff: ResearchRect(16, 180, 150, 48),
        substitution: ResearchRect(16, 250, 200, 48),
        roster: ResearchRect(16, 8, 320, 150),
      ),
    );
    expect(still.lastActivated, isNull);
    expect(still.commitKind, SystemCommitKind.idle);
    expect(still.sendOffs, isEmpty);
    still.pointerUp(pointerId: 1, x: 20, y: 190);
    still.resolveSimulatedCommit();
    expect(still.sendOffs, isEmpty);
    expect(still.cautions, hasLength(2));

    final blocked = _ready();
    blocked.pointerDown(pointerId: 1, x: 20, y: 190);
    blocked.accessibilityInvoke(FinalActionKind.recordSecondCautionSendOff);
    expect(blocked.sendOffs, isEmpty);
    blocked.pointerCancel(pointerId: 1);
    expect(blocked.commitKind, SystemCommitKind.idle);
    expect(blocked.sendOffs, isEmpty);
  });

  test('BANK K recovery: unknown and restart stay unverified', () {
    final unknown = ResearchInstrument()..loadScenario(ScenarioId.s16SaveNotVerified);
    unknown.offerRecordYellow();
    _tap(unknown, 20, 190);
    unknown.resolveSimulatedCommit();
    expect(unknown.commitKind, SystemCommitKind.saveNotVerified);
    expect(unknown.commitLabel, isNot(contains('SIMULATED SAVED')));
    expect(unknown.commitLabel.toLowerCase(), isNot(contains('known simulated failure')));
    expect(unknown.cautions, isEmpty);
    expect(unknown.claimsProductionRecovery, isFalse);
    expect(unknown.submitWhileUnverified(), isFalse);

    final restart = ResearchInstrument()
      ..loadScenario(ScenarioId.s17FinishLaterSimulatedRestart);
    final seeded = restart.cautions.length;
    expect(restart.recoveryBanner, 'SIMULATED RECOVERY BEHAVIOR');
    expect(restart.commitKind, SystemCommitKind.saveNotVerified);
    restart.offerRecordYellow();
    _tap(restart, 20, 190);
    restart.resolveSimulatedCommit();
    expect(restart.commitKind, SystemCommitKind.saveNotVerified);
    expect(restart.commitKind, isNot(SystemCommitKind.saved));
    expect(restart.commitKind, isNot(SystemCommitKind.notSaved));
    expect(restart.cautions, hasLength(seeded));
    expect(restart.sendOffs, isEmpty);
    expect(restart.submitWhileUnverified(), isFalse);
    expect(restart.claimsProductionRecovery, isFalse);
    expect(restart.productionMatchMemoryWrites, isFalse);
    restart.acknowledgeUnknownOutcome();
    expect(restart.commitKind, isNot(SystemCommitKind.saved));
    expect(restart.cautions, hasLength(seeded));
    expect(restart.claimsProductionRecovery, isFalse);
  });

  test('BANK L scenarios: reload restores the opening instrument', () {
    expect(coreScenarios, hasLength(20));
    final instrument = ResearchInstrument();
    for (final id in ScenarioId.values) {
      instrument.loadScenario(id);
      expect(instrument.pitchTruth, isNotEmpty);
      expect(instrument.p0Failure, isNotEmpty);
      final opening = instrument.behaviorSignature;
      instrument.offerRecordYellow();
      instrument.offerDirectSendOff();
      instrument.selectIn('p-home-7');
      instrument.selectOut('p-home-9');
      instrument.interrupt();
      instrument.reorderRoster(['p-home-7', 'p-home-9']);
      instrument.reset();
      expect(instrument.behaviorSignature, opening, reason: id.name);
      expect(instrument.scenarioId, id);
      expect(instrument.productionMatchMemoryWrites, isFalse);
      expect(instrument.claimsProductionRecovery, isFalse);
    }
  });

  test('BANK M pack: simulated recovery, no production guarantee sentence', () {
    const names = [
      'RECOVERY_CAPABILITY_MATRIX.md',
      'RESEARCH_PROTOTYPE_SPEC.md',
      'FOUNDER_DIAGNOSTIC_PILOT.md',
    ];
    for (final name in names) {
      final text = _sessionDoc(name);
      expect(text, contains('SIMULATED RECOVERY BEHAVIOR'), reason: name);
      final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      expect(
        normalized.contains('production recovery is guaranteed'),
        isFalse,
        reason: name,
      );
    }
  });

  test('BRIDGE 1 isolation holds after subject and team changes', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s09Home14ThenAway14);
    instrument.setTeam(ResearchTeamSide.away);
    instrument.selectParticipant('p-away-14');
    instrument.offerRecordYellow();
    _tap(instrument, 20, 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.selectedParticipantId, 'p-away-14');
    expect(instrument.cautions.single.subjectId, 'p-away-14');
    expect(instrument.productionMatchMemoryWrites, isFalse);
    expect(instrument.claimsProductionRecovery, isFalse);
    expect(instrument.sendOffs, isEmpty);
  });

  test('BRIDGE 2 two recorded cautions do not send the player off', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s05Y2SendOffContinuation);
    instrument.offerRecordYellow();
    instrument.pointerDown(pointerId: 1, x: 20, y: 190);
    instrument.pointerUp(pointerId: 1, x: 230, y: 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.twoCautionsRecorded, isTrue);
    expect(instrument.sendingOffRecorded, isFalse);
    expect(instrument.sendOffs, isEmpty);
    expect(instrument.armedKind, isNull);
    instrument.pointerDown(pointerId: 2, x: 20, y: 190);
    instrument.pointerUp(pointerId: 2, x: 230, y: 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.sendOffs, isEmpty);
  });

  test('BRIDGE 3 unverified state survives scope and team changes', () {
    final restart = ResearchInstrument()
      ..loadScenario(ScenarioId.s17FinishLaterSimulatedRestart);
    restart.setTeam(ResearchTeamSide.away);
    restart.setScope(ResearchScope.shootout);
    restart.resolveSimulatedCommit();
    restart.interrupt();
    expect(restart.commitKind, SystemCommitKind.saveNotVerified);
    expect(restart.commitKind, isNot(SystemCommitKind.saved));
    expect(restart.commitKind, isNot(SystemCommitKind.notSaved));
    expect(restart.claimsProductionRecovery, isFalse);
    expect(restart.recoveryBanner, 'SIMULATED RECOVERY BEHAVIOR');
    expect(
      restart.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.shootout,
      ),
      0,
    );
    expect(restart.submitWhileUnverified(), isFalse);
  });

  test('BRIDGE 4 a finished scenario reload stays non-production', () {
    final instrument = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior);
    final opening = instrument.behaviorSignature;
    instrument.offerRecordYellow();
    _tap(instrument, 20, 190);
    instrument.resolveSimulatedCommit();
    expect(instrument.cautions, hasLength(1));
    instrument.markCompleted();
    instrument.reset();
    expect(instrument.behaviorSignature, opening);
    expect(instrument.cautions, isEmpty);
    expect(instrument.productionMatchMemoryWrites, isFalse);
    expect(
      instrument.log.map((event) => event.kind),
      contains(ResearchLogKind.scenarioStarted),
    );
  });

  test('BRIDGE 5 s17 label is the validation pack phrase', () {
    final instrument = ResearchInstrument()
      ..loadScenario(ScenarioId.s17FinishLaterSimulatedRestart);
    expect(instrument.recoveryBanner, 'SIMULATED RECOVERY BEHAVIOR');
    expect(instrument.commitKind, SystemCommitKind.saveNotVerified);
    for (final name in [
      'RECOVERY_CAPABILITY_MATRIX.md',
      'RESEARCH_PROTOTYPE_SPEC.md',
      'FOUNDER_DIAGNOSTIC_PILOT.md',
    ]) {
      expect(_sessionDoc(name), contains(instrument.recoveryBanner), reason: name);
      expect(
        _sessionDoc(name).toLowerCase(),
        isNot(contains('production recovery is guaranteed')),
        reason: name,
      );
    }
  });

  test('CROSS-BANK hostile: in-flight commit does not follow later edits', () {
    final problems = <String>[];

    final hollow = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    hollow.pointerDown(pointerId: 1, x: 20, y: 190);
    hollow.commitCapturedActionWhileHeld(1);
    expect(hollow.commitKind, SystemCommitKind.saving);
    expect(hollow.pendingAction, FinalActionKind.recordYellow);
    hollow.setTeam(ResearchTeamSide.away);
    hollow.resolveSimulatedCommit();
    final storedOriginal = hollow.cautions.any(
      (caution) => caution.subjectId == 'p-home-9',
    );
    if (hollow.commitKind == SystemCommitKind.saved && !storedOriginal) {
      problems.add(
        'team invalidation during a yellow commit reports Saved and stores no caution',
      );
    }

    final retarget = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    retarget.pointerDown(pointerId: 1, x: 20, y: 190);
    retarget.pointerUp(pointerId: 1, x: 20, y: 190);
    expect(retarget.commitKind, SystemCommitKind.saving);
    retarget.selectParticipant('p-home-14');
    retarget.resolveSimulatedCommit();
    if (retarget.cautions.any((caution) => caution.subjectId == 'p-home-14')) {
      problems.add(
        'a yellow activated for p-home-9 was stored on p-home-14',
      );
    }

    final scopeBleed = ResearchInstrument()..loadScenario(ScenarioId.s01YellowNoPrior)
      ..offerRecordYellow();
    scopeBleed.pointerDown(pointerId: 1, x: 20, y: 190);
    scopeBleed.pointerUp(pointerId: 1, x: 20, y: 190);
    expect(scopeBleed.commitKind, SystemCommitKind.saving);
    expect(scopeBleed.scope, ResearchScope.match);
    scopeBleed.setScope(ResearchScope.shootout);
    scopeBleed.resolveSimulatedCommit();
    final shootoutCount = scopeBleed.savedCautionCount(
      'p-home-9',
      SubjectKind.participant,
      ResearchScope.shootout,
    );
    if (shootoutCount > 0) {
      problems.add(
        'a yellow activated in match scope was filed on the shoot-out ledger',
      );
    }

    final substitution = ResearchInstrument()
      ..loadScenario(ScenarioId.s11SubstitutionOutFirst);
    substitution.selectOut('p-home-9');
    substitution.selectIn('p-home-7');
    substitution.pointerDown(pointerId: 1, x: 40, y: 260);
    substitution.pointerUp(pointerId: 1, x: 40, y: 260);
    expect(substitution.commitKind, SystemCommitKind.saving);
    expect(substitution.pendingAction, FinalActionKind.recordSubstitution);
    substitution.selectIn('p-home-14');
    substitution.resolveSimulatedCommit();
    if (substitution.commitKind == SystemCommitKind.saved) {
      final pair = substitution.substitutions;
      final exact = pair.length == 1 &&
          pair.single.outId == 'p-home-9' &&
          pair.single.inId == 'p-home-7';
      if (!exact) {
        problems.add(
          'the saved substitution is not the activated pair p-home-9 to p-home-7',
        );
      }
    } else if (substitution.substitutions.isNotEmpty) {
      problems.add('a substitution was stored without a saved commit');
    }

    expect(problems, isEmpty, reason: problems.join('; '));
  });
}

ResearchInstrument _ready() {
  return ResearchInstrument()
    ..loadScenario(ScenarioId.s07RapidRepeatAfterY2)
    ..offerRecordYellow();
}

void _tap(
  ResearchInstrument instrument,
  double x,
  double y, {
  int pointerId = 1,
}) {
  instrument.pointerDown(pointerId: pointerId, x: x, y: y);
  instrument.pointerUp(pointerId: pointerId, x: x, y: y);
}

String _sessionDoc(String name) {
  return File(
    '../../docs/forref-development/night-session-iii/$name',
  ).readAsStringSync();
}
