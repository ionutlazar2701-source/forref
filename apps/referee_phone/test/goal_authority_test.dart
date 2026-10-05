import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;
  late PhoneTemporalEvidenceStore evidence;
  late ManualGoalClock clock;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('goal_authority_');
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
    clock = ManualGoalClock();
    evidence = PhoneTemporalEvidenceStore(storageRoot: temp, clock: clock);
  });

  tearDown(() async {
    await composition.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  CaptureContext context() => identity.contextFor('match-1');

  Future<void> kickOff() async {
    final result = await composition.boundary.commitKickOff(
      context(),
      period: const PeriodIdentity(index: 1),
      periodAnchor: () async {
        final captured = await evidence.captureAnchor();
        return TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        );
      },
    );
    expect(result, isA<KickOffAuthorityCommitted>());
  }

  Future<DurableCommitResult> commitGoal({
    required CreditedSide side,
    required String intentId,
    TemporalContext? temporal,
  }) async {
    final captured = temporal == null ? await evidence.captureAnchor() : null;
    return composition.boundary.commitGoal(
      context(),
      creditedSide: side,
      captureIntentId: intentId,
      temporalContext: temporal ??
          TemporalContext(
            evidenceIds: [captured!.evidenceId],
            domainClockPolicyVersion:
                PhoneCaptureIdentity.domainClockContract.value,
          ),
    );
  }

  Future<List<MatchRecord>> records() {
    return composition.boundary.durableStore.readCommittedForMatch('match-1');
  }

  List<MatchRecord> goalsOf(List<MatchRecord> committed) {
    return [
      for (final record in committed)
        if (record.payload is GoalPayload) record,
    ];
  }

  test('home and away goals score from projection without a player', () async {
    await kickOff();
    clock.elapsed = const Duration(minutes: 3);
    expect(
      await commitGoal(side: CreditedSide.home, intentId: 'home-1'),
      isA<DurableCommitSuccess>(),
    );
    clock.elapsed = const Duration(minutes: 8);
    expect(
      await commitGoal(side: CreditedSide.away, intentId: 'away-1'),
      isA<DurableCommitSuccess>(),
    );

    final committed = await records();
    final goals = goalsOf(committed);
    expect(goals, hasLength(2));
    for (final goal in goals) {
      expect(goal.recordKind, RecordKind.humanDetermination);
      expect(goal.authorityContext?.scope, isA<MainRefereeScope>());
      final encoded = encodeMatchRecordJson(goal);
      expect(encoded, isNot(contains('player')));
      expect(encoded, isNot(contains('elapsedSeconds')));
    }

    final storedEvidence = [
      for (final goal in goals)
        await evidence.resolve(goal.temporalContext!.evidenceIds.single),
    ];
    final anchorId = committed
        .firstWhere((record) {
          final payload = record.payload;
          return payload is TemporalTransitionPayload &&
              payload.semanticType == V1SemanticTypeCode.periodStarted;
        })
        .temporalContext!
        .evidenceIds
        .single;
    final projection = GoalMatchProjection.derive(
      records: committed,
      evidence: [
        (await evidence.resolve(anchorId))!,
        for (final item in storedEvidence) item!,
      ],
    );
    expect(projection.homeScore, 1);
    expect(projection.awayScore, 1);
    expect(
      projection.goals.last.temporal.exactPlayingTime,
      const Duration(minutes: 8),
    );
  });

  test('the same capture intent cannot append a second goal', () async {
    await kickOff();
    final captured = await evidence.captureAnchor();
    final temporal = TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    );
    final results = await Future.wait([
      composition.boundary.commitGoal(
        context(),
        creditedSide: CreditedSide.home,
        captureIntentId: 'dup',
        temporalContext: temporal,
      ),
      composition.boundary.commitGoal(
        context(),
        creditedSide: CreditedSide.home,
        captureIntentId: 'dup',
        temporalContext: temporal,
      ),
    ]);

    expect(results, everyElement(isA<DurableCommitSuccess>()));
    expect(goalsOf(await records()), hasLength(1));
    final again = await composition.boundary.commitGoal(
      context(),
      creditedSide: CreditedSide.away,
      captureIntentId: 'dup',
      temporalContext: temporal,
    );
    expect(again, isA<DurableCommitFailure>());
    expect(goalsOf(await records()), hasLength(1));
    expect(
      GoalMatchProjection.derive(records: await records()).homeScore,
      1,
    );
  });

  test('reused temporal evidence cannot create a second goal', () async {
    await kickOff();
    final captured = await evidence.captureAnchor();
    final temporal = TemporalContext(
      evidenceIds: [captured.evidenceId],
      domainClockPolicyVersion: PhoneCaptureIdentity.domainClockContract.value,
    );
    expect(
      await composition.boundary.commitGoal(
        context(),
        creditedSide: CreditedSide.home,
        captureIntentId: 'one',
        temporalContext: temporal,
      ),
      isA<DurableCommitSuccess>(),
    );
    final second = await composition.boundary.commitGoal(
      context(),
      creditedSide: CreditedSide.home,
      captureIntentId: 'two',
      temporalContext: temporal,
    );
    expect(second, isA<DurableCommitFailure>());
    expect(goalsOf(await records()), hasLength(1));
  });

  test('goal is blocked before an active period', () async {
    final result = await commitGoal(side: CreditedSide.home, intentId: 'early');
    expect(result, isA<DurableCommitFailure>());
    expect((result as DurableCommitFailure).reason, contains('active period'));
    expect(await records(), isEmpty);
  });

  test('goal is blocked during formal suspension', () async {
    await kickOff();
    final committed = await records();
    final periodStart = committed.firstWhere((record) {
      final payload = record.payload;
      return payload is TemporalTransitionPayload &&
          payload.semanticType == V1SemanticTypeCode.periodStarted;
    });
    final boundaryEvidence = await evidence.captureAnchor();
    expect(
      await composition.boundary.commitTemporarySuspensionStarted(
        context(),
        period: const PeriodIdentity(index: 1),
        periodStartedRecordId: periodStart.recordId,
        temporalContext: TemporalContext(
          evidenceIds: [boundaryEvidence.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      ),
      isA<DurableCommitSuccess>(),
    );

    final result = await commitGoal(side: CreditedSide.home, intentId: 'held');
    expect(result, isA<DurableCommitFailure>());
    expect((result as DurableCommitFailure).reason, contains('formal suspension'));
    expect(goalsOf(await records()), isEmpty);
  });

  test('goal is blocked after MATCH_ENDED', () async {
    await kickOff();
    await _appendTerminal(
      composition,
      context(),
      V1SemanticTypeCode.matchEnded,
    );
    final ended = await commitGoal(side: CreditedSide.home, intentId: 'ended');
    expect(ended, isA<DurableCommitFailure>());
    expect((ended as DurableCommitFailure).reason, contains('MATCH_ENDED'));
    expect(goalsOf(await records()), isEmpty);
  });

  test('goal is blocked after MATCH_ABANDONED', () async {
    await kickOff();
    await _appendTerminal(
      composition,
      context(),
      V1SemanticTypeCode.matchAbandoned,
    );
    final abandoned =
        await commitGoal(side: CreditedSide.away, intentId: 'abandoned');
    expect(abandoned, isA<DurableCommitFailure>());
    expect(
      (abandoned as DurableCommitFailure).reason,
      contains('MATCH_ABANDONED'),
    );
    expect(goalsOf(await records()), isEmpty);
  });

  test('reopen rebuilds the same score and goal history', () async {
    await kickOff();
    clock.elapsed = const Duration(minutes: 8);
    expect(
      await commitGoal(side: CreditedSide.home, intentId: 'kept'),
      isA<DurableCommitSuccess>(),
    );
    final beforeRecords = await records();
    final beforeEvidence = await _evidenceFor(evidence, beforeRecords);
    final before = GoalMatchProjection.derive(
      records: beforeRecords,
      evidence: beforeEvidence,
    );
    final databaseFile = composition.databaseFile;
    await composition.close();

    final reopened = MatchApplicationBoundary(
      store: SqliteDurableMatchStore.open(databaseFile),
    );
    addTearDown(reopened.close);
    final afterRecords =
        await reopened.durableStore.readCommittedForMatch('match-1');
    final after = GoalMatchProjection.derive(
      records: afterRecords,
      evidence: await _evidenceFor(evidence, afterRecords),
    );

    expect(after, before);
    expect(after.homeScore, 1);
    expect(after.goals.single.temporal.exactPlayingTime, const Duration(minutes: 8));
  });

  test('goal commit does not use the generic capture port or a manual minute', () {
    final source = File(
      'lib/match_application/match_application_boundary.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<DurableCommitResult> commitGoal');
    final end = source.indexOf('Future<DurableCommitResult> captureAndCommit');
    final method = source.substring(start, end);
    expect(method, isNot(contains('captureAndCommit(')));
    expect(method, isNot(contains('elapsedSeconds')));
    expect(method, isNot(contains('recordedAt:')));
    expect(method, isNot(contains('package:match_core')));

    final page = File('lib/features/live_match/live_match_page.dart')
        .readAsStringSync();
    expect(page, isNot(contains('MatchRecord(')));
    final tickStart = page.indexOf('void _onClockTick()');
    final tickEnd = page.indexOf('Future<void> _resumeMatch');
    expect(page.substring(tickStart, tickEnd), isNot(contains('GoalMatchProjection')));
    expect(page.substring(tickStart, tickEnd), isNot(contains('commitGoal')));
  });
}

Future<void> _appendTerminal(
  MatchApplicationComposition composition,
  CaptureContext context,
  V1SemanticTypeCode code,
) async {
  final request = composition.boundary.recordBuilder.build(
    context: context,
    recordKind: RecordKind.temporalFact,
    payload: TemporalTransitionPayload(semanticType: code),
    integrity: const IntegrityMetadata(),
  );
  expect(
    await composition.boundary.durableStore.commitAtNextOriginSequence(request),
    isA<DurableCommitSuccess>(),
  );
}

Future<List<TemporalEvidence>> _evidenceFor(
  PhoneTemporalEvidenceStore evidence,
  List<MatchRecord> records,
) async {
  final resolved = <TemporalEvidence>[];
  for (final record in records) {
    for (final id in record.temporalContext?.evidenceIds ?? const <String>[]) {
      final item = await evidence.resolve(id);
      if (item != null) resolved.add(item);
    }
  }
  return resolved;
}

final class ManualGoalClock implements MonotonicContinuityClock {
  Duration elapsed = Duration.zero;

  @override
  String get continuityDomainId => 'domain-goal';

  @override
  Duration get monotonicElapsed => elapsed;

  @override
  DateTime get chronology => DateTime.utc(2026, 10, 5, 12);
}
