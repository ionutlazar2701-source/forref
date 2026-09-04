import '../enums/enums.dart';
import 'player.dart';

final class Score {
  const Score({
    required this.home,
    required this.away,
  });

  final int home;
  final int away;
}

/// Type-specific payload. Same schema for Quick Capture and edit.
final class EventData {
  const EventData({
    this.teamId,
    this.player,
    this.out,
    this.inPlayer,
    this.isOwnGoal,
    this.note,
    this.reason,
  });

  final String? teamId;
  final PlayerRef? player;
  final PlayerRef? out;
  final PlayerRef? inPlayer;
  final bool? isOwnGoal;
  final String? note;
  final String? reason;
}

final class MatchEvent {
  const MatchEvent({
    required this.eventId,
    required this.matchId,
    required this.type,
    required this.status,
    required this.periodId,
    required this.matchTime,
    required this.createdAt,
    required this.updatedAt,
    required this.data,
  });

  final String eventId;
  final String matchId;
  final EventType type;
  final EventStatus status;
  final PeriodId periodId;
  final int matchTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EventData data;

  MatchEvent copyWith({
    EventType? type,
    EventStatus? status,
    PeriodId? periodId,
    int? matchTime,
    DateTime? updatedAt,
    EventData? data,
  }) {
    return MatchEvent(
      eventId: eventId,
      matchId: matchId,
      type: type ?? this.type,
      status: status ?? this.status,
      periodId: periodId ?? this.periodId,
      matchTime: matchTime ?? this.matchTime,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      data: data ?? this.data,
    );
  }
}
