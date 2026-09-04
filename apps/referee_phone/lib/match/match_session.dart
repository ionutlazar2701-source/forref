import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/match/client_ids.dart';

/// Holds the live [Match], persists every engine change, ticks the UI clock.
final class MatchSession extends ChangeNotifier {
  MatchSession({
    required this.database,
    required Match match,
  }) : _match = match {
    _syncTicker();
  }

  final LocalMatchDatabase database;
  final MatchClock clock = const MatchClock();
  final MatchLifecycle lifecycle = const MatchLifecycle();
  final EventFactory events = const EventFactory();
  final EventReducer reducer = const EventReducer();
  final EventValidator validator = const EventValidator();

  Match _match;
  Timer? _ticker;
  Timer? _undoTimer;
  String? _undoEventId;
  bool _undoFullTime = false;

  Match get match => _match;

  String? get undoEventId => _undoEventId;
  bool get canUndoFullTime =>
      _undoFullTime && lifecycle.canUndoFullTime(_match);

  int displayedElapsed([DateTime? now]) =>
      clock.currentElapsed(_match.currentState, (now ?? DateTime.now()).toUtc());

  Future<void> replace(Match next) async {
    _match = next;
    _syncTicker();
    notifyListeners();
    await database.upsertMatch(_match);
  }

  Future<void> goReady() {
    return replace(
      _match.copyWith(
        status: MatchStatus.ready,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> kickOff() =>
      replace(lifecycle.applyKickOff(_match, DateTime.now().toUtc()));

  Future<void> pause() =>
      replace(lifecycle.applyPause(_match, DateTime.now().toUtc()));

  Future<void> resume() =>
      replace(lifecycle.applyResume(_match, DateTime.now().toUtc()));

  Future<void> halfTime() =>
      replace(lifecycle.applyHalfTime(_match, DateTime.now().toUtc()));

  Future<void> startSecondHalf() =>
      replace(lifecycle.applyStartSecondHalf(_match, DateTime.now().toUtc()));

  Future<void> extraTime() =>
      replace(lifecycle.applyStartExtraTime(_match, DateTime.now().toUtc()));

  Future<void> fullTime() async {
    await replace(
      lifecycle.applyFullTime(
        _match,
        historyId: clientId(),
        now: DateTime.now().toUtc(),
      ),
    );
    _armUndo(fullTime: true);
  }

  Future<void> undoFullTime() async {
    if (!canUndoFullTime) return;
    _clearUndo();
    await replace(
      lifecycle.undoFullTime(
        _match,
        historyId: clientId(),
        now: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> finish() =>
      replace(lifecycle.applyFinish(_match, DateTime.now().toUtc()));

  Future<void> setAddedMinutes(int minutes) {
    final seconds = minutes < 0 ? 0 : minutes * 60;
    return replace(
      lifecycle.setAddedTime(_match, seconds, DateTime.now().toUtc()),
    );
  }

  Future<void> saveEvent({
    required EventType type,
    required EventData data,
    int? matchTime,
  }) async {
    final now = DateTime.now().toUtc();
    final event = events.create(
      eventId: clientId(),
      matchId: _match.matchId,
      type: type,
      periodId: _match.currentState.periodId,
      matchTime: matchTime ?? displayedElapsed(now),
      now: now,
      data: data,
    );
    await replace(reducer.applyNewEvent(_match, event));
    _armUndo(eventId: event.eventId);
  }

  Future<void> updateEvent(MatchEvent updated) async {
    await replace(
      reducer.applyEventUpdate(
        _match,
        updated,
        historyId: clientId(),
        now: DateTime.now().toUtc(),
      ),
    );
    _clearUndo();
  }

  Future<void> undoLastSave() async {
    final id = _undoEventId;
    if (id == null) return;
    _clearUndo();
    await replace(
      reducer.undoNewEvent(
        _match,
        eventId: id,
        historyId: clientId(),
        now: DateTime.now().toUtc(),
      ),
    );
  }

  void _armUndo({String? eventId, bool fullTime = false}) {
    _undoTimer?.cancel();
    _undoEventId = eventId;
    _undoFullTime = fullTime;
    notifyListeners();
    _undoTimer = Timer(const Duration(seconds: 5), () {
      _clearUndo();
      notifyListeners();
    });
  }

  void _clearUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _undoEventId = null;
    _undoFullTime = false;
  }

  void _syncTicker() {
    final running = _match.currentState.clockRunning;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        notifyListeners();
      });
    } else if (!running && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _undoTimer?.cancel();
    super.dispose();
  }
}
