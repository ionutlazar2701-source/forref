import 'dart:convert';
import 'dart:io';

import 'training_session.dart';

const trainingStoreSchema = 1;

/// Result of asking the training ledger to open a session.
sealed class TrainingStartResult {
  const TrainingStartResult();
}

final class TrainingStarted extends TrainingStartResult {
  const TrainingStarted(this.session);

  final TrainingSession session;
}

/// The same warm-up or the same start request already exists.
final class TrainingAlreadyPresent extends TrainingStartResult {
  const TrainingAlreadyPresent(this.session);

  final TrainingSession session;
}

final class TrainingStartBlocked extends TrainingStartResult {
  const TrainingStartBlocked(this.denial);

  final TrainingStartDenial denial;
}

/// JSON ledger beside Match Memory. A missing file is an empty history.
///
/// A file that cannot be decoded is unreadable. It is not shown as an empty
/// history and it is not rewritten.
///
/// Read, decide, and write stay on one synchronous turn. An awaited lock
/// would let two starts both observe an empty ledger, and a future created
/// outside a widget-test zone would never resume that test.
final class TrainingStore {
  TrainingStore({
    required this.directory,
    DateTime Function()? clock,
    String Function()? ids,
  })  : _clock = clock ?? DateTime.now,
        _ids = ids ?? _defaultId;

  final Directory directory;
  final DateTime Function() _clock;
  final String Function() _ids;

  DateTime Function() get clock => _clock;

  File get file => File('${directory.path}/training_sessions.json');

  static int _sequence = 0;

  static String _defaultId() {
    _sequence += 1;
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'training-$micros-$_sequence';
  }

  Future<TrainingLedger> load() => Future<TrainingLedger>.value(_readLedger());

  TrainingLedger _readLedger() {
    final target = file;
    if (!target.existsSync()) {
      return const TrainingLedger(sessions: []);
    }
    try {
      final raw = jsonDecode(target.readAsStringSync());
      if (raw is! Map || raw['schema'] != trainingStoreSchema) {
        return const TrainingLedger(sessions: [], unreadable: true);
      }
      final list = raw['sessions'];
      if (list is! List) {
        return const TrainingLedger(sessions: [], unreadable: true);
      }
      final sessions = <TrainingSession>[];
      for (final item in list) {
        final session = TrainingSession.fromJson(item);
        if (session == null) {
          return const TrainingLedger(sessions: [], unreadable: true);
        }
        sessions.add(session);
      }
      return TrainingLedger(sessions: sessions);
    } catch (_) {
      return const TrainingLedger(sessions: [], unreadable: true);
    }
  }

  Future<TrainingStartResult> startGeneral({
    String? title,
    String? requestId,
  }) {
    final ledger = _readLedger();
    if (ledger.unreadable) {
      return Future<TrainingStartResult>.value(
        const TrainingStartBlocked(TrainingStartDenial.ledgerUnreadable),
      );
    }
    if (requestId != null) {
      final prior = ledger.byRequest(requestId);
      if (prior != null) {
        return Future<TrainingStartResult>.value(TrainingAlreadyPresent(prior));
      }
    }
    final open = ledger.openSession;
    if (open != null) {
      return Future<TrainingStartResult>.value(
        const TrainingStartBlocked(TrainingStartDenial.anotherSessionOpen),
      );
    }
    final session = _newSession(
      kind: TrainingKind.general,
      title: title,
      requestId: requestId,
    );
    _write(ledger.add(session));
    return Future<TrainingStartResult>.value(TrainingStarted(session));
  }

  /// One warm-up for [matchId]. A second call returns the original session.
  Future<TrainingStartResult> startWarmUp({
    required String matchId,
    String? title,
  }) {
    final ledger = _readLedger();
    if (ledger.unreadable) {
      return Future<TrainingStartResult>.value(
        const TrainingStartBlocked(TrainingStartDenial.ledgerUnreadable),
      );
    }
    final existing = ledger.warmUpFor(matchId);
    if (existing != null) {
      return Future<TrainingStartResult>.value(
          TrainingAlreadyPresent(existing));
    }
    if (ledger.openSession != null) {
      return Future<TrainingStartResult>.value(
        const TrainingStartBlocked(TrainingStartDenial.anotherSessionOpen),
      );
    }
    final session = _newSession(
      kind: TrainingKind.preMatchWarmUp,
      title: title,
      linkedMatchId: matchId,
    );
    _write(ledger.add(session));
    return Future<TrainingStartResult>.value(TrainingStarted(session));
  }

  Future<TrainingSession?> session(String id) async {
    final ledger = _readLedger();
    if (ledger.unreadable) return null;
    return ledger.byId(id);
  }

  Future<TrainingSession?> pause(String id) =>
      _transition(id, TrainingEventKind.paused);

  Future<TrainingSession?> resume(String id) =>
      _transition(id, TrainingEventKind.resumed);

  Future<TrainingSession?> finish(String id) =>
      _transition(id, TrainingEventKind.finished);

  Future<TrainingSession?> updateNote(String id, String note) {
    final ledger = _readLedger();
    if (ledger.unreadable) return Future<TrainingSession?>.value();
    final current = ledger.byId(id);
    if (current == null) return Future<TrainingSession?>.value();
    final updated = current.copyWith(note: note);
    _write(ledger.replace(updated));
    return Future<TrainingSession?>.value(updated);
  }

  Future<TrainingSession?> _transition(
    String id,
    TrainingEventKind kind,
  ) {
    final ledger = _readLedger();
    if (ledger.unreadable) return Future<TrainingSession?>.value();
    final current = ledger.byId(id);
    if (current == null) return Future<TrainingSession?>.value();
    final next = _apply(current, kind, _clock().toUtc());
    if (identical(next, current)) {
      return Future<TrainingSession?>.value(current);
    }
    _write(ledger.replace(next));
    return Future<TrainingSession?>.value(next);
  }

  TrainingSession _apply(
    TrainingSession session,
    TrainingEventKind kind,
    DateTime at,
  ) {
    final phase = session.phase;
    final allowed = switch (kind) {
      TrainingEventKind.paused => phase == TrainingPhase.active,
      TrainingEventKind.resumed => phase == TrainingPhase.paused,
      TrainingEventKind.finished =>
        phase == TrainingPhase.active || phase == TrainingPhase.paused,
      TrainingEventKind.started => false,
    };
    if (!allowed) return session;
    return session.copyWith(
      events: [
        ...session.events,
        TrainingEvent(kind: kind, at: at),
      ],
    );
  }

  TrainingSession _newSession({
    required TrainingKind kind,
    String? title,
    String? linkedMatchId,
    String? requestId,
  }) {
    final now = _clock().toUtc();
    return TrainingSession(
      id: _ids(),
      kind: kind,
      linkedMatchId: linkedMatchId,
      title: _blankToNull(title),
      createdAt: now,
      requestId: requestId,
      events: [TrainingEvent(kind: TrainingEventKind.started, at: now)],
    );
  }

  void _write(TrainingLedger ledger) {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final payload = jsonEncode({
      'schema': trainingStoreSchema,
      'sessions': [for (final session in ledger.sessions) session.toJson()],
    });
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(payload, flush: true);
    tmp.renameSync(file.path);
  }
}

final class TrainingLedger {
  const TrainingLedger({required this.sessions, this.unreadable = false});

  final List<TrainingSession> sessions;
  final bool unreadable;

  TrainingSession? get openSession {
    for (final session in sessions) {
      if (session.isOpen) return session;
    }
    return null;
  }

  TrainingSession? byId(String id) {
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  TrainingSession? byRequest(String requestId) {
    for (final session in sessions) {
      if (session.requestId == requestId) return session;
    }
    return null;
  }

  TrainingSession? warmUpFor(String matchId) {
    for (final session in sessions) {
      if (session.kind == TrainingKind.preMatchWarmUp &&
          session.linkedMatchId == matchId) {
        return session;
      }
    }
    return null;
  }

  TrainingLedger add(TrainingSession session) {
    return TrainingLedger(sessions: [...sessions, session]);
  }

  TrainingLedger replace(TrainingSession session) {
    return TrainingLedger(
      sessions: [
        for (final current in sessions)
          if (current.id == session.id) session else current,
      ],
    );
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
