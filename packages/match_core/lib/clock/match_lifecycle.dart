import '../enums/enums.dart';
import '../history/history_builder.dart';
import '../models/history_entry.dart';
import '../models/match.dart';
import '../models/match_state.dart';
import '../models/period.dart';
import '../serialization/match_json.dart';
import 'match_clock.dart';

/// Match-level period bookends. The 5 s Undo window is UI; this restores state.
final class MatchLifecycle {
  const MatchLifecycle({
    this.clock = const MatchClock(),
    this.history = const HistoryBuilder(),
    this.codec = const MatchJson(),
  });

  final MatchClock clock;
  final HistoryBuilder history;
  final MatchJson codec;

  Match applyKickOff(Match match, DateTime now) =>
      clock.applyKickOff(match, now);

  /// LIVE → PAUSED. Does not change period. Extra pause confirm is UI-only.
  Match applyPause(Match match, DateTime now) {
    if (match.status == MatchStatus.paused) {
      return match;
    }
    _require(match, {MatchStatus.live}, 'Pause');
    final utc = now.toUtc();
    final paused = clock.onPause(match.currentState, utc);
    return match.copyWith(
      status: MatchStatus.paused,
      updatedAt: utc,
      periods: _setStatus(
        match.periods,
        paused.periodId,
        PeriodStatus.paused,
      ),
      currentState: paused,
    );
  }

  /// PAUSED → LIVE. Must not start 2H / ET (use [applyStartSecondHalf]).
  Match applyResume(Match match, DateTime now) {
    if (match.status == MatchStatus.halfTime) {
      throw StateError('Resume must not start the next half');
    }
    _require(match, {MatchStatus.paused}, 'Resume');
    final utc = now.toUtc();
    final running = clock.onResume(match.currentState, utc);
    return match.copyWith(
      status: MatchStatus.live,
      updatedAt: utc,
      periods: _setStatus(
        match.periods,
        running.periodId,
        PeriodStatus.active,
      ),
      currentState: running,
    );
  }

  /// Ends 1H or ET1. Clock frozen. Next half is a separate action.
  Match applyHalfTime(Match match, DateTime now) {
    _require(match, {MatchStatus.live, MatchStatus.paused}, 'Half-time');
    final periodId = match.currentState.periodId;
    if (periodId != PeriodId.firstHalf && periodId != PeriodId.extraTime1) {
      throw StateError(
        'Half-time requires 1H or ET1, was ${periodId.jsonValue}',
      );
    }
    final utc = now.toUtc();
    final frozen = _freeze(match.currentState, utc);
    return match.copyWith(
      status: MatchStatus.halfTime,
      updatedAt: utc,
      periods: _completePeriod(match.periods, periodId, utc, frozen),
      currentState: frozen,
    );
  }

  /// From HALF-TIME: 1H → 2H, or ET1 → ET2. Clock from 00:00.
  Match applyStartSecondHalf(Match match, DateTime now) {
    _require(match, {MatchStatus.halfTime}, 'Start second half');
    final nextId = switch (match.currentState.periodId) {
      PeriodId.firstHalf => PeriodId.secondHalf,
      PeriodId.extraTime1 => PeriodId.extraTime2,
      final other => throw StateError(
          'Start second half is not valid after ${other.jsonValue}',
        ),
    };
    return _startPeriod(match, nextId, now.toUtc());
  }

  /// Optional ET from 2H, before Full time. Stays LIVE; period `et1`.
  Match applyStartExtraTime(Match match, DateTime now) {
    _require(match, {MatchStatus.live, MatchStatus.paused}, 'Extra time');
    if (match.currentState.periodId != PeriodId.secondHalf) {
      throw StateError('Extra time starts from 2H, before Full time');
    }
    final utc = now.toUtc();
    final frozen = _freeze(match.currentState, utc);
    final ended = _completePeriod(
      match.periods,
      PeriodId.secondHalf,
      utc,
      frozen,
    );
    return _startPeriod(
      match.copyWith(periods: ended, currentState: frozen),
      PeriodId.extraTime1,
      utc,
    );
  }

  /// Playing ended. Not COMPLETED. Never blocked by incomplete events.
  Match applyFullTime(
    Match match, {
    required String historyId,
    required DateTime now,
  }) {
    _require(
      match,
      {MatchStatus.live, MatchStatus.paused, MatchStatus.halfTime},
      'Full time',
    );
    if (match.currentState.periodId == PeriodId.penalties) {
      throw StateError('Penalty kicks are not activated in MVP');
    }
    final utc = now.toUtc();
    final previous = codec.clockFieldsToJson(match);
    final frozen = _freeze(match.currentState, utc);
    final periodId = frozen.periodId;
    final periods = _period(match.periods, periodId).status ==
            PeriodStatus.completed
        ? _periodsOrDefault(match.periods)
        : _completePeriod(match.periods, periodId, utc, frozen);
    final next = match.copyWith(
      status: MatchStatus.fullTime,
      updatedAt: utc,
      periods: periods,
      currentState: frozen,
    );
    return next.copyWith(
      history: [
        ...match.history,
        history.matchFields(
          historyId: historyId,
          action: HistoryAction.update,
          changedAt: utc,
          previousValue: previous,
          newValue: codec.clockFieldsToJson(next),
        ),
      ],
    );
  }

  /// Cancels Full time. The 5 s window is enforced by the UI, not here.
  Match undoFullTime(
    Match match, {
    required String historyId,
    required DateTime now,
  }) {
    _require(match, {MatchStatus.fullTime}, 'Undo full time');
    final snapshot = _fullTimeEntry(match);
    if (snapshot == null) {
      throw StateError('No full-time snapshot to undo');
    }
    final utc = now.toUtc();
    final restored = codec.applyClockFields(match, snapshot.previousValue);
    final elapsed = match.currentState.elapsedSeconds;
    final running = restored.status == MatchStatus.live;
    final state = restored.currentState.copyWith(
      elapsedSeconds: elapsed,
      clockRunning: running,
      runningSince: running ? utc : null,
      clearRunningSince: !running,
    );
    final withClock = restored.copyWith(currentState: state, updatedAt: utc);
    return withClock.copyWith(
      history: [
        ...match.history,
        history.matchFields(
          historyId: historyId,
          action: HistoryAction.undo,
          changedAt: utc,
          previousValue: codec.clockFieldsToJson(match),
          newValue: codec.clockFieldsToJson(withClock),
        ),
      ],
    );
  }

  /// FULL TIME → COMPLETED. Confirm-if-incomplete is UI-only.
  Match applyFinish(Match match, DateTime now) {
    _require(match, {MatchStatus.fullTime}, 'Finish match');
    final utc = now.toUtc();
    return match.copyWith(
      status: MatchStatus.completed,
      updatedAt: utc,
      currentState: clock.onPause(match.currentState, utc),
    );
  }

  /// Announced `+N` on the current period. Not a second clock.
  Match setAddedTime(Match match, int seconds, DateTime now) {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', 'must be >= 0');
    }
    if (match.status == MatchStatus.ready ||
        match.status == MatchStatus.setup) {
      throw StateError('Added time is set during the match, not in setup');
    }
    final utc = now.toUtc();
    final periodId = match.currentState.periodId;
    return match.copyWith(
      updatedAt: utc,
      currentState: match.currentState.copyWith(addedTimeSeconds: seconds),
      periods: _updatePeriod(
        match.periods,
        periodId,
        (period) => period.copyWith(addedTimeSeconds: seconds),
      ),
    );
  }

  HistoryEntry? _fullTimeEntry(Match match) {
    for (final entry in match.history.reversed) {
      if (entry.eventId == null &&
          entry.action == HistoryAction.update &&
          entry.newValue['status'] == MatchStatus.fullTime.jsonValue) {
        return entry;
      }
    }
    return null;
  }

  bool canUndoFullTime(Match match) =>
      match.status == MatchStatus.fullTime && _fullTimeEntry(match) != null;

  MatchState _freeze(MatchState state, DateTime utc) =>
      clock.onPause(state, utc);

  Match _startPeriod(Match match, PeriodId id, DateTime utc) {
    if (id == PeriodId.penalties) {
      throw StateError('Penalty kicks are not activated in MVP');
    }
    return match.copyWith(
      status: MatchStatus.live,
      updatedAt: utc,
      periods: _updatePeriod(
        match.periods,
        id,
        (period) => period.copyWith(
          status: PeriodStatus.active,
          startedAt: utc,
        ),
      ),
      currentState: MatchState(
        periodId: id,
        clockRunning: true,
        elapsedSeconds: 0,
        runningSince: utc,
        addedTimeSeconds: 0,
      ),
    );
  }

  List<Period> _completePeriod(
    List<Period> periods,
    PeriodId id,
    DateTime utc,
    MatchState frozen,
  ) {
    return _updatePeriod(
      periods,
      id,
      (period) => period.copyWith(
        status: PeriodStatus.completed,
        endedAt: utc,
        addedTimeSeconds: frozen.addedTimeSeconds,
      ),
    );
  }

  List<Period> _setStatus(
    List<Period> periods,
    PeriodId id,
    PeriodStatus status,
  ) {
    return _updatePeriod(
      periods,
      id,
      (period) => period.copyWith(status: status),
    );
  }

  List<Period> _updatePeriod(
    List<Period> periods,
    PeriodId id,
    Period Function(Period) update,
  ) {
    final list = [..._periodsOrDefault(periods)];
    final index = list.indexWhere((period) => period.id == id);
    if (index < 0) {
      throw StateError('Missing period ${id.jsonValue}');
    }
    list[index] = update(list[index]);
    return list;
  }

  Period _period(List<Period> periods, PeriodId id) {
    return _periodsOrDefault(periods).firstWhere(
      (period) => period.id == id,
      orElse: () => throw StateError('Missing period ${id.jsonValue}'),
    );
  }

  List<Period> _periodsOrDefault(List<Period> periods) =>
      periods.isEmpty ? defaultMatchPeriods() : periods;

  void _require(Match match, Set<MatchStatus> allowed, String action) {
    if (!allowed.contains(match.status)) {
      throw StateError(
        '$action requires ${allowed.map((s) => s.jsonValue).join('|')}, '
        'was ${match.status.jsonValue}',
      );
    }
  }
}

