import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
  final format = _Formats.standard;
  final anchorAt = DateTime.utc(2026, 10, 14, 12);

  test('1 exact running lifecycle projects RunningTrusted', () {
    final records = _period(anchorId: 'anchor');
    final state = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 15)),
    );

    expect(state, isA<RunningTrusted>());
    final running = state as RunningTrusted;
    expect(running.period, const PeriodIdentity(index: 1));
    expect(running.nominalBase, Duration.zero);
    expect(running.activeElapsed, const Duration(seconds: 15));
    expect(running.footballTime, const Duration(seconds: 15));
    expect(running.footballTime, running.nominalBase + running.activeElapsed);
    expect(running.continuity, TemporalContinuityStatus.exactContinuity);
    expect(exactTickingClock(state), const Duration(seconds: 15));
  });

  test('2 bounded continuity projects RunningBounded', () {
    final state = _bounded(projector, format, anchorAt);

    expect(state, isA<RunningBounded>());
    final bounded = state as RunningBounded;
    expect(bounded.period, const PeriodIdentity(index: 1));
    expect(bounded.continuity, TemporalContinuityStatus.boundedContinuity);
    expect(bounded.activeElapsedLowerBound, const Duration(seconds: 10));
    expect(bounded.activeElapsedUpperBound, const Duration(seconds: 13));
    expect(bounded.footballTimeLowerBound, const Duration(seconds: 10));
    expect(bounded.footballTimeUpperBound, const Duration(seconds: 13));
    expect(exactTickingClock(state), isNull);
  });

  test('missing period anchor does not become a zero clock', () {
    final records = _period(anchorId: 'anchor');
    final projection = _project(projector, records);
    final lifecycle = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final elapsed = deriveActivePeriodElapsed(
      temporal: lifecycle,
      projection: projection,
      records: records,
      anchor: null,
      current: _point('live', anchorAt, const Duration(seconds: 30)),
    );
    final state = projectTemporalDisplay(
      lifecycle: lifecycle,
      elapsed: elapsed,
      projection: projection,
      format: format,
      periodAnchor: null,
    );

    expect(elapsed.exactElapsed, isNull);
    expect(state, isA<Unresolved>());
    expect((state as Unresolved).reason, TemporalUnresolvedReason.missingAnchor);
    expect(exactTickingClock(state), isNull);
  });

  test('3 unresolved continuity projects Unresolved', () {
    final state = _unresolvedDomain(projector, format, anchorAt);
    final reversed = _show(
      projector: projector,
      records: _period(anchorId: 'anchor'),
      format: format,
      anchor: _point('anchor', anchorAt, const Duration(seconds: 20)),
      current: _point('live', anchorAt, const Duration(seconds: 5)),
    );

    expect(state, isA<Unresolved>());
    expect((state as Unresolved).reason,
        TemporalUnresolvedReason.continuityUnresolved);
    expect(exactTickingClock(state), isNull);
    expect(reversed, isA<Unresolved>());
    expect(exactTickingClock(reversed), isNull);
  });

  test('4 bounded state cannot yield an exact elapsed', () {
    final equalBounds = _show(
      projector: projector,
      records: _period(anchorId: 'anchor'),
      format: format,
      anchor: _point('anchor', anchorAt, const Duration(seconds: 2)),
      current: TemporalEvidence(
        evidenceId: 'live',
        capturedAt: anchorAt,
        continuityDomainId: 'domain-1',
        monotonicElapsed: const Duration(seconds: 12),
        monotonicUpperBound: const Duration(seconds: 12),
      ),
    );
    final suspended = _show(
      projector: projector,
      records: _suspended(anchorId: 'anchor', boundaryId: 'boundary'),
      format: format,
      anchor: _point('anchor', anchorAt, const Duration(seconds: 2)),
      current: _point('live', anchorAt, const Duration(minutes: 10)),
      suspensionBoundary: TemporalEvidence(
        evidenceId: 'boundary',
        capturedAt: anchorAt,
        continuityDomainId: 'domain-1',
        monotonicElapsed: const Duration(seconds: 12),
        monotonicUpperBound: const Duration(seconds: 12),
      ),
    );

    expect(equalBounds, isA<RunningBounded>());
    final bounded = equalBounds as RunningBounded;
    expect(bounded.activeElapsedLowerBound, bounded.activeElapsedUpperBound);
    expect(exactTickingClock(equalBounds), isNull);
    expect(suspended, isA<SuspendedTrusted>());
    final elapsed = (suspended as SuspendedTrusted).elapsed;
    expect(elapsed, isA<BoundedSuspensionElapsed>());
    expect(frozenExact(elapsed), isNull);
    expect(exactTickingClock(suspended), isNull);
  });

  test('5 unresolved state cannot yield current elapsed', () {
    final forged = _forgedElapsed(
      period: const PeriodIdentity(index: 1),
      continuity: TemporalContinuityStatus.continuityUnresolved,
      exact: const Duration(seconds: 99),
    );
    final state = _show(
      projector: projector,
      records: _period(anchorId: 'anchor'),
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero, domainId: 'domain-a'),
      current: _point('live', anchorAt, const Duration(seconds: 40),
          domainId: 'domain-b'),
      elapsedOverride: forged,
      historicalElapsed: const Duration(seconds: 4),
    );

    expect(state, isA<Unresolved>());
    expect(exactTickingClock(state), isNull);
    expect((state as Unresolved).lastProvenActiveElapsed,
        isNot(const Duration(seconds: 99)));
  });

  test('6 last-proven time remains historical context only', () {
    final state = _show(
      projector: projector,
      records: _period(anchorId: 'anchor'),
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero, domainId: 'domain-a'),
      current: _point('live', anchorAt, const Duration(minutes: 3),
          domainId: 'domain-b'),
      historicalElapsed: const Duration(seconds: 12),
      historicalPeriod: const PeriodIdentity(index: 1),
      elapsedOverride: _forgedElapsed(
        period: const PeriodIdentity(index: 1),
        continuity: TemporalContinuityStatus.continuityUnresolved,
        exact: const Duration(seconds: 99),
      ),
    );

    final unresolved = state as Unresolved;
    expect(unresolved.reason, TemporalUnresolvedReason.continuityUnresolved);
    expect(unresolved.lastProvenActiveElapsed, const Duration(seconds: 12));
    expect(unresolved.lastProvenPeriod, const PeriodIdentity(index: 1));
    expect(exactTickingClock(state), isNull);
    expect(unresolved.lastProvenActiveElapsed, isNot(exactTickingClock(state)));
  });

  test('7 ordinary stoppage keeps active football-time running', () {
    final records = _period(anchorId: 'anchor');
    expect(
      records.any(_isSuspension),
      isFalse,
    );
    final atThirty = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 30)),
    );
    final atNinety = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 90)),
    );

    expect(atThirty, isA<RunningTrusted>());
    expect(atNinety, isA<RunningTrusted>());
    expect(
        (atNinety as RunningTrusted).footballTime -
            (atThirty as RunningTrusted).footballTime,
        const Duration(seconds: 60));
    expect(atNinety, isNot(isA<SuspendedTrusted>()));
  });

  test('8 event capture does not pause time', () {
    final records = [
      ..._period(anchorId: 'anchor'),
      _occurrence('goal', 3, {'event': 'goal'}),
      _occurrence('yellow', 4, {'event': 'yellowCard'}),
      _occurrence('injury', 5, {'event': 'injury'}),
      _occurrence('substitution', 6, {'event': 'substitution'}),
    ];
    final before = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 30)),
    );
    final after = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 90)),
    );

    expect(before, isA<RunningTrusted>());
    expect(after, isA<RunningTrusted>());
    expect(
        (after as RunningTrusted).activeElapsed, const Duration(seconds: 90));
    expect(after.footballTime - (before as RunningTrusted).footballTime,
        const Duration(seconds: 60));
    expect(after, isNot(isA<SuspendedTrusted>()));
    expect(records, hasLength(6));
  });

  test('9 formal suspension freezes active elapsed', () {
    final records = _suspended(anchorId: 'anchor', boundaryId: 'boundary');
    final boundary = _point('boundary', anchorAt, const Duration(seconds: 10));
    TemporalDisplayState at(Duration current) {
      return _show(
        projector: projector,
        records: records,
        format: format,
        anchor: _point('anchor', anchorAt, Duration.zero),
        current: _point('live', anchorAt, current),
        suspensionBoundary: boundary,
      );
    }

    final early = at(const Duration(seconds: 10));
    final later = at(const Duration(hours: 2));

    expect(early, isA<SuspendedTrusted>());
    expect(later, isA<SuspendedTrusted>());
    final frozen =
        (later as SuspendedTrusted).elapsed as ExactSuspensionElapsed;
    expect((early as SuspendedTrusted).period, const PeriodIdentity(index: 1));
    expect(later.period, const PeriodIdentity(index: 1));
    expect(later.temporalTrust, ProjectionTrust.trusted);
    expect(later.suspensionEvidenceId, 'boundary');
    expect(frozen.activeElapsed, const Duration(seconds: 10));
    expect(frozen.footballTime, const Duration(seconds: 10));
    expect(
      ((early.elapsed as ExactSuspensionElapsed).footballTime),
      frozen.footballTime,
    );
    expect(exactTickingClock(later), isNull);
    expect(records.where(_isPeriodEnd), isEmpty);
  });

  test('10 resume continues from the frozen active elapsed', () {
    final records = _resumed(
      anchorId: 'anchor',
      boundaryId: 'boundary',
      resumptionId: 'resume',
    );
    final resumed = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 47)),
      suspensionBoundary:
          _point('boundary', anchorAt, const Duration(seconds: 10)),
      resumptionAnchor: _point('resume', anchorAt, const Duration(seconds: 40)),
    );

    expect(resumed, isA<RunningTrusted>());
    final running = resumed as RunningTrusted;
    expect(running.period, const PeriodIdentity(index: 1));
    expect(running.activeElapsed, const Duration(seconds: 17));
    expect(running.footballTime, const Duration(seconds: 17));
    expect(running, isNot(isA<SuspendedTrusted>()));
  });

  test('11 suspension duration is not double-counted', () {
    final records = _resumed(
      anchorId: 'anchor',
      boundaryId: 'boundary',
      resumptionId: 'resume',
    );
    final running = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 47)),
      suspensionBoundary:
          _point('boundary', anchorAt, const Duration(seconds: 10)),
      resumptionAnchor: _point('resume', anchorAt, const Duration(seconds: 40)),
    ) as RunningTrusted;

    const held = Duration(seconds: 30);
    expect(running.activeElapsed, const Duration(seconds: 17));
    expect(running.footballTime, isNot(const Duration(seconds: 47)));
    expect(running.footballTime, isNot(const Duration(seconds: 17) + held));
    expect(running.activeElapsed + held, const Duration(seconds: 47));
  });

  test('12 reaching 45:00 does not create halftime', () {
    final records = _period(anchorId: 'anchor');
    final state = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current:
          _point('live', anchorAt, const Duration(minutes: 45, seconds: 1)),
    );

    expect(state, isA<RunningTrusted>());
    final running = state as RunningTrusted;
    expect(running.period, const PeriodIdentity(index: 1));
    expect(running.footballTime, const Duration(minutes: 45, seconds: 1));
    expect(running.addedTime.suggestion, isNull);
    expect(records.where(_isPeriodEnd), isEmpty);
    expect(state, isNot(isA<InactiveTrusted>()));
  });

  test('13 reaching 90:00 does not end the match', () {
    final records = _secondPeriod(anchorId: 'p2');
    final state = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('p2', anchorAt, Duration.zero),
      current:
          _point('live', anchorAt, const Duration(minutes: 45, seconds: 1)),
      evidence: [
        _point('p1', anchorAt, Duration.zero),
        _point('p1-end', anchorAt, const Duration(minutes: 45)),
        _point('p2', anchorAt, Duration.zero),
      ],
    );

    expect(state, isA<RunningTrusted>());
    final running = state as RunningTrusted;
    expect(running.period, const PeriodIdentity(index: 2));
    expect(running.nominalBase, const Duration(minutes: 45));
    expect(running.activeElapsed, const Duration(minutes: 45, seconds: 1));
    expect(running.footballTime, const Duration(minutes: 90, seconds: 1));
    expect(records.where(_isMatchEnded), isEmpty);
    expect(state, isNot(isA<InactiveTrusted>()));
  });

  test('14 halftime requires period-end lifecycle authority', () {
    final running = _show(
      projector: projector,
      records: _period(anchorId: 'anchor'),
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(minutes: 50)),
    );
    final records = _periodEnded(anchorId: 'anchor', endId: 'p1-end');
    final interval = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(hours: 3)),
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('p1-end', anchorAt, const Duration(minutes: 48, seconds: 37)),
      ],
    );

    expect(running, isA<RunningTrusted>());
    expect(interval, isA<InactiveTrusted>());
    expect((interval as InactiveTrusted).lifecycle, InactiveLifecycle.interval);
    expect(interval.endedPeriod, const PeriodIdentity(index: 1));
    expect(exactTickingClock(interval), isNull);
    expect(records.where(_isPeriodStart).map(_periodIndex), isNot(contains(2)));
  });

  test('15 next period and screen opening require authoritative start', () {
    final opened = _show(
      projector: projector,
      records: [_transition('start', V1SemanticTypeCode.matchStarted, 1)],
      format: format,
      anchor: _point('unused', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(minutes: 20)),
    );
    final interval = _show(
      projector: projector,
      records: _periodEnded(anchorId: 'anchor', endId: 'p1-end'),
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(days: 1)),
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('p1-end', anchorAt, const Duration(minutes: 46)),
      ],
    );
    final second = _show(
      projector: projector,
      records: _secondPeriod(anchorId: 'p2'),
      format: format,
      anchor: _point('p2', anchorAt, const Duration(minutes: 80)),
      current: _point('live', anchorAt, const Duration(minutes: 80)),
      evidence: [
        _point('p1', anchorAt, Duration.zero),
        _point('p1-end', anchorAt, const Duration(minutes: 48, seconds: 37)),
        _point('p2', anchorAt, const Duration(minutes: 80)),
      ],
    );

    expect(opened, isA<InactiveTrusted>());
    expect((opened as InactiveTrusted).lifecycle, InactiveLifecycle.prePeriod);
    expect(exactTickingClock(opened), isNull);
    expect(interval, isA<InactiveTrusted>());
    expect((interval as InactiveTrusted).lifecycle, InactiveLifecycle.interval);
    expect(second, isA<RunningTrusted>());
    expect((second as RunningTrusted).period, const PeriodIdentity(index: 2));
    expect(second.nominalBase, const Duration(minutes: 45));
    expect(second.activeElapsed, Duration.zero);
    expect(second.footballTime, const Duration(minutes: 45));
  });

  test('16 1H overrun does not shift the 2H nominal base', () {
    final ended = _periodEnded(anchorId: 'p1', endId: 'p1-end');
    final firstHalf = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: _project(projector, ended),
        records: ended,
      ),
      projection: _project(projector, ended),
      records: ended,
      anchor: _point('p1', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(hours: 5)),
      recordedEvidence: [
        _point('p1', anchorAt, Duration.zero),
        _point('p1-end', anchorAt, const Duration(minutes: 48, seconds: 37)),
      ],
    );
    final second = _show(
      projector: projector,
      records: _secondPeriod(anchorId: 'p2'),
      format: format,
      anchor: _point('p2', anchorAt, const Duration(hours: 1)),
      current: _point('live', anchorAt, const Duration(hours: 1)),
      evidence: [
        _point('p1', anchorAt, Duration.zero),
        _point('p1-end', anchorAt, const Duration(minutes: 48, seconds: 37)),
        _point('p2', anchorAt, const Duration(hours: 1)),
      ],
    ) as RunningTrusted;

    expect(firstHalf.exactElapsed, const Duration(minutes: 48, seconds: 37));
    expect(second.nominalBase, const Duration(minutes: 45));
    expect(second.activeElapsed, Duration.zero);
    expect(second.footballTime, const Duration(minutes: 45));
    expect(
        second.footballTime, isNot(const Duration(minutes: 48, seconds: 37)));
  });

  test('17 ET1 overrun does not shift the ET2 nominal base', () {
    final afterEt1 = _throughPeriod(3, endLast: true);
    final waiting = _show(
      projector: projector,
      records: afterEt1,
      format: format,
      anchor: _point('p3', anchorAt, const Duration(seconds: 1000)),
      current: _point('live', anchorAt, const Duration(days: 2)),
      evidence: _chainEvidence(3, endLast: true),
    );
    final et1 = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: _project(projector, afterEt1),
        records: afterEt1,
      ),
      projection: _project(projector, afterEt1),
      records: afterEt1,
      anchor: _point('p3', anchorAt, const Duration(seconds: 1000)),
      current: _point('live', anchorAt, const Duration(days: 2)),
      recordedEvidence: _chainEvidence(3, endLast: true),
    );
    final et2Records = _throughPeriod(4, endLast: false);
    final et2 = _show(
      projector: projector,
      records: et2Records,
      format: format,
      anchor: _point('p4', anchorAt, const Duration(seconds: 5000)),
      current: _point('live', anchorAt, const Duration(seconds: 5000)),
      evidence: [
        ..._chainEvidence(3, endLast: true),
        _point('p4', anchorAt, const Duration(seconds: 5000)),
      ],
    ) as RunningTrusted;

    expect(waiting, isA<InactiveTrusted>());
    expect((waiting as InactiveTrusted).lifecycle,
        InactiveLifecycle.awaitingNextPeriod);
    expect(exactTickingClock(waiting), isNull);
    expect(et1.exactElapsed, const Duration(minutes: 20));
    expect(et2.period, const PeriodIdentity(index: 4));
    expect(et2.nominalBase, const Duration(minutes: 105));
    expect(et2.activeElapsed, Duration.zero);
    expect(et2.footballTime, const Duration(minutes: 105));
    expect(et2.footballTime, isNot(const Duration(minutes: 110)));
    expect(et2.footballTime,
        isNot(const Duration(minutes: 90) + et1.exactElapsed!));
  });

  test('18 nominal bases come from format context', () {
    final records = _secondPeriod(anchorId: 'p2');
    final evidence = [
      _point('p1', anchorAt, Duration.zero),
      _point('p1-end', anchorAt, const Duration(minutes: 20)),
      _point('p2', anchorAt, const Duration(minutes: 40)),
    ];
    TemporalDisplayState project(MatchFormatClockContext clock) {
      return _show(
        projector: projector,
        records: records,
        format: clock,
        anchor: _point('p2', anchorAt, const Duration(minutes: 40)),
        current: _point('live', anchorAt, const Duration(minutes: 40)),
        evidence: evidence,
      );
    }

    final regulation = project(_Formats.standard) as RunningTrusted;
    final youth = project(_Formats.youth) as RunningTrusted;
    final missing = project(
      MatchFormatClockContext(
        periods: [
          const PeriodClockCoordinate(
            period: PeriodIdentity(index: 1),
            nominalBase: Duration.zero,
            nominalLength: Duration(minutes: 30),
          ),
        ],
      ),
    );
    final source =
        File('lib/projection/temporal_display_state.dart').readAsStringSync();

    expect(regulation.nominalBase, const Duration(minutes: 45));
    expect(regulation.footballTime, const Duration(minutes: 45));
    expect(youth.nominalBase, const Duration(minutes: 30));
    expect(youth.footballTime, const Duration(minutes: 30));
    expect(youth.footballTime, isNot(regulation.footballTime));
    expect(missing, isA<Unresolved>());
    expect((missing as Unresolved).reason,
        TemporalUnresolvedReason.missingNominalBase);
    expect(exactTickingClock(missing), isNull);
    expect(source, isNot(contains('minutes: 45')));
    expect(source, isNot(contains('minutes: 90')));
    expect(source, isNot(contains('minutes: 105')));
    expect(source, isNot(contains('minutes: 120')));
    expect(source, isNot(contains('regulationDisplayThreshold')));
  });

  test('19 stale authority cannot produce RunningTrusted', () {
    final records = _period(anchorId: 'anchor');
    final stale = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 40)),
      evaluatedGeneration: 2,
      elapsedOverride: _forgedElapsed(
        period: const PeriodIdentity(index: 1),
        exact: const Duration(seconds: 40),
      ),
    );
    final beyond = _show(
      projector: projector,
      records: _period(anchorId: 'anchor', generation: 5),
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 40)),
      elapsedOverride: _forgedElapsed(
        period: const PeriodIdentity(index: 1),
        exact: const Duration(seconds: 40),
      ),
    );

    expect(stale, isA<Unresolved>());
    expect(
        (stale as Unresolved).reason, TemporalUnresolvedReason.staleAuthority);
    expect(exactTickingClock(stale), isNull);
    expect(beyond, isA<Unresolved>());
    expect(
        (beyond as Unresolved).reason, TemporalUnresolvedReason.staleAuthority);
    expect(exactTickingClock(beyond), isNull);
  });

  test('20 temporal conflict cannot produce RunningTrusted', () {
    final records = [
      _transition('start', V1SemanticTypeCode.matchStarted, 1),
      _transition(
        'period',
        V1SemanticTypeCode.periodStarted,
        2,
        period: 1,
        dependsOn: 'start',
        evidenceId: 'anchor',
        principalId: 'ref-2',
      ),
    ];
    final projection = _project(projector, records);
    final state = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 12)),
      elapsedOverride: _forgedElapsed(
        period: const PeriodIdentity(index: 1),
        exact: const Duration(seconds: 12),
      ),
    );

    expect(projection.trustFor(ProjectionFacet.temporal),
        ProjectionTrust.conflicted);
    expect(state, isA<Unresolved>());
    expect((state as Unresolved).reason, TemporalUnresolvedReason.conflict);
    expect(exactTickingClock(state), isNull);
  });

  test('21 corrupted anchor cannot produce RunningTrusted', () {
    final records = _period(anchorId: 'anchor');
    final corrupt = TemporalEvidence(
      evidenceId: 'anchor',
      capturedAt: anchorAt,
      continuityDomainId: 'domain-1',
      monotonicElapsed: const Duration(seconds: 10),
      monotonicUpperBound: const Duration(seconds: 4),
    );
    final derived = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: corrupt,
      current: _point('live', anchorAt, const Duration(seconds: 30)),
    );
    final forged = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: corrupt,
      current: _point('live', anchorAt, const Duration(seconds: 30)),
      elapsedOverride: _forgedElapsed(
        period: const PeriodIdentity(index: 1),
        exact: const Duration(seconds: 20),
      ),
    );

    expect(derived, isA<Unresolved>());
    expect((derived as Unresolved).reason, TemporalUnresolvedReason.corruption);
    expect(forged, isA<Unresolved>());
    expect((forged as Unresolved).reason, TemporalUnresolvedReason.corruption);
    expect(exactTickingClock(forged), isNull);
    expect(forged.lastProvenActiveElapsed, isNull);
  });

  test('22 process restart with exact evidence recovers RunningTrusted', () {
    TemporalDisplayState rebuild() {
      return _show(
        projector: projector,
        records: _period(anchorId: 'anchor'),
        format: format,
        anchor: _point('anchor', anchorAt, const Duration(seconds: 4)),
        current: _point('live', anchorAt, const Duration(seconds: 19)),
      );
    }

    final watch = Stopwatch()..start();
    final first = rebuild();
    final second = rebuild();
    watch.stop();
    // ignore: avoid_print
    print('recovery exact rebuild x2: ${watch.elapsedMicroseconds} us');

    expect(first, isA<RunningTrusted>());
    expect(second, isA<RunningTrusted>());
    expect((second as RunningTrusted).footballTime,
        (first as RunningTrusted).footballTime);
    expect(second.footballTime, const Duration(seconds: 15));
    expect(second.continuity, TemporalContinuityStatus.exactContinuity);
  });

  test('23 process restart with bounded evidence stays RunningBounded', () {
    TemporalDisplayState rebuild() => _bounded(projector, format, anchorAt);

    final first = rebuild() as RunningBounded;
    final second = rebuild() as RunningBounded;

    expect(second.footballTimeLowerBound, first.footballTimeLowerBound);
    expect(second.footballTimeUpperBound, first.footballTimeUpperBound);
    expect(exactTickingClock(second), isNull);
    expect(second.continuity, TemporalContinuityStatus.boundedContinuity);
  });

  test('24 restart without defensible continuity stays Unresolved', () {
    TemporalDisplayState rebuild() =>
        _unresolvedDomain(projector, format, anchorAt);

    final first = rebuild() as Unresolved;
    final second = rebuild() as Unresolved;

    expect(first.reason, TemporalUnresolvedReason.continuityUnresolved);
    expect(second.reason, first.reason);
    expect(exactTickingClock(first), isNull);
    expect(exactTickingClock(second), isNull);
  });

  test('D lifecycle trusted but time unresolved does not counterfeit a timer',
      () {
    final state = _show(
      projector: projector,
      records: _period(anchorId: 'anchor'),
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(minutes: 10),
          domainId: 'domain-b'),
      historicalElapsed: const Duration(seconds: 8),
    );

    final unresolved = state as Unresolved;
    expect(unresolved.reason, TemporalUnresolvedReason.continuityUnresolved);
    expect(unresolved.lastProvenPeriod, const PeriodIdentity(index: 1));
    expect(unresolved.lastProvenActiveElapsed, const Duration(seconds: 8));
    expect(exactTickingClock(state), isNull);
    expect(state, isNot(isA<RunningTrusted>()));
    expect(state, isNot(isA<RunningBounded>()));
  });

  test('E time evidence with unresolved lifecycle does not guess a phase', () {
    final records = [
      _transition(
        'period',
        V1SemanticTypeCode.periodStarted,
        1,
        period: 1,
        dependsOn: 'missing-start',
        evidenceId: 'anchor',
      ),
    ];
    final state = _show(
      projector: projector,
      records: records,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 30)),
      elapsedOverride: _forgedElapsed(
        period: const PeriodIdentity(index: 1),
        exact: const Duration(seconds: 30),
      ),
    );

    final unresolved = state as Unresolved;
    expect(unresolved.reason, TemporalUnresolvedReason.lifecycleIncomplete);
    expect(unresolved.lastProvenPeriod, isNull);
    expect(unresolved.lastProvenActiveElapsed, isNull);
    expect(exactTickingClock(state), isNull);
  });

  test('25 suggestion is not a referee decision', () {
    const shared = Duration(minutes: 3, seconds: 37);
    const suggestion = AddedTimeSuggestion(shared);
    const decision = RefereeAddedTimeDecision(shared);
    final running = _overrun(projector, format, anchorAt);

    expect(suggestion, isNot(isA<RefereeAddedTimeDecision>()));
    expect(decision, isNot(isA<AddedTimeSuggestion>()));
    expect(suggestion.runtimeType, isNot(decision.runtimeType));
    expect(running.addedTime.suggestion, isNull);
    expect(running.addedTime.refereeDecision, isNull);
    expect(running.addedTime.elapsedBeyondNominal, isA<ElapsedBeyondNominal>());
    expect(running.addedTime.suggestion,
        isNot(running.addedTime.elapsedBeyondNominal));
  });

  test('26 referee decision is not a public indication', () {
    const decision = RefereeAddedTimeDecision(Duration(minutes: 4));
    final running = _overrun(projector, format, anchorAt);

    expect(decision, isNot(isA<PublicIndicationUnsupported>()));
    expect(running.addedTime.refereeDecision, isNull);
    expect(
        running.addedTime.publicIndication, isA<PublicIndicationUnsupported>());
    expect(running.addedTime.publicIndication, isNot(decision));
  });

  test('27 public indication is not elapsed beyond nominal', () {
    final running = _overrun(projector, format, anchorAt);
    final source =
        File('lib/projection/temporal_display_state.dart').readAsStringSync();
    final indication = source
        .split('final class PublicIndicationUnsupported')[1]
        .split('final class')
        .first;

    expect(
        running.addedTime.publicIndication, isA<PublicIndicationUnsupported>());
    expect(running.addedTime.elapsedBeyondNominal?.amount,
        const Duration(minutes: 3, seconds: 37));
    expect(running.addedTime.elapsedBeyondNominal,
        isNot(isA<PublicIndicationUnsupported>()));
    expect(running.addedTime.elapsedBeyondNominal,
        isNot(isA<AddedTimeSuggestion>()));
    expect(running.addedTime.elapsedBeyondNominal,
        isNot(isA<RefereeAddedTimeDecision>()));
    expect(indication, isNot(contains('Duration')));
    expect(indication, isNot(contains('amount')));
    expect(source, isNot(contains('as AddedTimeSuggestion')));
    expect(source, isNot(contains('as RefereeAddedTimeDecision')));
    expect(source, isNot(contains('as ElapsedBeyondNominal')));
    expect(source, contains('suggestion: null'));
    expect(source, contains('refereeDecision: null'));
  });

  test('28 no new Match Memory authority is introduced', () {
    final source =
        File('lib/projection/temporal_display_state.dart').readAsStringSync();

    expect(RecordKind.values.map((kind) => kind.name), [
      'occurrence',
      'humanDetermination',
      'action',
      'temporalFact',
      'correction',
      'legalSupersession',
    ]);
    expect(V1SemanticTypeCode.values.map((code) => code.name), [
      'matchStarted',
      'periodStarted',
      'periodEnded',
      'temporarySuspensionStarted',
      'temporarySuspensionEnded',
      'matchAbandoned',
      'matchEnded',
      'temporalCorrection',
      'correction',
      'legalSupersession',
    ]);
    expect(source, isNot(contains('extends MatchRecord')));
    expect(source, isNot(contains('DurableCommit')));
    expect(source, isNot(contains('enum RecordKind')));
    expect(source, isNot(contains('V1SemanticTypeCode.')));
  });

  test('29 no per-second persistence is introduced', () {
    final records = _period(anchorId: 'anchor');
    final anchor = _point('anchor', anchorAt, Duration.zero);
    final projection = _project(projector, records);
    final lifecycle = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final source =
        File('lib/projection/temporal_display_state.dart').readAsStringSync();
    RunningTrusted? previous;
    final tickWatch = Stopwatch()..start();
    for (var second = 0; second < 120; second++) {
      final elapsed = deriveActivePeriodElapsed(
        temporal: lifecycle,
        projection: projection,
        records: records,
        anchor: anchor,
        current: _point('live', anchorAt, Duration(seconds: second)),
      );
      final state = projectTemporalDisplay(
        lifecycle: lifecycle,
        elapsed: elapsed,
        projection: projection,
        format: format,
        periodAnchor: anchor,
      ) as RunningTrusted;
      if (previous != null) {
        expect(state.footballTime - previous.footballTime,
            const Duration(seconds: 1));
      }
      previous = state;
    }
    tickWatch.stop();
    // ignore: avoid_print
    print(
      'running trusted tick x120 (cached lifecycle + elapsed + display): '
      '${tickWatch.elapsedMicroseconds} us',
    );

    expect(records, hasLength(2));
    expect(previous!.footballTime, const Duration(seconds: 119));
    expect(source, isNot(contains('sqlite')));
    expect(source, isNot(contains('Firebase')));
    expect(source, isNot(contains('readCommittedForMatch')));
    expect(source, isNot(contains('List<MatchRecord>')));
    expect(source, isNot(contains('File(')));
    expect(source, isNot(contains('Timer')));
    expect(source, isNot(contains('uiPaused')));
    expect(source, isNot(contains('backgrounded')));
  });

  test('display-only hot path stays arithmetic', () {
    final records = _period(anchorId: 'anchor');
    final anchor = _point('anchor', anchorAt, Duration.zero);
    final projection = _project(projector, records);
    final lifecycle = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final elapsed = deriveActivePeriodElapsed(
      temporal: lifecycle,
      projection: projection,
      records: records,
      anchor: anchor,
      current: _point('live', anchorAt, const Duration(seconds: 12)),
    );
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20000; i++) {
      final state = projectTemporalDisplay(
        lifecycle: lifecycle,
        elapsed: elapsed,
        projection: projection,
        format: format,
        periodAnchor: anchor,
      );
      expect(state, isA<RunningTrusted>());
    }
    watch.stop();
    // ignore: avoid_print
    print('display-only x20000: ${watch.elapsedMicroseconds} us');
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });

  test('authoritative match end and abandonment do not keep a ticking clock',
      () {
    final ended = [
      ..._secondPeriod(anchorId: 'p2'),
      _transition(
        'p2-end',
        V1SemanticTypeCode.periodEnded,
        6,
        period: 2,
        dependsOn: 'p2',
        evidenceId: 'p2-end',
      ),
      _transition(
        'match-end',
        V1SemanticTypeCode.matchEnded,
        7,
        dependsOn: 'p2-end',
      ),
    ];
    final abandoned = [
      ..._period(anchorId: 'anchor'),
      _transition('abandoned', V1SemanticTypeCode.matchAbandoned, 3),
    ];
    final endedState = _show(
      projector: projector,
      records: ended,
      format: format,
      anchor: _point('p2', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(hours: 4)),
      evidence: [
        _point('p1', anchorAt, Duration.zero),
        _point('p1-end', anchorAt, const Duration(minutes: 45)),
        _point('p2', anchorAt, Duration.zero),
        _point('p2-end', anchorAt, const Duration(minutes: 45)),
      ],
    );
    final abandonedState = _show(
      projector: projector,
      records: abandoned,
      format: format,
      anchor: _point('anchor', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(hours: 4)),
    );

    expect(endedState, isA<InactiveTrusted>());
    expect(
        (endedState as InactiveTrusted).lifecycle, InactiveLifecycle.terminal);
    expect(endedState.matchNormallyEnded, isTrue);
    expect(exactTickingClock(endedState), isNull);
    expect(abandonedState, isA<InactiveTrusted>());
    expect((abandonedState as InactiveTrusted).lifecycle,
        InactiveLifecycle.terminal);
    expect(abandonedState.matchAbandoned, isTrue);
    expect(exactTickingClock(abandonedState), isNull);
  });
}

/// The only legal exact ticking value. Every other variant has none.
Duration? exactTickingClock(TemporalDisplayState state) {
  return switch (state) {
    RunningTrusted(:final footballTime) => footballTime,
    RunningBounded() => null,
    Unresolved() => null,
    SuspendedTrusted() => null,
    InactiveTrusted() => null,
  };
}

Duration? frozenExact(SuspensionElapsed elapsed) {
  return switch (elapsed) {
    ExactSuspensionElapsed(:final footballTime) => footballTime,
    BoundedSuspensionElapsed() => null,
    UnavailableSuspensionElapsed() => null,
  };
}

final class _Formats {
  static final standard = MatchFormatClockContext(
    periods: const [
      PeriodClockCoordinate(
        period: PeriodIdentity(index: 1),
        nominalBase: Duration.zero,
        nominalLength: Duration(minutes: 45),
      ),
      PeriodClockCoordinate(
        period: PeriodIdentity(index: 2),
        nominalBase: Duration(minutes: 45),
        nominalLength: Duration(minutes: 45),
      ),
      PeriodClockCoordinate(
        period: PeriodIdentity(index: 3),
        nominalBase: Duration(minutes: 90),
        nominalLength: Duration(minutes: 15),
      ),
      PeriodClockCoordinate(
        period: PeriodIdentity(index: 4),
        nominalBase: Duration(minutes: 105),
        nominalLength: Duration(minutes: 15),
      ),
    ],
  );

  static final youth = MatchFormatClockContext(
    periods: const [
      PeriodClockCoordinate(
        period: PeriodIdentity(index: 1),
        nominalBase: Duration.zero,
        nominalLength: Duration(minutes: 30),
      ),
      PeriodClockCoordinate(
        period: PeriodIdentity(index: 2),
        nominalBase: Duration(minutes: 30),
        nominalLength: Duration(minutes: 30),
      ),
    ],
  );
}

RunningTrusted _overrun(
  DeterministicMatchProjector projector,
  MatchFormatClockContext format,
  DateTime anchorAt,
) {
  return _show(
    projector: projector,
    records: _period(anchorId: 'anchor'),
    format: format,
    anchor: _point('anchor', anchorAt, Duration.zero),
    current: _point('live', anchorAt, const Duration(minutes: 48, seconds: 37)),
  ) as RunningTrusted;
}

TemporalDisplayState _bounded(
  DeterministicMatchProjector projector,
  MatchFormatClockContext format,
  DateTime anchorAt,
) {
  return _show(
    projector: projector,
    records: _period(anchorId: 'anchor'),
    format: format,
    anchor: _point('anchor', anchorAt, const Duration(seconds: 2)),
    current: TemporalEvidence(
      evidenceId: 'live',
      capturedAt: anchorAt,
      continuityDomainId: 'domain-1',
      monotonicElapsed: const Duration(seconds: 12),
      monotonicUpperBound: const Duration(seconds: 15),
    ),
  );
}

TemporalDisplayState _unresolvedDomain(
  DeterministicMatchProjector projector,
  MatchFormatClockContext format,
  DateTime anchorAt,
) {
  return _show(
    projector: projector,
    records: _period(anchorId: 'anchor'),
    format: format,
    anchor: _point('anchor', anchorAt, Duration.zero, domainId: 'domain-a'),
    current: _point(
      'live',
      anchorAt,
      const Duration(minutes: 10),
      domainId: 'domain-b',
    ),
  );
}

TemporalDisplayState _show({
  required DeterministicMatchProjector projector,
  required List<MatchRecord> records,
  required MatchFormatClockContext format,
  required TemporalEvidence anchor,
  required TemporalEvidence current,
  List<TemporalEvidence> evidence = const [],
  TemporalEvidence? suspensionBoundary,
  TemporalEvidence? resumptionAnchor,
  int evaluatedGeneration = 1,
  Duration? historicalElapsed,
  PeriodIdentity? historicalPeriod,
  ActivePeriodElapsedProjection? elapsedOverride,
}) {
  final projection =
      _project(projector, records, generation: evaluatedGeneration);
  final lifecycle = TemporalMatchProjection.derive(
    projection: projection,
    records: records,
  );
  final elapsed = elapsedOverride ??
      deriveActivePeriodElapsed(
        temporal: lifecycle,
        projection: projection,
        records: records,
        anchor: anchor,
        current: current,
        suspensionBoundary: suspensionBoundary,
        resumptionAnchor: resumptionAnchor,
        recordedEvidence: evidence,
      );
  return projectTemporalDisplay(
    lifecycle: lifecycle,
    elapsed: elapsed,
    projection: projection,
    format: format,
    periodAnchor: anchor,
    suspensionBoundary: suspensionBoundary,
    historicalLastProvenActiveElapsed: historicalElapsed,
    historicalLastProvenPeriod: historicalPeriod,
  );
}

MatchProjectionState _project(
  DeterministicMatchProjector projector,
  List<MatchRecord> records, {
  int generation = 1,
}) {
  return projector.projectRecords(
    matchId: 'match-1',
    records: records,
    context: ProjectionContext(evaluatedAuthorityGeneration: generation),
  );
}

ActivePeriodElapsedProjection _forgedElapsed({
  required PeriodIdentity period,
  TemporalContinuityStatus continuity =
      TemporalContinuityStatus.exactContinuity,
  Duration? exact,
  ProjectionTrust trust = ProjectionTrust.trusted,
}) {
  return ActivePeriodElapsedProjection(
    activePeriod: period,
    continuity: continuity,
    temporalTrust: trust,
    exactElapsed: exact,
    elapsedLowerBound: null,
    elapsedUpperBound: null,
    precisionSafeToShow: continuity == TemporalContinuityStatus.exactContinuity,
    certified: false,
    pastRegulationDisplayThreshold: false,
    formalSuspensionActive: false,
    suspensionStarted: false,
    suspensionDurationOpen: false,
    suspensionEnded: false,
    suspensionDuration: null,
    suspensionDurationLowerBound: null,
    suspensionDurationUpperBound: null,
    suspensionDurations: const [],
    playingSegments: const [],
    periodEnded: false,
  );
}

const _authority = AuthorityContext(
  scope: v1AuthorityScope,
  principal: AuthorityPrincipal(principalId: 'ref-1'),
  activeCaptureDevice: ActiveCaptureDevice(deviceId: 'device-1'),
  generation: AuthorityGeneration(value: 1),
);

List<MatchRecord> _period({required String anchorId, int generation = 1}) {
  return [
    _transition('start', V1SemanticTypeCode.matchStarted, 1,
        generation: generation),
    _transition(
      'period',
      V1SemanticTypeCode.periodStarted,
      2,
      period: 1,
      dependsOn: 'start',
      evidenceId: anchorId,
      generation: generation,
    ),
  ];
}

List<MatchRecord> _suspended({
  required String anchorId,
  required String boundaryId,
}) {
  return [
    ..._period(anchorId: anchorId),
    _transition(
      'susp',
      V1SemanticTypeCode.temporarySuspensionStarted,
      3,
      period: 1,
      dependsOn: 'period',
      evidenceId: boundaryId,
    ),
  ];
}

List<MatchRecord> _resumed({
  required String anchorId,
  required String boundaryId,
  required String resumptionId,
}) {
  return [
    ..._suspended(anchorId: anchorId, boundaryId: boundaryId),
    _transition(
      'resume',
      V1SemanticTypeCode.temporarySuspensionEnded,
      4,
      period: 1,
      dependsOn: 'susp',
      evidenceId: resumptionId,
    ),
  ];
}

List<MatchRecord> _periodEnded(
    {required String anchorId, required String endId}) {
  return [
    ..._period(anchorId: anchorId),
    _transition(
      endId,
      V1SemanticTypeCode.periodEnded,
      3,
      period: 1,
      dependsOn: 'period',
      evidenceId: endId,
    ),
  ];
}

List<MatchRecord> _secondPeriod({required String anchorId}) {
  return [
    _transition('start', V1SemanticTypeCode.matchStarted, 1),
    _transition(
      'p1',
      V1SemanticTypeCode.periodStarted,
      2,
      period: 1,
      dependsOn: 'start',
      evidenceId: 'p1',
    ),
    _transition(
      'p1-end',
      V1SemanticTypeCode.periodEnded,
      3,
      period: 1,
      dependsOn: 'p1',
      evidenceId: 'p1-end',
    ),
    _transition(
      anchorId,
      V1SemanticTypeCode.periodStarted,
      4,
      period: 2,
      dependsOn: 'p1-end',
      evidenceId: anchorId,
    ),
  ];
}

List<MatchRecord> _throughPeriod(int lastIndex, {required bool endLast}) {
  final records = <MatchRecord>[
    _transition('start', V1SemanticTypeCode.matchStarted, 1),
  ];
  var sequence = 2;
  String? previousEnd;
  for (var index = 1; index <= lastIndex; index++) {
    final startId = 'p$index';
    records.add(
      _transition(
        startId,
        V1SemanticTypeCode.periodStarted,
        sequence,
        period: index,
        dependsOn: previousEnd ?? 'start',
        evidenceId: startId,
      ),
    );
    sequence++;
    final ended = index < lastIndex || endLast;
    if (!ended) continue;
    final endId = 'p$index-end';
    records.add(
      _transition(
        endId,
        V1SemanticTypeCode.periodEnded,
        sequence,
        period: index,
        dependsOn: startId,
        evidenceId: endId,
      ),
    );
    sequence++;
    previousEnd = endId;
  }
  return records;
}

List<TemporalEvidence> _chainEvidence(int lastIndex, {required bool endLast}) {
  final wall = DateTime.utc(2026, 10, 14, 12);
  final evidence = <TemporalEvidence>[];
  for (var index = 1; index <= lastIndex; index++) {
    final start = index == 3
        ? const Duration(seconds: 1000)
        : Duration(seconds: index * 10);
    evidence.add(_point('p$index', wall, start));
    final ended = index < lastIndex || endLast;
    if (!ended) continue;
    final end = index == 3
        ? start + const Duration(minutes: 20)
        : start + const Duration(seconds: 10);
    evidence.add(_point('p$index-end', wall, end));
  }
  return evidence;
}

MatchRecord _occurrence(String id, int sequence, Map<String, Object?> payload) {
  return MatchRecord(
    recordId: id,
    matchId: 'match-1',
    recordKind: RecordKind.occurrence,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 14, 12, sequence),
    originDeviceId: 'dev-a',
    originSequence: sequence,
    payload: StructuredPayload(payload),
    integrity: const IntegrityMetadata(),
    authorityContext: _authority,
  );
}

MatchRecord _transition(
  String id,
  V1SemanticTypeCode code,
  int sequence, {
  int? period,
  String? dependsOn,
  String? evidenceId,
  int generation = 1,
  String principalId = 'ref-1',
  int schemaVersion = 1,
}) {
  return MatchRecord(
    recordId: id,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: schemaVersion,
    recordedAt: DateTime.utc(2026, 10, 14, 12, sequence),
    originDeviceId: 'dev-a',
    originSequence: sequence,
    payload: TemporalTransitionPayload(
      semanticType: code,
      period: period == null ? null : PeriodIdentity(index: period),
    ),
    integrity: const IntegrityMetadata(),
    temporalContext: evidenceId == null
        ? null
        : TemporalContext(
            evidenceIds: [evidenceId],
            domainClockPolicyVersion: 'domain-clock-v1',
          ),
    authorityContext: AuthorityContext(
      scope: v1AuthorityScope,
      principal: AuthorityPrincipal(principalId: principalId),
      activeCaptureDevice: const ActiveCaptureDevice(deviceId: 'device-1'),
      generation: AuthorityGeneration(value: generation),
    ),
    relationships: [
      if (dependsOn != null) CausalDependency(targetRecordId: dependsOn),
    ],
  );
}

TemporalEvidence _point(
  String evidenceId,
  DateTime capturedAt,
  Duration monotonic, {
  String domainId = 'domain-1',
}) {
  return TemporalEvidence(
    evidenceId: evidenceId,
    capturedAt: capturedAt,
    continuityDomainId: domainId,
    monotonicElapsed: monotonic,
  );
}

bool _isSuspension(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.temporarySuspensionStarted;
}

bool _isPeriodEnd(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodEnded;
}

bool _isPeriodStart(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodStarted;
}

bool _isMatchEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.matchEnded;
}

int? _periodIndex(MatchRecord record) {
  final payload = record.payload;
  if (payload is! TemporalTransitionPayload) return null;
  return payload.period?.index;
}
