import '../enums/enums.dart';

final class HistoryEntry {
  const HistoryEntry({
    required this.historyId,
    this.eventId,
    required this.action,
    required this.changedAt,
    required this.previousValue,
    required this.newValue,
  });

  final String historyId;
  final String? eventId;
  final HistoryAction action;
  final DateTime changedAt;
  final Map<String, Object?> previousValue;
  final Map<String, Object?> newValue;
}
