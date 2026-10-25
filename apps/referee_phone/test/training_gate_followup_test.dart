import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:referee_phone/officiate/fixture_list.dart';
import 'package:referee_phone/training/training_match_gate.dart';
import 'package:referee_phone/training/training_session.dart';
import 'package:referee_phone/training/training_store.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temp;
  late LocalMatchDatabase db;
  late MatchApplicationComposition composition;
  late PhoneCaptureIdentity identity;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('training_gate_');
    db = LocalMatchDatabase.memory();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    identity = await PhoneCaptureIdentityStore(temp).loadOrCreate();
  });

  tearDown(() async {
    await composition.close();
    await db.close();
    if (temp.existsSync()) {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // The store may release the directory a moment later.
      }
    }
  });

  Future<Match> seed({required MatchStatus status}) async {
    final match = newLocalMatch(DateTime.utc(2026, 10, 25, 12)).copyWith(
      status: status,
    );
    await db.upsertMatch(match);
    return match;
  }

  Future<TrainingStartDenial?> denial({
    MatchApplicationBoundary? boundary,
    bool anotherSessionOpen = false,
  }) {
    return trainingMatchDenial(
      database: db,
      boundary: boundary ?? composition.boundary,
      today: DateTime.utc(2026, 10, 25),
      anotherSessionOpen: anotherSessionOpen,
    );
  }

  test('the fixture list still shows legacy full time as current', () async {
    final match = await seed(status: MatchStatus.fullTime);
    expect(
      classifyFixture(
        match: match,
        evidence: const FixtureEvidence.none(),
        today: DateTime.utc(2026, 10, 25),
      ),
      FixtureGroup.current,
    );
  });

  test('legacy full time alone does not block a training start', () async {
    await seed(status: MatchStatus.fullTime);
    expect(await denial(), isNull);
    expect(await denial(boundary: null), isNull);
  });

  test('a live, paused, or half-time match still blocks training', () async {
    Future<void> expectBlocks(MatchStatus status) async {
      final isolated = LocalMatchDatabase.memory();
      final match = newLocalMatch(DateTime.utc(2026, 10, 25, 12)).copyWith(
        status: status,
      );
      await isolated.upsertMatch(match);
      final result = await trainingMatchDenial(
        database: isolated,
        boundary: null,
        today: DateTime.utc(2026, 10, 25),
        anotherSessionOpen: false,
      );
      expect(result, TrainingStartDenial.matchInProgress);
      await isolated.close();
    }

    await expectBlocks(MatchStatus.live);
    await expectBlocks(MatchStatus.paused);
    await expectBlocks(MatchStatus.halfTime);
    await seed(status: MatchStatus.live);
    expect(await denial(), TrainingStartDenial.matchInProgress);
  });

  test('authoritative start without an end still blocks on full time',
      () async {
    final match = await seed(status: MatchStatus.fullTime);
    final context = identity.contextFor(match.matchId);
    expect(
      await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
        GenerationOneAuthorityRoot(
          matchId: match.matchId,
          principalId: context.authorityPrincipalId,
          deviceId: context.originDeviceId,
        ),
      ),
      isA<GenerationOneRootCommitSuccess>(),
    );
    expect(
      await composition.boundary.commitKickOff(
        context,
        period: const PeriodIdentity(index: 1),
      ),
      isA<KickOffAuthorityCommitted>(),
    );
    expect(await denial(), TrainingStartDenial.matchInProgress);
  });

  test('a corrupt Match Memory row blocks training', () async {
    final match = await seed(status: MatchStatus.fullTime);
    final context = identity.contextFor(match.matchId);
    await composition.boundary.durableStore.commitGenerationOneAuthorityRoot(
      GenerationOneAuthorityRoot(
        matchId: match.matchId,
        principalId: context.authorityPrincipalId,
        deviceId: context.originDeviceId,
      ),
    );
    await composition.boundary.commitKickOff(
      context,
      period: const PeriodIdentity(index: 1),
    );
    final records =
        await composition.boundary.durableStore.readCommittedForMatch(
      match.matchId,
    );
    final recordId = records.first.recordId;
    await composition.close();
    final database = sqlite3.open(composition.databaseFile.path);
    database.execute(
      'UPDATE committed_match_records SET record_json = ? WHERE record_id = ?',
      ['"not-an-object"', recordId],
    );
    database.close();
    composition = await MatchApplicationComposition.open(storageRoot: temp);
    expect(await denial(), TrainingStartDenial.matchStateUnverified);
  });

  test('another open session still blocks when no match is running', () async {
    await seed(status: MatchStatus.setup);
    expect(
      await denial(anotherSessionOpen: true),
      TrainingStartDenial.anotherSessionOpen,
    );
  });

  test('an unrelated full-time match does not block, a live one does',
      () async {
    await seed(status: MatchStatus.fullTime);
    expect(await denial(), isNull);
    await seed(status: MatchStatus.live);
    expect(await denial(), TrainingStartDenial.matchInProgress);
  });

  test('parallel starts leave one open session after reopen', () async {
    final store = TrainingStore(directory: temp);
    final results = await Future.wait([
      store.startGeneral(requestId: 'request-a'),
      store.startGeneral(requestId: 'request-b'),
    ]);
    final started = results.whereType<TrainingStarted>().length;
    final blocked = results.whereType<TrainingStartBlocked>().length;
    expect(started, 1);
    expect(blocked, 1);
    final reopened = TrainingStore(directory: temp);
    final ledger = await reopened.load();
    expect(ledger.unreadable, isFalse);
    expect(ledger.sessions, hasLength(1));
    expect(ledger.openSession, isNotNull);
  });
}
