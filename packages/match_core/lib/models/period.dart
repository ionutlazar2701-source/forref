import '../enums/enums.dart';

/// Canonical period slots. `pens` stays pending in MVP.
List<Period> defaultMatchPeriods() => const [
      Period(id: PeriodId.firstHalf, status: PeriodStatus.pending),
      Period(id: PeriodId.secondHalf, status: PeriodStatus.pending),
      Period(id: PeriodId.extraTime1, status: PeriodStatus.pending),
      Period(id: PeriodId.extraTime2, status: PeriodStatus.pending),
      Period(id: PeriodId.penalties, status: PeriodStatus.pending),
    ];

final class Period {
  const Period({
    required this.id,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.addedTimeSeconds = 0,
  });

  final PeriodId id;
  final PeriodStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int addedTimeSeconds;

  Period copyWith({
    PeriodStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? addedTimeSeconds,
  }) {
    return Period(
      id: id,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      addedTimeSeconds: addedTimeSeconds ?? this.addedTimeSeconds,
    );
  }
}
