import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:referee_phone/match_application/match_started_read_model.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('match_started_cutover_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('kick-off creates one MATCH_STARTED with allocated sequence', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();

    final result = await composition.boundary.commitMatchStarted(
      identity.contextFor('match-1'),
    );

    expect(result, isA<DurableCommitSuccess>());
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records, hasLength(1));
    expect(records.single.recordKind, RecordKind.temporalFact);
    expect(records.single.originSequence, 1);
    expect(
      (records.single.payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.matchStarted,
    );
    expect(records.single.authorityContext!.scope, isA<MainRefereeScope>());
    expect(
      records.single.authorityContext!.principal!.principalId,
      identity.authorityPrincipalId,
    );
  });

  test('second MATCH_STARTED fails closed and does not consume a sequence', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final context = identity.contextFor('match-1');

    expect(
      await composition.boundary.commitMatchStarted(context),
      isA<DurableCommitSuccess>(),
    );
    final second = await composition.boundary.commitMatchStarted(context);

    expect(second, isA<DurableCommitFailure>());
    expect((second as DurableCommitFailure).reason, contains('MATCH_STARTED'));
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records, hasLength(1));
    expect(records.single.originSequence, 1);
  });

  test('failed kick-off leaves no started projection', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      throw StateError('abort before commit');
    };

    final result = await composition.boundary.commitMatchStarted(
      identity.contextFor('match-1'),
    );

    expect(result, isA<DurableCommitFailure>());
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    final projection = await composition.boundary.project(
      'match-1',
      evaluatedAuthorityGeneration: PhoneCaptureIdentity.initialAuthorityGeneration,
    );
    expect(
      MatchStartedReadModel.from(projection: projection, records: records)
          .authoritativelyStarted,
      isFalse,
    );
  });

  test('reopen reconstructs trusted started projection', () async {
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final first = await MatchApplicationComposition.open(storageRoot: temp);
    expect(
      await first.boundary.commitMatchStarted(identity.contextFor('match-1')),
      isA<DurableCommitSuccess>(),
    );
    await first.close();

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final records = await reopened.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    final projection = await reopened.boundary.project(
      'match-1',
      evaluatedAuthorityGeneration: PhoneCaptureIdentity.initialAuthorityGeneration,
    );

    expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.trusted);
    final model = MatchStartedReadModel.from(
      projection: projection,
      records: records,
    );
    expect(model.authoritativelyStarted, isTrue);
    expect(model.activePeriod, isNull);
    expect(model.temporallyIncomplete, isTrue);
  });

  test('kick-off commits MATCH_STARTED then PERIOD_STARTED in sequence', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();

    final result = await composition.boundary.commitKickOff(
      identity.contextFor('match-1'),
      period: const PeriodIdentity(index: 1),
    );

    expect(result, isA<KickOffAuthorityCommitted>());
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records.map((record) => record.originSequence).toList(), [1, 2]);
    expect(
      (records[0].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.matchStarted,
    );
    final period = records[1].payload as TemporalTransitionPayload;
    expect(period.semanticType, V1SemanticTypeCode.periodStarted);
    expect(period.period, const PeriodIdentity(index: 1));
    expect(records[1].relationships.single, isA<CausalDependency>());
    expect(
      (records[1].relationships.single as CausalDependency).targetRecordId,
      records[0].recordId,
    );
  });

  test('period failure keeps MATCH_STARTED and retry writes only the period', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final context = identity.contextFor('match-1');
    var commits = 0;
    composition.boundary.durableStore.abortBeforeCommitForTest = () {
      commits += 1;
      if (commits > 1) throw StateError('abort period start');
    };

    final partial = await composition.boundary.commitKickOff(
      context,
      period: const PeriodIdentity(index: 1),
    );

    expect(partial, isA<KickOffMatchStartedIncomplete>());
    final afterPartial = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(afterPartial, hasLength(1));
    expect(afterPartial.single.originSequence, 1);
    final partialModel = await _model(composition);
    expect(partialModel.authoritativelyStarted, isTrue);
    expect(partialModel.activePeriod, isNull);
    expect(partialModel.temporallyIncomplete, isTrue);

    composition.boundary.durableStore.abortBeforeCommitForTest = null;
    final recovered = await composition.boundary.commitKickOff(
      context,
      period: const PeriodIdentity(index: 1),
    );

    expect(recovered, isA<KickOffAuthorityCommitted>());
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records, hasLength(2));
    expect(records[1].originSequence, 2);
    expect(
      (records[1].payload as TemporalTransitionPayload).semanticType,
      V1SemanticTypeCode.periodStarted,
    );
    final model = await _model(composition);
    expect(model.activePeriod, const PeriodIdentity(index: 1));
    expect(model.temporallyIncomplete, isFalse);
  });

  test('reopen after both commits reconstructs period 1', () async {
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final first = await MatchApplicationComposition.open(storageRoot: temp);
    expect(
      await first.boundary.commitKickOff(
        identity.contextFor('match-1'),
        period: const PeriodIdentity(index: 1),
      ),
      isA<KickOffAuthorityCommitted>(),
    );
    await first.close();

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final model = await _model(reopened);
    expect(model.authoritativelyStarted, isTrue);
    expect(model.activePeriod, const PeriodIdentity(index: 1));
    expect(model.temporallyIncomplete, isFalse);
  });

  test('reopen after MATCH_STARTED only stays incomplete', () async {
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final first = await MatchApplicationComposition.open(storageRoot: temp);
    expect(
      await first.boundary.commitMatchStarted(identity.contextFor('match-1')),
      isA<DurableCommitSuccess>(),
    );
    await first.close();

    final reopened = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(reopened.close);
    final model = await _model(reopened);
    expect(model.authoritativelyStarted, isTrue);
    expect(model.activePeriod, isNull);
    expect(model.temporallyIncomplete, isTrue);
  });

  test('duplicate kick-off does not write a second start or period', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final context = identity.contextFor('match-1');

    expect(
      await composition.boundary.commitKickOff(
        context,
        period: const PeriodIdentity(index: 1),
      ),
      isA<KickOffAuthorityCommitted>(),
    );
    final second = await composition.boundary.commitKickOff(
      context,
      period: const PeriodIdentity(index: 1),
    );

    expect(second, isA<KickOffAlreadyStarted>());
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records, hasLength(2));
    expect(records.map((record) => record.originSequence).toList(), [1, 2]);
  });

  test('PERIOD_STARTED without MATCH_STARTED fails closed', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();

    final result = await composition.boundary.commitPeriodStarted(
      identity.contextFor('match-1'),
      period: const PeriodIdentity(index: 1),
      matchStartedRecordId: 'missing-start',
    );

    expect(result, isA<DurableCommitFailure>());
    expect(
      (result as DurableCommitFailure).reason,
      contains('MATCH_STARTED'),
    );
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records, isEmpty);
  });

  test('PERIOD_STARTED with the wrong start id fails closed', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final context = identity.contextFor('match-1');
    expect(
      await composition.boundary.commitMatchStarted(context),
      isA<DurableCommitSuccess>(),
    );

    final result = await composition.boundary.commitPeriodStarted(
      context,
      period: const PeriodIdentity(index: 1),
      matchStartedRecordId: 'other-start',
    );

    expect(result, isA<DurableCommitFailure>());
    expect((result as DurableCommitFailure).reason, contains('dependency'));
    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records, hasLength(1));
  });

  test('recordedAt does not choose sporting order', () async {
    final composition = await MatchApplicationComposition.open(storageRoot: temp);
    addTearDown(composition.close);
    final identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    final early = DateTime.utc(2026, 1, 1);
    final late = DateTime.utc(2026, 12, 31);

    await composition.boundary.captureAndCommit(
      _command(identity, recordedAt: late, code: V1SemanticTypeCode.periodEnded),
    );
    await composition.boundary.captureAndCommit(
      _command(identity, recordedAt: early, code: V1SemanticTypeCode.periodStarted),
    );

    final records = await composition.boundary.durableStore.readCommittedForMatch(
      'match-1',
    );
    expect(records.map((record) => record.originSequence).toList(), [1, 2]);
    expect(records.first.recordedAt.isAfter(records.last.recordedAt), isTrue);
  });

  test('phone capture identity is stable and not a display name', () async {
    final store = PhoneCaptureIdentityStore(temp);
    final first = await store.loadOrCreate();
    final second = await store.loadOrCreate();

    expect(second.originDeviceId, first.originDeviceId);
    expect(second.authorityPrincipalId, first.authorityPrincipalId);
    expect(first.authorityPrincipalId, isNot(contains(' ')));
  });

  test('kick-off UI path does not call legacy kickOff', () {
    final page = File('lib/features/live_match/live_match_page.dart')
        .readAsStringSync();
    expect(page, contains('commitKickOff'));
    expect(page, isNot(contains('commitMatchStarted')));
    expect(page, isNot(contains('session.kickOff')));
    expect(page, isNot(contains('.kickOff(')));
    final session = File('lib/match/match_session.dart').readAsStringSync();
    expect(session, contains('applyKickOff'));
  });
}

Future<MatchStartedReadModel> _model(
  MatchApplicationComposition composition,
) async {
  final records = await composition.boundary.durableStore.readCommittedForMatch(
    'match-1',
  );
  final projection = await composition.boundary.project(
    'match-1',
    evaluatedAuthorityGeneration: PhoneCaptureIdentity.initialAuthorityGeneration,
  );
  return MatchStartedReadModel.from(projection: projection, records: records);
}

AuthoritativeCaptureCommand _command(
  PhoneCaptureIdentity identity, {
  required DateTime recordedAt,
  required V1SemanticTypeCode code,
}) {
  return AuthoritativeCaptureCommand(
    context: identity.contextFor('match-1'),
    recordKind: RecordKind.temporalFact,
    payload: TemporalTransitionPayload(
      semanticType: code,
      period: code == V1SemanticTypeCode.periodStarted ||
              code == V1SemanticTypeCode.periodEnded
          ? const PeriodIdentity(index: 1)
          : null,
    ),
    integrity: const IntegrityMetadata(),
    recordedAt: recordedAt,
  );
}
