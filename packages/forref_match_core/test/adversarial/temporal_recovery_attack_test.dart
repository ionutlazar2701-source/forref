import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

/// Attacks false temporal precision and false period-end authority.
///
/// Evidence is supplied through the public derivation API. Nothing here
/// certifies a device clock, and [TemporalEvidence.certified] is only an
/// input flag the projection must refuse.
void main() {
  const threshold = ActivePeriodElapsedProjection.regulationDisplayThreshold;

  group('unavailable constant', () {
    test('is unresolved, untrusted, uncertified, and not a period end', () {
      const unavailable = ActivePeriodElapsedProjection.unavailable;

      expect(unavailable.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(unavailable.temporalTrust, ProjectionTrust.untrusted);
      expect(unavailable.certified, isFalse);
      expect(unavailable.periodEnded, isFalse);
      expect(unavailable.pastRegulationDisplayThreshold, isFalse);
      expect(unavailable.activePeriod, isNull);
      expect(threshold, const Duration(minutes: 45));
      _expectNoFalsePrecision(unavailable);
    });

    test('empty memory plus a certified past-45 sample stays unavailable', () {
      final spoofed = _certifiedPoint(
        'live',
        DateTime.utc(2099, 1, 1),
        const Duration(minutes: 90),
      );
      final reading = _read(
        records: const <MatchRecord>[],
        anchor: spoofed,
        current: spoofed,
      );

      expect(reading.projection.trustFor(ProjectionFacet.temporal),
          ProjectionTrust.untrusted);
      expect(reading.temporal.matchStarted, isFalse);
      expect(reading.elapsed, ActivePeriodElapsedProjection.unavailable);
      expect(reading.elapsed.exactElapsed, isNot(spoofed.monotonicElapsed));
      _expectNoFalsePrecision(reading.elapsed);
    });
  });

  group('unresolved continuity', () {
    test('a forged anchor id does not create exact elapsed', () {
      final records = _startedPeriod(anchorId: 'committed-anchor');
      final reading = _read(
        records: records,
        anchor: _point(
          'forged-anchor',
          DateTime.utc(2026, 10, 3, 12),
          Duration.zero,
        ),
        current: _certifiedPoint(
          'live',
          DateTime.utc(2026, 10, 3, 13),
          threshold + const Duration(seconds: 1),
        ),
      );

      expect(reading.projection.trustFor(ProjectionFacet.temporal),
          ProjectionTrust.trusted);
      expect(reading.temporal.activePeriod, const PeriodIdentity(index: 1));
      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(reading.elapsed.activePeriod, const PeriodIdentity(index: 1));
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(records.where(_isPeriodEnded), isEmpty);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('absent continuity fields do not fall back to wall-clock subtraction',
        () {
      final records = _startedPeriod(anchorId: 'anchor-1');
      final wallStart = DateTime.utc(2026, 10, 3, 12);
      final wallEnd = wallStart.add(const Duration(minutes: 45));
      final missingMonotonic = _read(
        records: records,
        anchor: TemporalEvidence(
          evidenceId: 'anchor-1',
          capturedAt: wallStart,
          continuityDomainId: 'domain-1',
        ),
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: wallEnd,
          continuityDomainId: 'domain-1',
          monotonicElapsed: threshold,
          certified: true,
        ),
      );
      final missingDomain = _read(
        records: records,
        anchor: _point('anchor-1', wallStart, Duration.zero, domainId: null),
        current: _point('live', wallEnd, threshold, domainId: null),
      );

      expect(missingMonotonic.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(missingMonotonic.elapsed.exactElapsed, isNot(threshold));
      expect(missingDomain.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(missingDomain.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(missingMonotonic.elapsed);
      _expectNoFalsePrecision(missingDomain.elapsed);
    });

    test('a reversed monotonic reading is not clamped to an exact elapsed', () {
      final records = _startedPeriod(anchorId: 'anchor-1');
      final reading = _read(
        records: records,
        anchor: _point('anchor-1', DateTime.utc(2026, 10, 3, 18),
            const Duration(seconds: 20)),
        current: _point(
            'live', DateTime.utc(2026, 10, 3, 12), const Duration(seconds: 5)),
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(reading.elapsed.exactElapsed, isNot(Duration.zero));
      expect(reading.elapsed.exactElapsed, isNot(const Duration(seconds: -15)));
      expect(reading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('an interval that starts before the anchor is not clipped', () {
      final records = _startedPeriod(anchorId: 'anchor-1');
      final reading = _read(
        records: records,
        anchor: _point('anchor-1', DateTime.utc(2026, 10, 3, 12),
            const Duration(seconds: 10)),
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: DateTime.utc(2026, 10, 3, 13),
          continuityDomainId: 'domain-1',
          monotonicElapsed: const Duration(seconds: 8),
          monotonicUpperBound: const Duration(seconds: 30),
          certified: true,
        ),
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(reading.elapsed.exactElapsed, isNot(const Duration(seconds: 20)));
      expect(reading.elapsed.elapsedLowerBound, isNot(Duration.zero));
      expect(reading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('near-identical continuity domains stay unresolved', () {
      final records = _startedPeriod(anchorId: 'anchor-1');
      final reading = _read(
        records: records,
        anchor: _point(
          'anchor-1',
          DateTime.utc(2026, 10, 3, 12),
          Duration.zero,
          domainId: 'domain-1',
        ),
        current: _certifiedPoint(
          'live',
          DateTime.utc(2026, 10, 3, 13),
          threshold,
          domainId: 'Domain-1',
        ),
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(reading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('incomplete temporal trust hides a certified exact sample', () {
      final records = [
        ..._startedPeriod(anchorId: 'anchor-1'),
        _record(
          'orphan-suspension',
          V1SemanticTypeCode.temporarySuspensionStarted,
          originSequence: 3,
          period: const PeriodIdentity(index: 1),
          relationships: [
            CausalDependency(targetRecordId: 'missing-suspension-cause')
          ],
          temporalContext: const TemporalContext(evidenceIds: ['boundary-1']),
        ),
      ];
      final reading = _read(
        records: records,
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: _certifiedPoint(
          'live',
          DateTime.utc(2099),
          threshold + const Duration(seconds: 1),
        ),
        suspensionBoundary: _point(
          'boundary-1',
          DateTime.utc(2026, 10, 3, 12, 30),
          threshold,
        ),
      );

      expect(reading.projection.trustFor(ProjectionFacet.temporal),
          ProjectionTrust.incomplete);
      expect(reading.elapsed.temporalTrust, ProjectionTrust.incomplete);
      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(reading.elapsed, isNot(ActivePeriodElapsedProjection.unavailable));
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('conflicted temporal authority hides a certified exact sample', () {
      final records = [
        _record(
          'start-a',
          V1SemanticTypeCode.matchStarted,
          originSequence: 1,
          authorityContext: _authority('ref-a'),
        ),
        _record(
          'start-b',
          V1SemanticTypeCode.matchStarted,
          originSequence: 2,
          authorityContext: _authority('ref-b'),
        ),
      ];
      final reading = _read(
        records: records,
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: _certifiedPoint(
            'live', DateTime.utc(2099), const Duration(hours: 2)),
      );

      expect(reading.projection.trustFor(ProjectionFacet.temporal),
          ProjectionTrust.conflicted);
      expect(reading.elapsed.temporalTrust, ProjectionTrust.conflicted);
      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(reading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('match start without a period does not invent elapsed or period end',
        () {
      final records = [
        _record('start', V1SemanticTypeCode.matchStarted, originSequence: 1),
      ];
      final reading = _read(
        records: records,
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: _certifiedPoint('live', DateTime.utc(2099), threshold),
      );

      expect(reading.temporal.matchStarted, isTrue);
      expect(reading.temporal.temporallyIncomplete, isTrue);
      expect(reading.temporal.activePeriod, isNull);
      expect(reading.elapsed.temporalTrust, ProjectionTrust.trusted);
      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.continuityUnresolved);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed, isNot(ActivePeriodElapsedProjection.unavailable));
      _expectNoFalsePrecision(reading.elapsed);
    });
  });

  group('regulation display threshold is not period end', () {
    test('exact 45:00 raises only the display flag', () {
      final records = _startedPeriod(anchorId: 'anchor-1');
      final idsBefore = [for (final record in records) record.recordId];
      final reading = _read(
        records: records,
        anchor: _certifiedPoint(
            'anchor-1', DateTime.utc(1970, 1, 1), Duration.zero),
        current: _certifiedPoint(
          'live',
          DateTime.utc(2099, 6, 1),
          threshold,
        ),
      );

      expect(reading.temporal.activePeriod, const PeriodIdentity(index: 1));
      expect(reading.elapsed.exactElapsed, threshold);
      expect(reading.elapsed.pastRegulationDisplayThreshold, isTrue);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed.certified, isFalse);
      expect(reading.projection.committedRecordIds, idsBefore);
      expect(records.where(_isPeriodEnded), isEmpty);
      _expectThresholdDoesNotEndPeriod(reading.elapsed);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('one microsecond before 45:00 is not rounded up', () {
      final justUnder = threshold - const Duration(microseconds: 1);
      final reading = _read(
        records: _startedPeriod(anchorId: 'anchor-1'),
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current:
            _point('live', DateTime.utc(2026, 10, 3, 12, 44, 59), justUnder),
      );

      expect(
          reading.elapsed.continuity, TemporalContinuityStatus.exactContinuity);
      expect(reading.elapsed.exactElapsed, justUnder);
      expect(reading.elapsed.exactElapsed, isNot(threshold));
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(reading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('a sub-second exact reading is not rounded to a whole second', () {
      const elapsed = Duration(milliseconds: 1500);
      final reading = _read(
        records: _startedPeriod(anchorId: 'anchor-1'),
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: _certifiedPoint('live', DateTime.utc(2099), elapsed),
      );

      expect(reading.elapsed.exactElapsed, elapsed);
      expect(reading.elapsed.exactElapsed, isNot(const Duration(seconds: 1)));
      expect(reading.elapsed.exactElapsed, isNot(const Duration(seconds: 2)));
      expect(reading.elapsed.certified, isFalse);
      expect(reading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('wall clock past 90 minutes does not end a short monotonic period',
        () {
      final reading = _read(
        records: _startedPeriod(
          anchorId: 'anchor-1',
          periodRecordedAt: DateTime.utc(2099, 1, 1),
        ),
        anchor: _point('anchor-1', DateTime.utc(2099, 1, 1), Duration.zero),
        current: _point(
          'live',
          DateTime.utc(1970, 1, 1),
          const Duration(seconds: 10),
        ),
      );

      expect(reading.elapsed.exactElapsed, const Duration(seconds: 10));
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.temporal.activePeriod, const PeriodIdentity(index: 1));
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('a bounded span around 45:00 is not an exact period end', () {
      final reading = _read(
        records: _startedPeriod(anchorId: 'anchor-1'),
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: DateTime.utc(2026, 10, 3, 13),
          continuityDomainId: 'domain-1',
          monotonicElapsed: threshold - const Duration(seconds: 1),
          monotonicUpperBound: threshold + const Duration(seconds: 1),
          certified: true,
        ),
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.boundedContinuity);
      expect(reading.elapsed.elapsedLowerBound,
          threshold - const Duration(seconds: 1));
      expect(reading.elapsed.elapsedUpperBound,
          threshold + const Duration(seconds: 1));
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed.playingSegments, [null]);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('a zero-width interval at 45:00 stays bounded', () {
      final reading = _read(
        records: _startedPeriod(anchorId: 'anchor-1'),
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: DateTime.utc(2026, 10, 3, 12, 45),
          continuityDomainId: 'domain-1',
          monotonicElapsed: threshold,
          monotonicUpperBound: threshold,
          certified: true,
        ),
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.boundedContinuity);
      expect(reading.elapsed.elapsedLowerBound, threshold);
      expect(reading.elapsed.elapsedUpperBound, threshold);
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(reading.elapsed.precisionSafeToShow, isFalse);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed.certified, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('an interval wholly past 45:00 still does not end the period', () {
      final reading = _read(
        records: _startedPeriod(anchorId: 'anchor-1'),
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: DateTime.utc(2099),
          continuityDomainId: 'domain-1',
          monotonicElapsed: const Duration(minutes: 46),
          monotonicUpperBound: const Duration(minutes: 47),
        ),
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.boundedContinuity);
      expect(reading.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.temporal.activePeriod, const PeriodIdentity(index: 1));
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('open suspension at 45:01 is not period end and does not add time',
        () {
      final records = [
        ..._startedPeriod(anchorId: 'anchor-1'),
        _record(
          'susp',
          V1SemanticTypeCode.temporarySuspensionStarted,
          originSequence: 3,
          period: const PeriodIdentity(index: 1),
          relationships: [CausalDependency(targetRecordId: 'period')],
          temporalContext: const TemporalContext(evidenceIds: ['boundary-1']),
        ),
      ];
      final atBoundary = threshold + const Duration(seconds: 1);
      final reading = _read(
        records: records,
        anchor:
            _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        current: _certifiedPoint(
            'live', DateTime.utc(2099), const Duration(hours: 2)),
        suspensionBoundary: _point(
          'boundary-1',
          DateTime.utc(1970),
          atBoundary,
        ),
      );

      expect(reading.temporal.formallySuspended, isTrue);
      expect(reading.elapsed.formalSuspensionActive, isTrue);
      expect(reading.elapsed.exactElapsed, atBoundary);
      expect(reading.elapsed.pastRegulationDisplayThreshold, isTrue);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed.exactElapsed, isNot(const Duration(hours: 2)));
      expect(records.where(_isPeriodEnded), isEmpty);
      _expectThresholdDoesNotEndPeriod(reading.elapsed);
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('an early period end is not rewritten to 45:00', () {
      const whistle = Duration(seconds: 12);
      final records = [
        ..._startedPeriod(anchorId: 'anchor-1'),
        _record(
          'period-end',
          V1SemanticTypeCode.periodEnded,
          originSequence: 3,
          period: const PeriodIdentity(index: 1),
          relationships: [CausalDependency(targetRecordId: 'period')],
          temporalContext: const TemporalContext(evidenceIds: ['end-1']),
        ),
      ];
      final evidence = [
        _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        _point('end-1', DateTime.utc(2026, 10, 3, 12, 0, 12), whistle),
      ];
      final ended = _read(
        records: records,
        anchor: evidence.first,
        current: _certifiedPoint(
            'live', DateTime.utc(2099), const Duration(hours: 3)),
        recordedEvidence: evidence,
      );
      final stillEnded = _read(
        records: records,
        anchor: evidence.first,
        current: _certifiedPoint(
            'live', DateTime.utc(1970), threshold + const Duration(seconds: 1)),
        recordedEvidence: evidence,
      );

      expect(ended.temporal.activePeriod, isNull);
      expect(ended.temporal.endedPeriod, const PeriodIdentity(index: 1));
      expect(ended.elapsed.periodEnded, isTrue);
      expect(ended.elapsed.exactElapsed, whistle);
      expect(ended.elapsed.pastRegulationDisplayThreshold, isFalse);
      expect(stillEnded.elapsed, ended.elapsed);
      expect(stillEnded.elapsed.exactElapsed, isNot(threshold));
      expect(stillEnded.elapsed.pastRegulationDisplayThreshold, isFalse);
      _expectNoFalsePrecision(ended.elapsed);
      _expectNoFalsePrecision(stillEnded.elapsed);
    });
  });

  group('exact and bounded are mutually exclusive', () {
    test('the same records yield one mode for each evidence shape', () {
      final records = _startedPeriod(anchorId: 'anchor-1');
      final exact = _read(
        records: records,
        anchor: _point('anchor-1', DateTime.utc(2026, 10, 3, 12),
            const Duration(seconds: 2)),
        current: _certifiedPoint(
          'live',
          DateTime.utc(2026, 10, 3, 18),
          const Duration(seconds: 17),
        ),
      );
      final bounded = _read(
        records: records,
        anchor: _point('anchor-1', DateTime.utc(2026, 10, 3, 12),
            const Duration(seconds: 2)),
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: DateTime.utc(2026, 10, 3, 18),
          continuityDomainId: 'domain-1',
          monotonicElapsed: const Duration(seconds: 12),
          monotonicUpperBound: const Duration(seconds: 15),
          certified: true,
        ),
      );

      expect(
          exact.elapsed.continuity, TemporalContinuityStatus.exactContinuity);
      expect(exact.elapsed.exactElapsed, const Duration(seconds: 15));
      expect(exact.elapsed.precisionSafeToShow, isTrue);
      expect(bounded.elapsed.continuity,
          TemporalContinuityStatus.boundedContinuity);
      expect(bounded.elapsed.elapsedLowerBound, const Duration(seconds: 10));
      expect(bounded.elapsed.elapsedUpperBound, const Duration(seconds: 13));
      expect(bounded.elapsed.precisionSafeToShow, isFalse);
      expect(exact.elapsed.continuity, isNot(bounded.elapsed.continuity));
      expect(exact.elapsed, isNot(bounded.elapsed));
      _expectNoFalsePrecision(exact.elapsed);
      _expectNoFalsePrecision(bounded.elapsed);
    });

    test('an exact segment plus an interval sample does not collapse', () {
      final records = [
        ..._startedPeriod(anchorId: 'anchor'),
        _record(
          'susp',
          V1SemanticTypeCode.temporarySuspensionStarted,
          originSequence: 3,
          period: const PeriodIdentity(index: 1),
          relationships: [CausalDependency(targetRecordId: 'period')],
          temporalContext: const TemporalContext(evidenceIds: ['boundary']),
        ),
        _record(
          'resume',
          V1SemanticTypeCode.temporarySuspensionEnded,
          originSequence: 4,
          period: const PeriodIdentity(index: 1),
          relationships: [CausalDependency(targetRecordId: 'susp')],
          temporalContext: const TemporalContext(evidenceIds: ['resume']),
        ),
      ];
      final evidence = [
        _point('anchor', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        _point('boundary', DateTime.utc(2026, 10, 3, 12, 0, 10),
            const Duration(seconds: 10)),
        _point('resume', DateTime.utc(2099), const Duration(seconds: 40)),
      ];
      final reading = _read(
        records: records,
        anchor: evidence.first,
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: DateTime.utc(1970),
          continuityDomainId: 'domain-1',
          monotonicElapsed: const Duration(seconds: 50),
          monotonicUpperBound: const Duration(seconds: 55),
          certified: true,
        ),
        recordedEvidence: evidence,
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.boundedContinuity);
      expect(reading.elapsed.elapsedLowerBound, const Duration(seconds: 20));
      expect(reading.elapsed.elapsedUpperBound, const Duration(seconds: 25));
      expect(reading.elapsed.playingSegments, [
        const Duration(seconds: 10),
        null,
      ]);
      expect(
          reading.elapsed.suspensionDurations, [const Duration(seconds: 30)]);
      expect(reading.elapsed.periodEnded, isFalse);
      expect(reading.elapsed.exactElapsed, isNot(const Duration(seconds: 22)));
      expect(reading.elapsed.exactElapsed, isNot(const Duration(seconds: 55)));
      _expectNoFalsePrecision(reading.elapsed);
    });

    test('both interval endpoints stay bounds rather than one exact second',
        () {
      final reading = _read(
        records: _startedPeriod(anchorId: 'anchor-1'),
        anchor: TemporalEvidence(
          evidenceId: 'anchor-1',
          capturedAt: DateTime.utc(2026, 10, 3, 12),
          continuityDomainId: 'domain-1',
          monotonicElapsed: Duration.zero,
          monotonicUpperBound: const Duration(seconds: 2),
        ),
        current: TemporalEvidence(
          evidenceId: 'live',
          capturedAt: DateTime.utc(2026, 10, 3, 13),
          continuityDomainId: 'domain-1',
          monotonicElapsed: const Duration(seconds: 10),
          monotonicUpperBound: const Duration(seconds: 14),
          certified: true,
        ),
      );

      expect(reading.elapsed.continuity,
          TemporalContinuityStatus.boundedContinuity);
      expect(reading.elapsed.elapsedLowerBound, const Duration(seconds: 8));
      expect(reading.elapsed.elapsedUpperBound, const Duration(seconds: 14));
      expect(reading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(reading.elapsed);
    });
  });

  group('repeated projection is deterministic', () {
    test('order and a fresh projector rebuild the same elapsed', () {
      final records = [
        _record(
          'period',
          V1SemanticTypeCode.periodStarted,
          originSequence: 1,
          originDeviceId: 'dev-a',
          period: const PeriodIdentity(index: 1),
          relationships: [CausalDependency(targetRecordId: 'start')],
          temporalContext: const TemporalContext(evidenceIds: ['anchor-1']),
        ),
        _record(
          'start',
          V1SemanticTypeCode.matchStarted,
          originSequence: 5,
          originDeviceId: 'dev-z',
        ),
      ];
      final orders = [
        records,
        records.reversed.toList(),
        [records.last, records.first],
      ];
      final projectors = [
        _projector,
        DeterministicMatchProjector(ProductionSemanticsResolver()),
      ];
      final readings = [
        for (final projector in projectors)
          for (final order in orders)
            _read(
              projector: projector,
              records: order,
              anchor: _point('anchor-1', DateTime.utc(1970), Duration.zero),
              current: _certifiedPoint(
                'live',
                DateTime.utc(2099),
                const Duration(seconds: 15),
              ),
            ),
      ];

      expect(readings, hasLength(6));
      for (final reading in readings.skip(1)) {
        expect(reading.elapsed, readings.first.elapsed);
        expect(reading.elapsed.hashCode, readings.first.elapsed.hashCode);
        expect(reading.temporal.activePeriod,
            readings.first.temporal.activePeriod);
        expect(reading.projection.committedRecordIds,
            readings.first.projection.committedRecordIds);
      }
      expect(readings.first.elapsed.exactElapsed, const Duration(seconds: 15));
      expect(readings.first.elapsed.periodEnded, isFalse);
      expect(readings.first.projection.committedRecordIds, ['period', 'start']);
      _expectNoFalsePrecision(readings.first.elapsed);
    });

    test('the same ended records stay frozen while the live sample moves', () {
      final records = [
        ..._startedPeriod(anchorId: 'anchor-1'),
        _record(
          'period-end',
          V1SemanticTypeCode.periodEnded,
          originSequence: 3,
          period: const PeriodIdentity(index: 1),
          relationships: [CausalDependency(targetRecordId: 'period')],
          temporalContext: const TemporalContext(evidenceIds: ['end-1']),
        ),
      ];
      final evidence = [
        _point('anchor-1', DateTime.utc(2026, 10, 3, 12), Duration.zero),
        _point('end-1', DateTime.utc(2026, 10, 3, 12, 20),
            const Duration(seconds: 25)),
      ];
      final samples = [
        const Duration(seconds: 25),
        threshold,
        const Duration(hours: 3),
      ];
      final readings = [
        for (final sample in samples)
          _read(
            records: records,
            anchor: evidence.first,
            current: _certifiedPoint('live', DateTime.utc(2099), sample),
            recordedEvidence: evidence,
          ),
      ];

      for (final reading in readings) {
        expect(reading.elapsed, readings.first.elapsed);
        expect(reading.elapsed.periodEnded, isTrue);
        expect(reading.elapsed.exactElapsed, const Duration(seconds: 25));
        expect(reading.elapsed.exactElapsed, isNot(const Duration(hours: 3)));
        _expectNoFalsePrecision(reading.elapsed);
      }
    });

    test('recordedAt changes do not change elapsed for the same transitions',
        () {
      final early = _startedPeriod(
        anchorId: 'anchor-1',
        periodRecordedAt: DateTime.utc(1970, 1, 1),
      );
      final late = _startedPeriod(
        anchorId: 'anchor-1',
        periodRecordedAt: DateTime.utc(2099, 12, 31),
      );
      final earlyReading = _read(
        records: early,
        anchor:
            _point('anchor-1', DateTime.utc(2099), const Duration(seconds: 4)),
        current: _point('live', DateTime.utc(1970), const Duration(seconds: 9)),
      );
      final lateReading = _read(
        records: late,
        anchor:
            _point('anchor-1', DateTime.utc(1970), const Duration(seconds: 4)),
        current: _point('live', DateTime.utc(2099), const Duration(seconds: 9)),
      );

      expect(earlyReading.elapsed, lateReading.elapsed);
      expect(earlyReading.elapsed.exactElapsed, const Duration(seconds: 5));
      expect(earlyReading.elapsed.periodEnded, isFalse);
      _expectNoFalsePrecision(earlyReading.elapsed);
    });
  });
}

void _expectNoFalsePrecision(ActivePeriodElapsedProjection elapsed) {
  expect(elapsed.certified, isFalse);
  final hasExact = elapsed.exactElapsed != null;
  final hasBound =
      elapsed.elapsedLowerBound != null || elapsed.elapsedUpperBound != null;
  expect(hasExact && hasBound, isFalse);

  switch (elapsed.continuity) {
    case TemporalContinuityStatus.continuityUnresolved:
      expect(elapsed.exactElapsed, isNull);
      expect(elapsed.elapsedLowerBound, isNull);
      expect(elapsed.elapsedUpperBound, isNull);
      expect(elapsed.precisionSafeToShow, isFalse);
    case TemporalContinuityStatus.boundedContinuity:
      expect(elapsed.exactElapsed, isNull);
      expect(elapsed.precisionSafeToShow, isFalse);
      expect(elapsed.elapsedLowerBound, isNotNull);
      expect(elapsed.elapsedUpperBound, isNotNull);
      expect(elapsed.elapsedUpperBound! >= elapsed.elapsedLowerBound!, isTrue);
    case TemporalContinuityStatus.exactContinuity:
      expect(elapsed.exactElapsed, isNotNull);
      expect(elapsed.elapsedLowerBound, isNull);
      expect(elapsed.elapsedUpperBound, isNull);
      expect(elapsed.precisionSafeToShow, isTrue);
  }

  if (elapsed.pastRegulationDisplayThreshold) {
    expect(elapsed.continuity, TemporalContinuityStatus.exactContinuity);
    expect(
      elapsed.exactElapsed! >=
          ActivePeriodElapsedProjection.regulationDisplayThreshold,
      isTrue,
    );
  }
}

void _expectThresholdDoesNotEndPeriod(ActivePeriodElapsedProjection elapsed) {
  expect(elapsed.pastRegulationDisplayThreshold, isTrue);
  expect(elapsed.periodEnded, isFalse);
}

final DeterministicMatchProjector _projector = DeterministicMatchProjector(
  ProductionSemanticsResolver(),
);

const ProjectionContext _context =
    ProjectionContext(evaluatedAuthorityGeneration: 1);

typedef _Reading = ({
  MatchProjectionState projection,
  TemporalMatchProjection temporal,
  ActivePeriodElapsedProjection elapsed,
});

_Reading _read({
  DeterministicMatchProjector? projector,
  required List<MatchRecord> records,
  TemporalEvidence? anchor,
  TemporalEvidence? current,
  TemporalEvidence? suspensionBoundary,
  TemporalEvidence? resumptionAnchor,
  List<TemporalEvidence> recordedEvidence = const [],
}) {
  final projection = (projector ?? _projector).projectRecords(
    matchId: 'match-1',
    records: records,
    context: _context,
  );
  final temporal = TemporalMatchProjection.derive(
    projection: projection,
    records: records,
  );
  final elapsed = deriveActivePeriodElapsed(
    temporal: temporal,
    projection: projection,
    records: records,
    anchor: anchor,
    current: current,
    suspensionBoundary: suspensionBoundary,
    resumptionAnchor: resumptionAnchor,
    recordedEvidence: recordedEvidence,
  );
  return (projection: projection, temporal: temporal, elapsed: elapsed);
}

List<MatchRecord> _startedPeriod({
  required String anchorId,
  DateTime? periodRecordedAt,
}) {
  return [
    _record('start', V1SemanticTypeCode.matchStarted, originSequence: 1),
    _record(
      'period',
      V1SemanticTypeCode.periodStarted,
      originSequence: 2,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'start')],
      recordedAt: periodRecordedAt,
      temporalContext: TemporalContext(evidenceIds: [anchorId]),
    ),
  ];
}

MatchRecord _record(
  String recordId,
  V1SemanticTypeCode code, {
  required int originSequence,
  String originDeviceId = 'dev-a',
  PeriodIdentity? period,
  List<RecordRelationship> relationships = const [],
  DateTime? recordedAt,
  TemporalContext? temporalContext,
  AuthorityContext? authorityContext,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: originDeviceId,
    originSequence: originSequence,
    payload: TemporalTransitionPayload(semanticType: code, period: period),
    integrity: const IntegrityMetadata(),
    relationships: relationships,
    temporalContext: temporalContext,
    authorityContext: authorityContext,
  );
}

AuthorityContext _authority(String principalId) {
  return AuthorityContext(
    scope: const MainRefereeScope(),
    principal: AuthorityPrincipal(principalId: principalId),
    generation: const AuthorityGeneration(value: 1),
  );
}

bool _isPeriodEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodEnded;
}

TemporalEvidence _point(
  String evidenceId,
  DateTime capturedAt,
  Duration monotonic, {
  String? domainId = 'domain-1',
  bool certified = false,
}) {
  return TemporalEvidence(
    evidenceId: evidenceId,
    capturedAt: capturedAt,
    continuityDomainId: domainId,
    monotonicElapsed: monotonic,
    certified: certified,
  );
}

TemporalEvidence _certifiedPoint(
  String evidenceId,
  DateTime capturedAt,
  Duration monotonic, {
  String? domainId = 'domain-1',
}) {
  return _point(
    evidenceId,
    capturedAt,
    monotonic,
    domainId: domainId,
    certified: true,
  );
}
