import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());
  final anchorAt = DateTime.utc(2026, 10, 3, 12);
  final laterWall = DateTime.utc(2026, 10, 3, 18);

  test('elapsed is anchor monotonic plus current monotonic evidence', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );

    final elapsed = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, const Duration(seconds: 4)),
      current: _point(
        'phone-live-monotonic',
        laterWall,
        const Duration(seconds: 19),
      ),
    );

    expect(elapsed.exactElapsed, const Duration(seconds: 15));
    expect(elapsed.continuity, TemporalContinuityStatus.exactContinuity);
    expect(elapsed.precisionSafeToShow, isTrue);
    expect(elapsed.certified, isFalse);
    expect(elapsed.activePeriod, const PeriodIdentity(index: 1));
    expect(elapsed.pastRegulationDisplayThreshold, isFalse);
  });

  test('identical authority and evidence are deterministic', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final anchor = _point('anchor-1', anchorAt, const Duration(seconds: 1));
    final current = _point(
      'live',
      laterWall,
      const Duration(seconds: 8),
    );

    final first = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: anchor,
      current: current,
    );
    final second = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: anchor,
      current: current,
    );

    expect(second, first);
  });

  test('recordedAt alone cannot establish elapsed', () {
    final records = _startedPeriod(
      anchorId: 'anchor-1',
      periodRecordedAt: DateTime.utc(2026, 12, 31),
    );
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );

    final withoutEvidence = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: null,
      current: _point('live', laterWall, const Duration(hours: 3)),
    );
    final withEvidence = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero),
      current: _point('live', anchorAt, const Duration(seconds: 8)),
    );

    expect(withoutEvidence.exactElapsed, isNull);
    expect(
      withoutEvidence.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
    expect(withEvidence.exactElapsed, const Duration(seconds: 8));
    expect(records.last.recordedAt, DateTime.utc(2026, 12, 31));
  });

  test('wall-clock jump does not rewrite elapsed', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point('anchor-1', laterWall, const Duration(seconds: 10)),
      current: _point(
        'live',
        anchorAt,
        const Duration(seconds: 16),
      ),
    );

    expect(elapsed.exactElapsed, const Duration(seconds: 6));
  });

  test('a different continuity domain does not fabricate exact elapsed', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point(
        'anchor-1',
        anchorAt,
        const Duration(seconds: 5),
        domainId: 'domain-a',
      ),
      current: _point(
        'live',
        anchorAt.add(const Duration(minutes: 20)),
        const Duration(seconds: 5),
        domainId: 'domain-b',
      ),
    );

    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.elapsedLowerBound, isNull);
    expect(
      elapsed.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
    expect(elapsed.precisionSafeToShow, isFalse);
    expect(elapsed.activePeriod, const PeriodIdentity(index: 1));
  });

  test('an interval reading is bounded and not an exact second', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, const Duration(seconds: 2)),
      current: TemporalEvidence(
        evidenceId: 'live',
        capturedAt: laterWall,
        continuityDomainId: 'domain-1',
        monotonicElapsed: const Duration(seconds: 12),
        monotonicUpperBound: const Duration(seconds: 15),
      ),
    );

    expect(elapsed.continuity, TemporalContinuityStatus.boundedContinuity);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.elapsedLowerBound, const Duration(seconds: 10));
    expect(elapsed.elapsedUpperBound, const Duration(seconds: 13));
    expect(elapsed.precisionSafeToShow, isFalse);
    expect(elapsed.certified, isFalse);
  });

  test('ordinary play continues without a formal suspension record', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    expect(
      records.any(
        (record) =>
            record.payload is TemporalTransitionPayload &&
            (record.payload as TemporalTransitionPayload).semanticType ==
                V1SemanticTypeCode.temporarySuspensionStarted,
      ),
      isFalse,
    );
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero),
      current: _point('live', laterWall, const Duration(seconds: 30)),
    );

    expect(elapsed.exactElapsed, const Duration(seconds: 30));
    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.suspensionStarted, isFalse);
    expect(elapsed.suspensionDurationOpen, isFalse);
  });

  test('45:00 is display information and does not end the period', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero),
      current: _point(
        'live',
        laterWall,
        const Duration(minutes: 45, seconds: 1),
      ),
    );

    expect(elapsed.pastRegulationDisplayThreshold, isTrue);
    expect(elapsed.exactElapsed, const Duration(minutes: 45, seconds: 1));
    expect(
      records.where((record) {
        final payload = record.payload;
        return payload is TemporalTransitionPayload &&
            payload.semanticType == V1SemanticTypeCode.periodEnded;
      }),
      isEmpty,
    );
    expect(records, hasLength(2));
  });

  test('certified flags do not certify the phone projection', () {
    final records = _startedPeriod(anchorId: 'anchor-1');
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: TemporalEvidence(
        evidenceId: 'anchor-1',
        capturedAt: anchorAt,
        continuityDomainId: 'domain-1',
        monotonicElapsed: Duration.zero,
        certified: true,
      ),
      current: TemporalEvidence(
        evidenceId: 'live',
        capturedAt: laterWall,
        continuityDomainId: 'domain-1',
        monotonicElapsed: const Duration(seconds: 3),
        certified: true,
      ),
    );

    expect(elapsed.certified, isFalse);
    expect(elapsed.exactElapsed, const Duration(seconds: 3));
  });

  test('formal suspension freezes playing elapsed at the boundary', () {
    final records = _suspended(anchorId: 'anchor-1', boundaryId: 'boundary-1');
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final elapsed = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point('anchor-1', laterWall, const Duration(seconds: 4)),
      current: _point('live', anchorAt, const Duration(minutes: 20)),
      suspensionBoundary: _point(
        'boundary-1',
        DateTime.utc(1999, 1, 1),
        const Duration(seconds: 19),
      ),
    );
    final again = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point('anchor-1', laterWall, const Duration(seconds: 4)),
      current: _point('live', DateTime.utc(2099), const Duration(hours: 3)),
      suspensionBoundary: _point(
        'boundary-1',
        DateTime.utc(1999, 1, 1),
        const Duration(seconds: 19),
      ),
    );

    expect(temporal.formallySuspended, isTrue);
    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
    expect(elapsed.exactElapsed, const Duration(seconds: 15));
    expect(again, elapsed);
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.suspensionStarted, isTrue);
    expect(elapsed.suspensionDurationOpen, isTrue);
    expect(elapsed.precisionSafeToShow, isTrue);
    expect(elapsed.certified, isFalse);
    expect(records, hasLength(3));
    expect(records.where(_isPeriodEnded), isEmpty);
  });

  test('a bounded suspension boundary stays bounded after later play', () {
    final records = _suspended(anchorId: 'anchor-1', boundaryId: 'boundary-1');
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, const Duration(seconds: 2)),
      current: _point('live', laterWall, const Duration(minutes: 10)),
      suspensionBoundary: TemporalEvidence(
        evidenceId: 'boundary-1',
        capturedAt: laterWall,
        continuityDomainId: 'domain-1',
        monotonicElapsed: const Duration(seconds: 12),
        monotonicUpperBound: const Duration(seconds: 15),
      ),
    );

    expect(elapsed.continuity, TemporalContinuityStatus.boundedContinuity);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.elapsedLowerBound, const Duration(seconds: 10));
    expect(elapsed.elapsedUpperBound, const Duration(seconds: 13));
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.suspensionDurationOpen, isTrue);
    expect(elapsed.precisionSafeToShow, isFalse);
  });

  test('unresolved suspension boundary does not invent exact elapsed', () {
    final records = _suspended(anchorId: 'anchor-1', boundaryId: 'boundary-1');
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final elapsed = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point(
        'anchor-1',
        anchorAt,
        const Duration(seconds: 5),
        domainId: 'domain-a',
      ),
      current: _point(
        'live',
        laterWall,
        const Duration(minutes: 30),
        domainId: 'domain-a',
      ),
      suspensionBoundary: _point(
        'boundary-1',
        laterWall,
        const Duration(seconds: 40),
        domainId: 'domain-b',
      ),
    );

    expect(temporal.formallySuspended, isTrue);
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.suspensionStarted, isTrue);
    expect(elapsed.suspensionDurationOpen, isTrue);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.elapsedLowerBound, isNull);
    expect(
      elapsed.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
    expect(elapsed.precisionSafeToShow, isFalse);
  });

  test('45:00 during suspension does not end the period or add time', () {
    final records = _suspended(anchorId: 'anchor-1', boundaryId: 'boundary-1');
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero),
      current: _point('live', laterWall, const Duration(hours: 2)),
      suspensionBoundary: _point(
        'boundary-1',
        anchorAt,
        const Duration(minutes: 45, seconds: 1),
      ),
    );

    expect(elapsed.exactElapsed, const Duration(minutes: 45, seconds: 1));
    expect(elapsed.pastRegulationDisplayThreshold, isTrue);
    expect(elapsed.suspensionDurationOpen, isTrue);
    expect(records.where(_isPeriodEnded), isEmpty);
    expect(records, hasLength(3));
    final source = File(
      'lib/projection/active_period_elapsed.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('addedTime')));
    expect(source, isNot(contains('V1SemanticTypeCode.periodEnded')));
  });

  test('resumption continues the frozen playing elapsed once', () {
    final records = _resumed(
      anchorId: 'anchor-1',
      boundaryId: 'boundary-1',
      resumptionId: 'resume-1',
    );
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final atResume = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero),
      current: _point('live', laterWall, const Duration(seconds: 40)),
      suspensionBoundary: _point('boundary-1', anchorAt, const Duration(seconds: 10)),
      resumptionAnchor: _point(
        'resume-1',
        DateTime.utc(2099),
        const Duration(seconds: 40),
      ),
    );
    final later = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero),
      current: _point('live', DateTime.utc(1990), const Duration(seconds: 47)),
      suspensionBoundary: _point('boundary-1', laterWall, const Duration(seconds: 10)),
      resumptionAnchor: _point(
        'resume-1',
        DateTime.utc(2099),
        const Duration(seconds: 40),
      ),
    );

    expect(temporal.formallySuspended, isFalse);
    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
    expect(atResume.exactElapsed, const Duration(seconds: 10));
    expect(atResume.formalSuspensionActive, isFalse);
    expect(atResume.suspensionStarted, isTrue);
    expect(atResume.suspensionEnded, isTrue);
    expect(atResume.suspensionDurationOpen, isFalse);
    expect(atResume.suspensionDuration, const Duration(seconds: 30));
    expect(later.exactElapsed, const Duration(seconds: 17));
    expect(later.suspensionDuration, const Duration(seconds: 30));
    expect(
      later.exactElapsed! + later.suspensionDuration!,
      const Duration(seconds: 47),
    );
    expect(later.exactElapsed, isNot(const Duration(seconds: 47)));
    expect(later, isNot(atResume));
    expect(records.where(_isPeriodEnded), isEmpty);
    expect(
      V1SemanticContract
          .byCode[V1SemanticTypeCode.temporarySuspensionEnded]!
          .isDurableMatchState,
      isFalse,
    );
    expect(V1SemanticTypeCodeWire.parseWire('RESUMED'), isNull);
  });

  test('a new continuity domain after resumption does not invent elapsed', () {
    final records = _resumed(
      anchorId: 'anchor-1',
      boundaryId: 'boundary-1',
      resumptionId: 'resume-1',
    );
    final projection = _project(projector, records);
    final elapsed = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection.derive(
        projection: projection,
        records: records,
      ),
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero, domainId: 'domain-a'),
      current: _point(
        'live',
        laterWall,
        const Duration(hours: 3),
        domainId: 'domain-b',
      ),
      suspensionBoundary: _point(
        'boundary-1',
        anchorAt,
        const Duration(seconds: 10),
        domainId: 'domain-a',
      ),
      resumptionAnchor: _point(
        'resume-1',
        laterWall,
        const Duration(seconds: 40),
        domainId: 'domain-a',
      ),
    );

    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.suspensionEnded, isTrue);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.precisionSafeToShow, isFalse);
    expect(elapsed.suspensionDuration, const Duration(seconds: 30));
    expect(
      elapsed.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
  });

  test('an end that misses the suspension lineage stays open', () {
    final records = [
      ..._suspended(anchorId: 'anchor-1', boundaryId: 'boundary-1'),
      _record(
        'resume',
        V1SemanticTypeCode.temporarySuspensionEnded,
        originSequence: 4,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'period')],
        temporalContext: const TemporalContext(evidenceIds: ['resume-1']),
      ),
    ];
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final elapsed = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: _point('anchor-1', anchorAt, Duration.zero),
      current: _point('live', laterWall, const Duration(seconds: 90)),
      suspensionBoundary: _point('boundary-1', anchorAt, const Duration(seconds: 10)),
      resumptionAnchor: _point('resume-1', laterWall, const Duration(seconds: 40)),
    );

    expect(temporal.formallySuspended, isTrue);
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.suspensionEnded, isFalse);
    expect(elapsed.exactElapsed, const Duration(seconds: 10));
  });

  test('two suspension cycles sum playing segments and keep both intervals', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _suspensionStart('susp-2', 'boundary-2', 5),
      _suspensionEnd('end-2', 'susp-2', 'resume-2', 6),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', laterWall, const Duration(seconds: 10)),
        _point('resume-1', DateTime.utc(2099), const Duration(seconds: 40)),
        _point('boundary-2', DateTime.utc(1990), const Duration(seconds: 47)),
        _point('resume-2', DateTime.utc(1980), const Duration(seconds: 67)),
      ],
      currentMonotonic: const Duration(seconds: 72),
    );
    final temporal = TemporalMatchProjection.derive(
      projection: _project(projector, records),
      records: records,
    );

    expect(elapsed.exactElapsed, const Duration(seconds: 22));
    expect(elapsed.playingSegments, [
      const Duration(seconds: 10),
      const Duration(seconds: 7),
      const Duration(seconds: 5),
    ]);
    expect(elapsed.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 72)));
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 42)));
    expect(elapsed.suspensionDuration, isNull);
    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.suspensionEnded, isTrue);
    expect(temporal.formallySuspended, isFalse);
    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
    expect(records.where(_isPeriodEnded), isEmpty);
  });

  test('three suspension cycles use the same segment walk', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _suspensionStart('susp-2', 'boundary-2', 5),
      _suspensionEnd('end-2', 'susp-2', 'resume-2', 6),
      _suspensionStart('susp-3', 'boundary-3', 7),
      _suspensionEnd('end-3', 'susp-3', 'resume-3', 8),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', anchorAt, const Duration(seconds: 10)),
        _point('resume-1', anchorAt, const Duration(seconds: 40)),
        _point('boundary-2', anchorAt, const Duration(seconds: 47)),
        _point('resume-2', anchorAt, const Duration(seconds: 67)),
        _point('boundary-3', anchorAt, const Duration(seconds: 72)),
        _point('resume-3', anchorAt, const Duration(seconds: 82)),
      ],
      currentMonotonic: const Duration(seconds: 86),
    );

    expect(elapsed.exactElapsed, const Duration(seconds: 26));
    expect(elapsed.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
      const Duration(seconds: 10),
    ]);
    expect(elapsed.playingSegments, [
      const Duration(seconds: 10),
      const Duration(seconds: 7),
      const Duration(seconds: 5),
      const Duration(seconds: 4),
    ]);
    expect(findSuspensionHistory(
      records: records,
      activePeriod: const PeriodIdentity(index: 1),
    ).cycles, hasLength(3));
  });

  test('an open final suspension freezes the summed playing segments', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _suspensionStart('susp-2', 'boundary-2', 5),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', laterWall, const Duration(seconds: 10)),
        _point('resume-1', DateTime.utc(2099), const Duration(seconds: 40)),
        _point('boundary-2', DateTime.utc(1990), const Duration(seconds: 47)),
      ],
      currentMonotonic: const Duration(hours: 2),
    );

    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.exactElapsed, const Duration(seconds: 17));
    expect(elapsed.suspensionDurations, [const Duration(seconds: 30)]);
    expect(elapsed.exactElapsed, isNot(const Duration(hours: 2)));
  });

  test('overlapping suspension starts do not invent playing elapsed', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionStart('susp-2', 'boundary-2', 4),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', anchorAt, const Duration(seconds: 10)),
        _point('boundary-2', anchorAt, const Duration(seconds: 40)),
      ],
      currentMonotonic: const Duration(seconds: 72),
    );
    final history = findSuspensionHistory(
      records: records,
      activePeriod: const PeriodIdentity(index: 1),
    );

    expect(history.overlapping, isTrue);
    expect(elapsed.formalSuspensionActive, isTrue);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 72)));
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 42)));
  });

  test('a second end of one suspension does not invent playing elapsed', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _suspensionEnd('end-2', 'susp-1', 'resume-2', 5),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', anchorAt, const Duration(seconds: 10)),
        _point('resume-1', anchorAt, const Duration(seconds: 40)),
        _point('resume-2', anchorAt, const Duration(seconds: 67)),
      ],
      currentMonotonic: const Duration(seconds: 72),
    );

    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.suspensionDurations, isEmpty);
  });

  test('one uncertain suspension interval leaves the other exact', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _suspensionStart('susp-2', 'boundary-2', 5),
      _suspensionEnd('end-2', 'susp-2', 'resume-2', 6),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', anchorAt, const Duration(seconds: 10)),
        _point('resume-1', anchorAt, const Duration(seconds: 40)),
        _point('boundary-2', anchorAt, const Duration(seconds: 47)),
        _point(
          'resume-2',
          laterWall,
          const Duration(seconds: 67),
          domainId: 'domain-b',
        ),
      ],
      currentMonotonic: const Duration(seconds: 72),
      currentDomain: 'domain-b',
    );

    expect(elapsed.exactElapsed, const Duration(seconds: 22));
    expect(elapsed.playingSegments, [
      const Duration(seconds: 10),
      const Duration(seconds: 7),
      const Duration(seconds: 5),
    ]);
    expect(elapsed.suspensionDurations, [
      const Duration(seconds: 30),
      null,
    ]);
  });

  test('one uncertain playing segment does not erase a known suspension', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _suspensionStart('susp-2', 'boundary-2', 5),
      _suspensionEnd('end-2', 'susp-2', 'resume-2', 6),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', anchorAt, const Duration(seconds: 10)),
        _point('resume-1', anchorAt, const Duration(seconds: 40)),
        _point(
          'boundary-2',
          anchorAt,
          const Duration(seconds: 47),
          domainId: 'domain-b',
        ),
        _point(
          'resume-2',
          laterWall,
          const Duration(seconds: 67),
          domainId: 'domain-b',
        ),
      ],
      currentMonotonic: const Duration(seconds: 72),
      currentDomain: 'domain-b',
    );

    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.playingSegments[0], const Duration(seconds: 10));
    expect(elapsed.playingSegments[1], isNull);
    expect(elapsed.playingSegments[2], const Duration(seconds: 5));
    expect(elapsed.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 72)));
  });

  test('period end freezes playing elapsed after two suspension cycles', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _suspensionStart('susp-2', 'boundary-2', 5),
      _suspensionEnd('end-2', 'susp-2', 'resume-2', 6),
      _periodEnd('period-end', 'end-boundary', 7),
    ];
    final evidence = [
      _point('anchor', anchorAt, Duration.zero),
      _point('boundary-1', laterWall, const Duration(seconds: 10)),
      _point('resume-1', DateTime.utc(2099), const Duration(seconds: 40)),
      _point('boundary-2', DateTime.utc(1990), const Duration(seconds: 47)),
      _point('resume-2', DateTime.utc(1980), const Duration(seconds: 67)),
      _point('end-boundary', DateTime.utc(1970), const Duration(seconds: 75)),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: evidence,
      currentMonotonic: const Duration(seconds: 75),
    );
    final later = _deriveAt(
      projector: projector,
      records: records,
      evidence: evidence,
      currentMonotonic: const Duration(hours: 2),
    );
    final temporal = TemporalMatchProjection.derive(
      projection: _project(projector, records),
      records: records,
    );

    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.formallySuspended, isFalse);
    expect(temporal.periodEndAmbiguous, isFalse);
    expect(elapsed.periodEnded, isTrue);
    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.exactElapsed, const Duration(seconds: 25));
    expect(elapsed.playingSegments, [
      const Duration(seconds: 10),
      const Duration(seconds: 7),
      const Duration(seconds: 8),
    ]);
    expect(elapsed.suspensionDurations, [
      const Duration(seconds: 30),
      const Duration(seconds: 20),
    ]);
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 75)));
    expect(later.exactElapsed, const Duration(seconds: 25));
    expect(later, elapsed);
    expect(records.where(_isPeriodEnded), hasLength(1));
  });

  test('45:00 does not end the period and an explicit end can be another value', () {
    final running = _startedPeriod(anchorId: 'anchor');
    final atThreshold = _deriveAt(
      projector: projector,
      records: running,
      evidence: [_point('anchor', anchorAt, Duration.zero)],
      currentMonotonic: const Duration(minutes: 45, seconds: 1),
    );
    final runningTemporal = TemporalMatchProjection.derive(
      projection: _project(projector, running),
      records: running,
    );
    expect(atThreshold.pastRegulationDisplayThreshold, isTrue);
    expect(atThreshold.periodEnded, isFalse);
    expect(runningTemporal.activePeriod, const PeriodIdentity(index: 1));
    expect(running.where(_isPeriodEnded), isEmpty);

    final earlyRecords = [
      ...running,
      _periodEnd('period-end', 'end-boundary', 3),
    ];
    final early = _deriveAt(
      projector: projector,
      records: earlyRecords,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('end-boundary', laterWall, const Duration(seconds: 12)),
      ],
      currentMonotonic: const Duration(minutes: 45),
    );
    final earlyTemporal = TemporalMatchProjection.derive(
      projection: _project(projector, earlyRecords),
      records: earlyRecords,
    );
    expect(early.exactElapsed, const Duration(seconds: 12));
    expect(early.pastRegulationDisplayThreshold, isFalse);
    expect(early.periodEnded, isTrue);
    expect(earlyTemporal.activePeriod, isNull);
    expect(earlyTemporal.endedPeriod, const PeriodIdentity(index: 1));

    final lateRecords = [
      ..._startedPeriod(anchorId: 'anchor-late'),
      _record(
        'period-end-late',
        V1SemanticTypeCode.periodEnded,
        originSequence: 3,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'period')],
        temporalContext: const TemporalContext(evidenceIds: ['end-late']),
      ),
    ];
    final late = _deriveAt(
      projector: projector,
      records: lateRecords,
      evidence: [
        _point('anchor-late', anchorAt, Duration.zero),
        _point('end-late', laterWall, const Duration(minutes: 46)),
      ],
      currentMonotonic: const Duration(hours: 3),
    );
    expect(late.exactElapsed, const Duration(minutes: 46));
    expect(late.pastRegulationDisplayThreshold, isTrue);
    expect(late.periodEnded, isTrue);
    expect(late.exactElapsed, isNot(const Duration(hours: 3)));
  });

  test('unresolved end boundary keeps PERIOD_ENDED without an exact total', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _periodEnd('period-end', 'end-boundary', 3),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point(
          'end-boundary',
          laterWall,
          const Duration(seconds: 20),
          domainId: 'domain-b',
        ),
      ],
      currentMonotonic: const Duration(hours: 2),
    );
    final temporal = TemporalMatchProjection.derive(
      projection: _project(projector, records),
      records: records,
    );

    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.activePeriod, isNull);
    expect(elapsed.periodEnded, isTrue);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.precisionSafeToShow, isFalse);
    expect(
      elapsed.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
  });

  test('period 2 elapsed uses its own anchor and ignores period 1', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _suspensionStart('susp-1', 'boundary-1', 3),
      _suspensionEnd('end-1', 'susp-1', 'resume-1', 4),
      _periodEnd('period-end', 'end-boundary', 5),
      _record(
        'period-2',
        V1SemanticTypeCode.periodStarted,
        originSequence: 6,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'period-end')],
        temporalContext: const TemporalContext(evidenceIds: ['anchor-2']),
      ),
    ];
    final evidence = [
      _point('anchor', anchorAt, Duration.zero),
      _point('boundary-1', anchorAt, const Duration(seconds: 10)),
      _point('resume-1', laterWall, const Duration(seconds: 40)),
      _point('end-boundary', DateTime.utc(2099), const Duration(seconds: 47)),
      _point('anchor-2', DateTime.utc(1990), const Duration(seconds: 100)),
    ];
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final periodTwo = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: evidence.last,
      current: _point('live', DateTime.utc(1980), const Duration(seconds: 112)),
      recordedEvidence: evidence,
    );
    final periodOne = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection(
        matchStarted: true,
        activePeriod: null,
        endedPeriod: const PeriodIdentity(index: 1),
        periodEndAmbiguous: false,
        intervalActive: true,
        temporallyIncomplete: false,
        formallySuspended: false,
      ),
      projection: projection,
      records: records,
      anchor: evidence.first,
      current: _point('live', DateTime.utc(1980), const Duration(seconds: 112)),
      recordedEvidence: evidence,
    );

    expect(temporal.activePeriod, const PeriodIdentity(index: 2));
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.intervalActive, isFalse);
    expect(periodTwo.exactElapsed, const Duration(seconds: 12));
    expect(periodTwo.activePeriod, const PeriodIdentity(index: 2));
    expect(periodTwo.suspensionDurations, isEmpty);
    expect(periodOne.exactElapsed, const Duration(seconds: 17));
    expect(periodOne.suspensionDurations, [const Duration(seconds: 30)]);
    expect(periodTwo.exactElapsed, isNot(const Duration(seconds: 17)));
    expect(periodTwo.exactElapsed, isNot(const Duration(seconds: 47)));
  });

  test('interval keeps final elapsed without an active period identity', () {
    final records = [
      ..._startedPeriod(anchorId: 'anchor'),
      _periodEnd('period-end', 'end-boundary', 3),
    ];
    final evidence = [
      _point('anchor', anchorAt, Duration.zero),
      _point('end-boundary', laterWall, const Duration(seconds: 25)),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: evidence,
      currentMonotonic: const Duration(hours: 2),
    );
    final later = _deriveAt(
      projector: projector,
      records: records,
      evidence: evidence,
      currentMonotonic: const Duration(hours: 3),
    );
    final temporal = TemporalMatchProjection.derive(
      projection: _project(projector, records),
      records: records,
    );

    expect(temporal.intervalActive, isTrue);
    expect(elapsed.activePeriod, isNull);
    expect(elapsed.periodEnded, isTrue);
    expect(elapsed.exactElapsed, const Duration(seconds: 25));
    expect(later.exactElapsed, const Duration(seconds: 25));
    expect(later, elapsed);
  });

  test('an end during an open suspension does not invent final playing elapsed', () {
    final records = [
      ..._suspended(anchorId: 'anchor', boundaryId: 'boundary-1'),
      _periodEnd('period-end', 'end-boundary', 4),
    ];
    final elapsed = _deriveAt(
      projector: projector,
      records: records,
      evidence: [
        _point('anchor', anchorAt, Duration.zero),
        _point('boundary-1', anchorAt, const Duration(seconds: 10)),
        _point('end-boundary', laterWall, const Duration(seconds: 40)),
      ],
      currentMonotonic: const Duration(seconds: 90),
    );

    expect(elapsed.periodEnded, isTrue);
    expect(elapsed.formalSuspensionActive, isFalse);
    expect(elapsed.exactElapsed, isNull);
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 40)));
    expect(elapsed.exactElapsed, isNot(const Duration(seconds: 90)));
  });

  test('period 2 end freezes 26s and leaves period 1 at 17s', () {
    final records = [
      _record('start', V1SemanticTypeCode.matchStarted, originSequence: 1),
      _record(
        'period',
        V1SemanticTypeCode.periodStarted,
        originSequence: 2,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'start')],
        temporalContext: const TemporalContext(evidenceIds: ['p1']),
      ),
      _record(
        'p1-susp',
        V1SemanticTypeCode.temporarySuspensionStarted,
        originSequence: 3,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'period')],
        temporalContext: const TemporalContext(evidenceIds: ['p1-susp']),
      ),
      _record(
        'p1-resume',
        V1SemanticTypeCode.temporarySuspensionEnded,
        originSequence: 4,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'p1-susp')],
        temporalContext: const TemporalContext(evidenceIds: ['p1-resume']),
      ),
      _record(
        'p1-end',
        V1SemanticTypeCode.periodEnded,
        originSequence: 5,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'period')],
        temporalContext: const TemporalContext(evidenceIds: ['p1-end']),
      ),
      _record(
        'period-2',
        V1SemanticTypeCode.periodStarted,
        originSequence: 6,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'p1-end')],
        temporalContext: const TemporalContext(evidenceIds: ['p2']),
      ),
      _record(
        'p2-susp-1',
        V1SemanticTypeCode.temporarySuspensionStarted,
        originSequence: 7,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'period-2')],
        temporalContext: const TemporalContext(evidenceIds: ['p2-susp-1']),
      ),
      _record(
        'p2-resume-1',
        V1SemanticTypeCode.temporarySuspensionEnded,
        originSequence: 8,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'p2-susp-1')],
        temporalContext: const TemporalContext(evidenceIds: ['p2-resume-1']),
      ),
      _record(
        'p2-susp-2',
        V1SemanticTypeCode.temporarySuspensionStarted,
        originSequence: 9,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'period-2')],
        temporalContext: const TemporalContext(evidenceIds: ['p2-susp-2']),
      ),
      _record(
        'p2-resume-2',
        V1SemanticTypeCode.temporarySuspensionEnded,
        originSequence: 10,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'p2-susp-2')],
        temporalContext: const TemporalContext(evidenceIds: ['p2-resume-2']),
      ),
      _record(
        'p2-end',
        V1SemanticTypeCode.periodEnded,
        originSequence: 11,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'period-2')],
        temporalContext: const TemporalContext(evidenceIds: ['p2-end']),
      ),
    ];
    final evidence = [
      _point('p1', anchorAt, Duration.zero),
      _point('p1-susp', anchorAt, const Duration(seconds: 10)),
      _point('p1-resume', laterWall, const Duration(seconds: 40)),
      _point('p1-end', laterWall, const Duration(seconds: 47)),
      _point('p2', laterWall, const Duration(seconds: 100)),
      _point('p2-susp-1', laterWall, const Duration(seconds: 112)),
      _point('p2-resume-1', laterWall, const Duration(seconds: 132)),
      _point('p2-susp-2', laterWall, const Duration(seconds: 140)),
      _point('p2-resume-2', laterWall, const Duration(seconds: 150)),
      _point('p2-end', DateTime.utc(2099), const Duration(seconds: 156)),
    ];
    final projection = _project(projector, records);
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final periodTwo = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: evidence[4],
      current: _point('live', DateTime.utc(2099), const Duration(seconds: 400)),
      recordedEvidence: evidence,
    );
    final periodOne = deriveActivePeriodElapsed(
      temporal: TemporalMatchProjection(
        matchStarted: true,
        activePeriod: null,
        endedPeriod: const PeriodIdentity(index: 1),
        periodEndAmbiguous: false,
        intervalActive: true,
        temporallyIncomplete: false,
        formallySuspended: false,
      ),
      projection: projection,
      records: records,
      anchor: evidence.first,
      current: _point('live', DateTime.utc(2099), const Duration(seconds: 400)),
      recordedEvidence: evidence,
    );

    expect(temporal.bothOrdinaryPeriodsEnded, isTrue);
    expect(temporal.intervalActive, isFalse);
    expect(temporal.activePeriod, isNull);
    expect(periodTwo.activePeriod, isNull);
    expect(periodTwo.periodEnded, isTrue);
    expect(periodTwo.exactElapsed, const Duration(seconds: 26));
    expect(periodTwo.suspensionDurations, [
      const Duration(seconds: 20),
      const Duration(seconds: 10),
    ]);
    expect(periodTwo.playingSegments, [
      const Duration(seconds: 12),
      const Duration(seconds: 8),
      const Duration(seconds: 6),
    ]);
    expect(periodOne.exactElapsed, const Duration(seconds: 17));
    expect(periodOne.suspensionDurations, [const Duration(seconds: 30)]);
    expect(periodTwo.exactElapsed, isNot(const Duration(seconds: 17)));
    expect(periodTwo.exactElapsed, isNot(const Duration(seconds: 400)));
  });
}

MatchProjectionState _project(
  DeterministicMatchProjector projector,
  List<MatchRecord> records,
) {
  return projector.projectRecords(
    matchId: 'match-1',
    records: records,
    context: context,
  );
}

const context = ProjectionContext(evaluatedAuthorityGeneration: 1);

List<MatchRecord> _startedPeriod({
  required String anchorId,
  DateTime? periodRecordedAt,
}) {
  return [
    _record(
      'start',
      V1SemanticTypeCode.matchStarted,
      originSequence: 1,
    ),
    _record(
      'period',
      V1SemanticTypeCode.periodStarted,
      originSequence: 2,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'start')],
      recordedAt: periodRecordedAt,
      temporalContext: TemporalContext(
        evidenceIds: [anchorId],
        domainClockPolicyVersion: 'domain-clock-v1',
      ),
    ),
  ];
}

List<MatchRecord> _suspended({
  required String anchorId,
  required String boundaryId,
}) {
  return [
    ..._startedPeriod(anchorId: anchorId),
    _record(
      'susp',
      V1SemanticTypeCode.temporarySuspensionStarted,
      originSequence: 3,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'period')],
      recordedAt: DateTime.utc(2030, 1, 1),
      temporalContext: TemporalContext(evidenceIds: [boundaryId]),
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
    _record(
      'resume',
      V1SemanticTypeCode.temporarySuspensionEnded,
      originSequence: 4,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'susp')],
      temporalContext: TemporalContext(evidenceIds: [resumptionId]),
    ),
  ];
}

bool _isPeriodEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.periodEnded;
}

MatchRecord _record(
  String recordId,
  V1SemanticTypeCode code, {
  required int originSequence,
  PeriodIdentity? period,
  List<RecordRelationship> relationships = const [],
  DateTime? recordedAt,
  TemporalContext? temporalContext,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: TemporalTransitionPayload(semanticType: code, period: period),
    integrity: const IntegrityMetadata(),
    relationships: relationships,
    temporalContext: temporalContext,
  );
}

ActivePeriodElapsedProjection _deriveAt({
  required DeterministicMatchProjector projector,
  required List<MatchRecord> records,
  required List<TemporalEvidence> evidence,
  required Duration currentMonotonic,
  String currentDomain = 'domain-1',
}) {
  final projection = _project(projector, records);
  return deriveActivePeriodElapsed(
    temporal: TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    ),
    projection: projection,
    records: records,
    anchor: evidence.first,
    current: _point(
      'live',
      DateTime.utc(2099),
      currentMonotonic,
      domainId: currentDomain,
    ),
    recordedEvidence: evidence,
  );
}

MatchRecord _periodEnd(String id, String evidenceId, int sequence) {
  return _record(
    id,
    V1SemanticTypeCode.periodEnded,
    originSequence: sequence,
    period: const PeriodIdentity(index: 1),
    relationships: [CausalDependency(targetRecordId: 'period')],
    temporalContext: TemporalContext(evidenceIds: [evidenceId]),
  );
}

MatchRecord _suspensionStart(String id, String evidenceId, int sequence) {
  return _record(
    id,
    V1SemanticTypeCode.temporarySuspensionStarted,
    originSequence: sequence,
    period: const PeriodIdentity(index: 1),
    relationships: [CausalDependency(targetRecordId: 'period')],
    temporalContext: TemporalContext(evidenceIds: [evidenceId]),
  );
}

MatchRecord _suspensionEnd(
  String id,
  String targetId,
  String evidenceId,
  int sequence,
) {
  return _record(
    id,
    V1SemanticTypeCode.temporarySuspensionEnded,
    originSequence: sequence,
    period: const PeriodIdentity(index: 1),
    relationships: [CausalDependency(targetRecordId: targetId)],
    temporalContext: TemporalContext(evidenceIds: [evidenceId]),
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
