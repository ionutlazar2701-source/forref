/// Phone-local training ledger. Not a Match Record and not sporting authority.
library;

enum TrainingKind { general, preMatchWarmUp }

enum TrainingPhase { notStarted, active, paused, finished }

enum TrainingEventKind { started, paused, resumed, finished }

/// Why a new session was not created. The open session is left as it is.
enum TrainingStartDenial {
  anotherSessionOpen,
  matchInProgress,
  matchStateUnverified,
  ledgerUnreadable,
}

final class TrainingEvent {
  const TrainingEvent({required this.kind, required this.at});

  final TrainingEventKind kind;
  final DateTime at;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'at': at.toUtc().toIso8601String(),
      };

  static TrainingEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kindName = raw['kind'];
    final atRaw = raw['at'];
    if (kindName is! String || atRaw is! String) return null;
    final kind = TrainingEventKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    final at = DateTime.tryParse(atRaw);
    if (kind == null || at == null) return null;
    return TrainingEvent(kind: kind, at: at.toUtc());
  }
}

final class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.events,
    this.linkedMatchId,
    this.title,
    this.note,
    this.requestId,
  });

  final String id;
  final TrainingKind kind;
  final String? linkedMatchId;
  final String? title;
  final String? note;
  final DateTime createdAt;
  final String? requestId;
  final List<TrainingEvent> events;

  TrainingPhase get phase {
    if (events.isEmpty) return TrainingPhase.notStarted;
    return switch (events.last.kind) {
      TrainingEventKind.started ||
      TrainingEventKind.resumed =>
        TrainingPhase.active,
      TrainingEventKind.paused => TrainingPhase.paused,
      TrainingEventKind.finished => TrainingPhase.finished,
    };
  }

  bool get isOpen =>
      phase == TrainingPhase.active || phase == TrainingPhase.paused;

  TrainingSession copyWith({
    String? note,
    List<TrainingEvent>? events,
  }) {
    return TrainingSession(
      id: id,
      kind: kind,
      linkedMatchId: linkedMatchId,
      title: title,
      note: note ?? this.note,
      createdAt: createdAt,
      requestId: requestId,
      events: events ?? this.events,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'linkedMatchId': linkedMatchId,
        'title': title,
        'note': note,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'requestId': requestId,
        'events': [for (final event in events) event.toJson()],
      };

  static TrainingSession? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final kindName = raw['kind'];
    final createdRaw = raw['createdAt'];
    final eventsRaw = raw['events'];
    if (id is! String || id.isEmpty || kindName is! String) return null;
    if (createdRaw is! String || eventsRaw is! List) return null;
    final kind = TrainingKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    final createdAt = DateTime.tryParse(createdRaw);
    if (kind == null || createdAt == null) return null;
    final events = <TrainingEvent>[];
    for (final item in eventsRaw) {
      final event = TrainingEvent.fromJson(item);
      if (event == null) return null;
      events.add(event);
    }
    final linked = raw['linkedMatchId'];
    final title = raw['title'];
    final note = raw['note'];
    final requestId = raw['requestId'];
    if (linked != null && linked is! String) return null;
    if (title != null && title is! String) return null;
    if (note != null && note is! String) return null;
    if (requestId != null && requestId is! String) return null;
    return TrainingSession(
      id: id,
      kind: kind,
      linkedMatchId: linked,
      title: title,
      note: note,
      createdAt: createdAt.toUtc(),
      requestId: requestId,
      events: events,
    );
  }
}

/// Measured time from captured segment endpoints.
///
/// [known] is false when an open segment cannot be closed by [now] without
/// inventing a duration, including a clock that moved backwards.
final class TrainingElapsed {
  const TrainingElapsed.measured(Duration this.duration) : known = true;

  const TrainingElapsed.unknown()
      : known = false,
        duration = null;

  final bool known;
  final Duration? duration;
}

final class TrainingFacts {
  const TrainingFacts({
    required this.phase,
    required this.elapsed,
    required this.pauseCount,
  });

  final TrainingPhase phase;
  final TrainingElapsed elapsed;
  final int pauseCount;
}

TrainingFacts trainingFacts(TrainingSession session, DateTime now) {
  var closed = Duration.zero;
  DateTime? open;
  var unknown = false;
  var pauses = 0;
  for (final event in session.events) {
    switch (event.kind) {
      case TrainingEventKind.started:
      case TrainingEventKind.resumed:
        if (open != null) unknown = true;
        open = event.at;
      case TrainingEventKind.paused:
        pauses += 1;
        final closedSegment = _close(open, event.at);
        open = null;
        if (closedSegment == null) {
          unknown = true;
        } else {
          closed += closedSegment;
        }
      case TrainingEventKind.finished:
        final closedSegment = _close(open, event.at);
        open = null;
        if (closedSegment == null) {
          unknown = true;
        } else {
          closed += closedSegment;
        }
    }
  }
  final phase = session.phase;
  if (phase == TrainingPhase.active) {
    final closedSegment = _close(open, now.toUtc());
    if (closedSegment == null) {
      unknown = true;
    } else {
      closed += closedSegment;
    }
  } else if (open != null) {
    unknown = true;
  }
  if (unknown || closed.isNegative) {
    return TrainingFacts(
      phase: phase,
      elapsed: const TrainingElapsed.unknown(),
      pauseCount: pauses,
    );
  }
  return TrainingFacts(
    phase: phase,
    elapsed: TrainingElapsed.measured(closed),
    pauseCount: pauses,
  );
}

Duration? _close(DateTime? open, DateTime end) {
  if (open == null) return null;
  if (end.toUtc().isBefore(open.toUtc())) return null;
  return end.toUtc().difference(open.toUtc());
}

/// Phone-local refusal. Does not stop a match and does not write Match Memory.
TrainingStartDenial? denyTrainingStart({
  required bool anotherSessionOpen,
  required bool matchInProgress,
  required bool matchStateUnverified,
}) {
  if (matchStateUnverified) return TrainingStartDenial.matchStateUnverified;
  if (matchInProgress) return TrainingStartDenial.matchInProgress;
  if (anotherSessionOpen) return TrainingStartDenial.anotherSessionOpen;
  return null;
}

String formatTrainingDuration(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss';
  return '$mm:$ss';
}
