import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_core/projection/temporal_display_admission.dart';
import 'package:test/test.dart';

void main() {
  const minute = Duration(minutes: 1);

  final rows = <_ElapsedRow>[
    _ElapsedRow(
      'exact positive at 12:00',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.trusted,
        exactElapsed: minute * 12,
        precisionSafeToShow: true,
        certified: true,
      ),
      const ExactElapsedAdmission(Duration(minutes: 12)),
    ),
    _ElapsedRow(
      'F10 89:00 stays exact while periodEnded is false',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.trusted,
        exactElapsed: const Duration(minutes: 89),
        precisionSafeToShow: true,
        certified: true,
        pastRegulationDisplayThreshold: true,
      ),
      const ExactElapsedAdmission(Duration(minutes: 89)),
    ),
    _ElapsedRow(
      'supplied Duration.zero with full exact proof stays exact',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.trusted,
        exactElapsed: Duration.zero,
        precisionSafeToShow: true,
        certified: true,
      ),
      const ExactElapsedAdmission(Duration.zero),
    ),
    _ElapsedRow(
      'exact guard: continuity unresolved',
      _elapsed(
        trust: ProjectionTrust.trusted,
        exactElapsed: minute * 12,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'exact guard: bounded continuity does not borrow an exact duration',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.trusted,
        exactElapsed: minute * 12,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'exact guard: null exactElapsed',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.trusted,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'exact guard: incomplete trust',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.incomplete,
        exactElapsed: minute * 12,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'exact guard: conflicted trust',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.conflicted,
        exactElapsed: minute * 12,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'exact guard: untrusted',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.untrusted,
        exactElapsed: minute * 12,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'exact guard: precision not safe',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.trusted,
        exactElapsed: minute * 12,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'exact guard: certified false',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.trusted,
        exactElapsed: minute * 12,
        precisionSafeToShow: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'bounded positive, trusted, certified false',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.trusted,
        lower: minute * 10,
        upper: minute * 12,
        precisionSafeToShow: true,
      ),
      const BoundedElapsedAdmission(
        lower: Duration(minutes: 10),
        upper: Duration(minutes: 12),
      ),
    ),
    _ElapsedRow(
      'bounded positive, incomplete, equal bounds',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.incomplete,
        lower: minute * 8,
        upper: minute * 8,
        precisionSafeToShow: true,
        certified: true,
      ),
      const BoundedElapsedAdmission(
        lower: Duration(minutes: 8),
        upper: Duration(minutes: 8),
      ),
    ),
    _ElapsedRow(
      'bounded guard: missing lower',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.trusted,
        upper: minute * 12,
        precisionSafeToShow: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'bounded guard: missing upper',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.trusted,
        lower: minute * 10,
        precisionSafeToShow: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'bounded guard: inverted bounds',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.trusted,
        lower: minute * 12,
        upper: minute * 10,
        precisionSafeToShow: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'bounded guard: conflicted trust',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.conflicted,
        lower: minute * 10,
        upper: minute * 12,
        precisionSafeToShow: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'bounded guard: untrusted',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.untrusted,
        lower: minute * 10,
        upper: minute * 12,
        precisionSafeToShow: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'bounded guard: precision not safe',
      _elapsed(
        continuity: TemporalContinuityStatus.boundedContinuity,
        trust: ProjectionTrust.incomplete,
        lower: minute * 10,
        upper: minute * 12,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'continuity mismatch: exact continuity with only a range',
      _elapsed(
        continuity: TemporalContinuityStatus.exactContinuity,
        trust: ProjectionTrust.trusted,
        lower: minute * 10,
        upper: minute * 12,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'F1 unavailable recovery carries no digits',
      ActivePeriodElapsedProjection.unavailable,
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'F4 wall-clock jump supplied as unresolved evidence',
      _elapsed(trust: ProjectionTrust.untrusted),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'F5 wall-clock step back does not become Duration.zero',
      _elapsed(
        trust: ProjectionTrust.untrusted,
        exactElapsed: Duration.zero,
      ),
      const UnresolvedElapsedAdmission(),
    ),
    _ElapsedRow(
      'F6 time-zone change supplied as unresolved evidence',
      _elapsed(
        continuity: TemporalContinuityStatus.continuityUnresolved,
        trust: ProjectionTrust.incomplete,
        precisionSafeToShow: true,
        certified: true,
      ),
      const UnresolvedElapsedAdmission(),
    ),
  ];

  for (final row in rows) {
    test(row.name, () {
      final admitted = TemporalDisplayAdmission.admit(row.projection);
      expect(admitted, row.expected);
      if (admitted is UnresolvedElapsedAdmission) {
        expect(admitted, isNot(isA<ExactElapsedAdmission>()));
        expect(admitted, isNot(isA<BoundedElapsedAdmission>()));
      }
      if (row.name.startsWith('F10')) {
        expect(row.projection.periodEnded, isFalse);
        expect(
          row.projection.exactElapsed! >
              ActivePeriodElapsedProjection.regulationDisplayThreshold,
          isTrue,
        );
        expect(row.projection.pastRegulationDisplayThreshold, isTrue);
      }
    });
  }

  test('periodEnded true does not erase a certified exact elapsed', () {
    final projection = _elapsed(
      continuity: TemporalContinuityStatus.exactContinuity,
      trust: ProjectionTrust.trusted,
      exactElapsed: const Duration(minutes: 50),
      precisionSafeToShow: true,
      certified: true,
      pastRegulationDisplayThreshold: true,
      periodEnded: true,
    );
    expect(
      TemporalDisplayAdmission.admit(projection),
      const ExactElapsedAdmission(Duration(minutes: 50)),
    );
    expect(projection.periodEnded, isTrue);
  });

  final home = MatchTeamId('side-a');
  final away = MatchTeamId('side-b');
  final scoreRows = <_ScoreRow>[
    _ScoreRow(
      'F14 ScoreUnavailable stays absent',
      const ScoreUnavailable(),
      null,
      null,
    ),
    _ScoreRow(
      'ScoreConflicted stays absent',
      const ScoreConflicted(),
      null,
      null,
    ),
    _ScoreRow(
      'known home does not invent away as zero',
      KnownScore({home: 1}),
      1,
      null,
    ),
    _ScoreRow(
      'known pair is preserved',
      KnownScore({home: 2, away: 1}),
      2,
      1,
    ),
    _ScoreRow(
      'empty known map is absent for both',
      KnownScore({}),
      null,
      null,
    ),
  ];

  for (final row in scoreRows) {
    test(row.name, () {
      expect(_goalsOrNull(row.score, home), row.home);
      expect(_goalsOrNull(row.score, away), row.away);
    });
  }
}

int? _goalsOrNull(ScoreProjection score, MatchTeamId team) {
  if (score is! KnownScore) {
    return null;
  }
  return score.goalsByTeam[team];
}

ActivePeriodElapsedProjection _elapsed({
  TemporalContinuityStatus continuity =
      TemporalContinuityStatus.continuityUnresolved,
  ProjectionTrust trust = ProjectionTrust.untrusted,
  Duration? exactElapsed,
  Duration? lower,
  Duration? upper,
  bool precisionSafeToShow = false,
  bool certified = false,
  bool pastRegulationDisplayThreshold = false,
  bool periodEnded = false,
}) {
  return ActivePeriodElapsedProjection(
    activePeriod: const PeriodIdentity(index: 1),
    continuity: continuity,
    temporalTrust: trust,
    exactElapsed: exactElapsed,
    elapsedLowerBound: lower,
    elapsedUpperBound: upper,
    precisionSafeToShow: precisionSafeToShow,
    certified: certified,
    pastRegulationDisplayThreshold: pastRegulationDisplayThreshold,
    formalSuspensionActive: false,
    suspensionStarted: false,
    suspensionDurationOpen: false,
    suspensionEnded: false,
    suspensionDuration: null,
    suspensionDurationLowerBound: null,
    suspensionDurationUpperBound: null,
    suspensionDurations: const <Duration?>[],
    playingSegments: const <Duration?>[],
    periodEnded: periodEnded,
  );
}

final class _ElapsedRow {
  const _ElapsedRow(this.name, this.projection, this.expected);

  final String name;
  final ActivePeriodElapsedProjection projection;
  final TemporalDisplayAdmission expected;
}

final class _ScoreRow {
  const _ScoreRow(this.name, this.score, this.home, this.away);

  final String name;
  final ScoreProjection score;
  final int? home;
  final int? away;
}
