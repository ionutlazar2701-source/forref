import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const matchId = 'match-1';
  final person = MatchParticipantId('person-a');
  final other = MatchParticipantId('person-b');
  final official = MatchTeamOfficialId('official-7');
  final participant = ParticipantDisciplinarySubject(person);
  final officialSubject = TeamOfficialDisciplinarySubject(official);

  MatchRecord record({
    required String recordId,
    required int originSequence,
    required RecordKind recordKind,
    required MatchRecordPayload payload,
    List<RecordRelationship> relationships = const [],
  }) {
    return MatchRecord(
      recordId: recordId,
      matchId: matchId,
      recordKind: recordKind,
      schemaVersion: 1,
      recordedAt: DateTime.utc(2026, 10, 2, 12, originSequence),
      originDeviceId: 'dev-a',
      originSequence: originSequence,
      authorityContext: const AuthorityContext(
        scope: MainRefereeScope(),
        principal: AuthorityPrincipal(principalId: 'ref-1'),
        generation: AuthorityGeneration(value: 1),
      ),
      payload: payload,
      integrity: IntegrityMetadata(evidenceRefs: [recordId]),
      relationships: relationships,
    );
  }

  MatchRecord yellow({
    required String recordId,
    required int originSequence,
    required DisciplinarySubjectRef subject,
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    String intent = 'intent-y',
  }) {
    final payload = subject is ParticipantDisciplinarySubject
        ? YellowCardPayload(
            participantId: subject.participantId,
            accountingScope: scope,
            captureIntentId: intent,
          )
        : YellowCardPayloadV2(
            disciplinarySubject: subject,
            accountingScope: scope,
            captureIntentId: intent,
          );
    return record(
      recordId: recordId,
      originSequence: originSequence,
      recordKind: RecordKind.humanDetermination,
      payload: payload,
    );
  }

  MatchRecord sendOff({
    required String recordId,
    required int originSequence,
    required DisciplinarySubjectRef subject,
    required SendOffPathway pathway,
    String? first,
    String? second,
    DisciplinaryAccountingScope scope = DisciplinaryAccountingScope.match,
    String intent = 'intent-send',
  }) {
    return record(
      recordId: recordId,
      originSequence: originSequence,
      recordKind: RecordKind.humanDetermination,
      relationships: pathway == SendOffPathway.direct
          ? const []
          : [
              CausalDependency(targetRecordId: first!),
              CausalDependency(targetRecordId: second!),
            ],
      payload: SendOffPayload(
        disciplinarySubject: subject,
        disciplinaryScope: scope,
        pathway: pathway,
        captureIntentId: intent,
        firstStandingCautionRecordId: first,
        secondCautionRecordId: second,
      ),
    );
  }

  EffectiveSendOffSet resolve(List<MatchRecord> records) {
    final resolution = resolveEffectiveSendOffs(
      recordsById: {for (final item in records) item.recordId: item},
    );
    expect(resolution, isA<EffectiveSendOffSet>());
    return resolution as EffectiveSendOffSet;
  }

  test('two yellow records create zero SEND_OFF records', () {
    final records = [
      yellow(
        recordId: 'y1',
        originSequence: 1,
        subject: participant,
        intent: 'intent-1',
      ),
      yellow(
        recordId: 'y2',
        originSequence: 2,
        subject: participant,
        intent: 'intent-2',
      ),
    ];
    expect(records.where((item) => item.payload is SendOffPayload), isEmpty);
    expect(resolve(records).sendOffs, isEmpty);
  });

  test('direct participant SEND_OFF does not require a yellow', () {
    final resolved = resolve([
      sendOff(
        recordId: 'so-1',
        originSequence: 1,
        subject: participant,
        pathway: SendOffPathway.direct,
      ),
    ]);
    expect(resolved.sendOffs, hasLength(1));
    expect(resolved.sendOffs.single.pathway, SendOffPathway.direct);
    expect(resolved.sendOffs.single.legallyEffective, isTrue);
    expect(
      resolved.sendOffs.single.dependencyStatus,
      SendOffDependencyStatus.ready,
    );
  });

  test('direct team-official SEND_OFF is explicit', () {
    final resolved = resolve([
      sendOff(
        recordId: 'so-off',
        originSequence: 1,
        subject: officialSubject,
        pathway: SendOffPathway.direct,
      ),
    ]);
    expect(resolved.sendOffs.single.subject, officialSubject);
    expect(
      resolved.sendOffs.single.subject,
      isNot(ParticipantDisciplinarySubject(MatchParticipantId('official-7'))),
    );
  });

  test('second-caution SEND_OFF requires the named yellow roles', () {
    final records = [
      yellow(recordId: 'y1', originSequence: 1, subject: participant, intent: 'a'),
      yellow(recordId: 'y2', originSequence: 2, subject: participant, intent: 'b'),
      sendOff(
        recordId: 'so-2',
        originSequence: 3,
        subject: participant,
        pathway: SendOffPathway.secondCaution,
        first: 'y1',
        second: 'y2',
      ),
    ];
    final resolved = resolve(records);
    expect(resolved.sendOffs, hasLength(1));
    expect(resolved.sendOffs.single.dependencyStatus, SendOffDependencyStatus.ready);
    expect(records.where((item) => item.payload is YellowCardPayload), hasLength(2));
  });

  test('second-caution team-official SEND_OFF uses the official subject', () {
    final records = [
      yellow(
        recordId: 'y1',
        originSequence: 1,
        subject: officialSubject,
        intent: 'a',
      ),
      yellow(
        recordId: 'y2',
        originSequence: 2,
        subject: officialSubject,
        intent: 'b',
      ),
      sendOff(
        recordId: 'so-off',
        originSequence: 3,
        subject: officialSubject,
        pathway: SendOffPathway.secondCaution,
        first: 'y1',
        second: 'y2',
      ),
    ];
    expect(
      resolve(records).sendOffs.single.dependencyStatus,
      SendOffDependencyStatus.ready,
    );
  });

  test('missing, same, mismatched, and non-yellow dependencies fail closed', () {
    expect(
      () => SendOffPayload(
        disciplinarySubject: participant,
        disciplinaryScope: DisciplinaryAccountingScope.match,
        pathway: SendOffPathway.secondCaution,
        captureIntentId: 'intent-send',
        firstStandingCautionRecordId: 'y1',
        secondCautionRecordId: 'y1',
      ),
      throwsA(isA<AssertionError>()),
    );

    final missing = resolve([
      sendOff(
        recordId: 'so-missing',
        originSequence: 1,
        subject: participant,
        pathway: SendOffPathway.secondCaution,
        first: 'y1',
        second: 'y2',
      ),
    ]);
    expect(
      missing.sendOffs.single.dependencyStatus,
      SendOffDependencyStatus.unavailable,
    );

    final mismatch = resolve([
      yellow(recordId: 'y1', originSequence: 1, subject: participant, intent: 'a'),
      yellow(
        recordId: 'y2',
        originSequence: 2,
        subject: ParticipantDisciplinarySubject(other),
        intent: 'b',
      ),
      sendOff(
        recordId: 'so-mis',
        originSequence: 3,
        subject: participant,
        pathway: SendOffPathway.secondCaution,
        first: 'y1',
        second: 'y2',
      ),
    ]);
    expect(
      mismatch.sendOffs.single.dependencyStatus,
      SendOffDependencyStatus.unavailable,
    );

    final wrongScope = resolve([
      yellow(recordId: 'y1', originSequence: 1, subject: participant, intent: 'a'),
      yellow(
        recordId: 'y2',
        originSequence: 2,
        subject: participant,
        intent: 'b',
        scope: DisciplinaryAccountingScope.shootout,
      ),
      sendOff(
        recordId: 'so-scope',
        originSequence: 3,
        subject: participant,
        pathway: SendOffPathway.secondCaution,
        first: 'y1',
        second: 'y2',
      ),
    ]);
    expect(
      wrongScope.sendOffs.single.dependencyStatus,
      SendOffDependencyStatus.unavailable,
    );

    final notYellow = [
      record(
        recordId: 'y1',
        originSequence: 1,
        recordKind: RecordKind.humanDetermination,
        payload: GoalPayload(
          scoringTeamId: MatchTeamId('team-alpha'),
          captureIntentId: 'goal-1',
        ),
      ),
      yellow(recordId: 'y2', originSequence: 2, subject: participant, intent: 'b'),
      sendOff(
        recordId: 'so-goal',
        originSequence: 3,
        subject: participant,
        pathway: SendOffPathway.secondCaution,
        first: 'y1',
        second: 'y2',
      ),
    ];
    expect(
      resolve(notYellow).sendOffs.single.dependencyStatus,
      SendOffDependencyStatus.unavailable,
    );
  });

  test('superseding a yellow does not delete SEND_OFF history', () {
    final records = [
      yellow(recordId: 'y1', originSequence: 1, subject: participant, intent: 'a'),
      yellow(recordId: 'y2', originSequence: 2, subject: participant, intent: 'b'),
      sendOff(
        recordId: 'so-2',
        originSequence: 3,
        subject: participant,
        pathway: SendOffPathway.secondCaution,
        first: 'y1',
        second: 'y2',
      ),
      record(
        recordId: 'void-y1',
        originSequence: 4,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'y1')],
      ),
    ];
    final resolved = resolve(records);
    expect(records.where((item) => item.payload is SendOffPayload), hasLength(1));
    expect(resolved.sendOffs.single.legallyEffective, isTrue);
    expect(resolved.sendOffs.single.sendOffRecordId, 'so-2');
  });

  test('superseding the SEND_OFF clears legal effect and keeps the record', () {
    final records = [
      sendOff(
        recordId: 'so-1',
        originSequence: 1,
        subject: participant,
        pathway: SendOffPathway.direct,
      ),
      record(
        recordId: 'void-so',
        originSequence: 2,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [LegalSupersessionTarget(targetRecordId: 'so-1')],
      ),
    ];
    final resolved = resolve(records);
    expect(resolved.sendOffs, hasLength(1));
    expect(resolved.sendOffs.single.legallyEffective, isFalse);
  });

  test('a correction cycle fails closed', () {
    final records = [
      record(
        recordId: 'c1',
        originSequence: 1,
        recordKind: RecordKind.correction,
        payload: CorrectionPayload(
          repairedDisciplinarySubject: participant,
        ),
        relationships: [CorrectionTarget(targetRecordId: 'c2')],
      ),
      record(
        recordId: 'c2',
        originSequence: 2,
        recordKind: RecordKind.correction,
        payload: CorrectionPayload(
          repairedDisciplinarySubject: participant,
        ),
        relationships: [CorrectionTarget(targetRecordId: 'c1')],
      ),
    ];
    expect(
      resolveEffectiveSendOffs(
        recordsById: {for (final item in records) item.recordId: item},
      ),
      isA<EffectiveSendOffUnavailable>(),
    );
  });
}
