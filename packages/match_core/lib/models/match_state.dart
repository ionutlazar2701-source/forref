import '../enums/enums.dart';

/// Persisted clock cache. Reconstruct; do not tick every second.
final class MatchState {
  const MatchState({
    required this.periodId,
    required this.clockRunning,
    required this.elapsedSeconds,
    this.runningSince,
    this.addedTimeSeconds = 0,
  });

  final PeriodId periodId;
  final bool clockRunning;
  final int elapsedSeconds;
  final DateTime? runningSince;
  final int addedTimeSeconds;

  MatchState copyWith({
    PeriodId? periodId,
    bool? clockRunning,
    int? elapsedSeconds,
    DateTime? runningSince,
    bool clearRunningSince = false,
    int? addedTimeSeconds,
  }) {
    return MatchState(
      periodId: periodId ?? this.periodId,
      clockRunning: clockRunning ?? this.clockRunning,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      runningSince:
          clearRunningSince ? null : (runningSince ?? this.runningSince),
      addedTimeSeconds: addedTimeSeconds ?? this.addedTimeSeconds,
    );
  }
}
