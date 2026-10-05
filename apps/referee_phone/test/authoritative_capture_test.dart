import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('referee_capture_');
  });

  tearDown(() async {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  group('Authoritative capture', () {
    test('captureAndCommit assigns sequences 1 then 2', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      final context = _context();
      final first = await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: context,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
          integrity: const IntegrityMetadata(),
        ),
      );
      final second = await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: context,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodStarted,
            period: const PeriodIdentity(index: 1),
          ),
          integrity: const IntegrityMetadata(),
        ),
      );

      expect(first, isA<DurableCommitSuccess>());
      expect(second, isA<DurableCommitSuccess>());
      final records = await composition.boundary.durableStore.readCommittedForMatch(
        'match-1',
      );
      expect(records.map((record) => record.originSequence).toList(), [1, 2]);
    });

    test('recordId is independent from timestamp', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      final recordedAt = DateTime.utc(2026, 10, 2, 12);
      final context = _context();
      await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: context,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
          integrity: const IntegrityMetadata(),
          recordedAt: recordedAt,
        ),
      );
      await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: context,
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.periodEnded,
            period: const PeriodIdentity(index: 1),
          ),
          integrity: const IntegrityMetadata(),
          recordedAt: recordedAt,
        ),
      );

      final records = await composition.boundary.durableStore.readCommittedForMatch(
        'match-1',
      );
      expect(records[0].recordId, isNot(records[1].recordId));
      expect(records[0].recordedAt, records[1].recordedAt);
    });

    test('constructed record carries explicit principal scope and generation', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: _context(
            authorityPrincipalId: 'ref-main',
            authorityGeneration: 2,
          ),
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
            domainContractVersion: const DomainContractVersion('domain-clock-v1'),
            competitionRulesContext: const CompetitionRulesContext(rulesetId: 'ifab'),
          ),
          integrity: const IntegrityMetadata(evidenceRefs: ['evidence-1']),
          relationships: const [CausalDependency(targetRecordId: 'dep-1')],
        ),
      );

      final stored = (await composition.boundary.durableStore.readCommittedForMatch(
        'match-1',
      )).single;
      expect(stored.authorityContext!.scope, isA<MainRefereeScope>());
      expect(stored.authorityContext!.principal!.principalId, 'ref-main');
      expect(stored.authorityContext!.generation!.value, 2);
      expect(
        (stored.payload as TemporalTransitionPayload).domainContractVersion,
        const DomainContractVersion('domain-clock-v1'),
      );
      expect(stored.relationships.single, isA<CausalDependency>());
    });

    test('projection generation is supplied explicitly', () async {
      final composition = await MatchApplicationComposition.open(
        storageRoot: temp,
      );
      addTearDown(composition.close);

      await composition.boundary.captureAndCommit(
        AuthoritativeCaptureCommand(
          context: _context(
            authorityGeneration: 2,
            projectionAuthorityGeneration: 2,
          ),
          recordKind: RecordKind.temporalFact,
          payload: TemporalTransitionPayload(
            semanticType: V1SemanticTypeCode.matchStarted,
          ),
          integrity: const IntegrityMetadata(),
        ),
      );

      final projection = await composition.boundary.project(
        'match-1',
        evaluatedAuthorityGeneration: 2,
      );
      expect(projection.trustFor(ProjectionFacet.temporal), ProjectionTrust.trusted);
      expect(projection.trustFor(ProjectionFacet.authority), ProjectionTrust.trusted);

      final mismatched = await composition.boundary.project(
        'match-1',
        evaluatedAuthorityGeneration: 1,
      );
      expect(
        mismatched.trustFor(ProjectionFacet.authority),
        ProjectionTrust.incomplete,
      );
    });

    test('feature pages do not activate captureAndCommit', () {
      final featureFiles = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in featureFiles) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('captureAndCommit')));
        expect(text, isNot(contains('AuthoritativeCaptureCommand')));
      }
    });

    test('legacy MatchSession remains untouched', () {
      final sessionSource = File('lib/match/match_session.dart').readAsStringSync();
      expect(sessionSource, isNot(contains('captureAndCommit')));
      expect(sessionSource, isNot(contains('CaptureContext')));
      expect(sessionSource, contains('upsertMatch'));
    });
  });
}

CaptureContext _context({
  String matchId = 'match-1',
  String originDeviceId = 'dev-a',
  String authorityPrincipalId = 'ref-1',
  int authorityGeneration = 1,
  int projectionAuthorityGeneration = 1,
}) {
  return CaptureContext(
    matchId: matchId,
    originDeviceId: originDeviceId,
    authorityScope: v1AuthorityScope,
    authorityPrincipalId: authorityPrincipalId,
    authorityGeneration: authorityGeneration,
    projectionAuthorityGeneration: projectionAuthorityGeneration,
    activeCaptureDeviceId: 'phone-a',
  );
}
