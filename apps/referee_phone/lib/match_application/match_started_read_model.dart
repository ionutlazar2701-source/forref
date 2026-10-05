import 'package:forref_match_core/forref_match_core.dart';

/// Thin UI adapter over the production temporal projection.
///
/// Started and period-running truth come from committed records. They are not
/// legacy `Match.status` or `currentState`.
final class MatchStartedReadModel {
  const MatchStartedReadModel._({
    required this.authoritativelyStarted,
    required this.activePeriod,
    required this.temporallyIncomplete,
  });

  final bool authoritativelyStarted;
  final PeriodIdentity? activePeriod;
  final bool temporallyIncomplete;

  static MatchStartedReadModel from({
    required MatchProjectionState projection,
    required List<MatchRecord> records,
  }) {
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    return MatchStartedReadModel._(
      authoritativelyStarted: temporal.matchStarted,
      activePeriod: temporal.activePeriod,
      temporallyIncomplete: temporal.temporallyIncomplete,
    );
  }
}
