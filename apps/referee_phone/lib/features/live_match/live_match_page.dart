import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/features/live_match/capture_overlay.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/match/match_session.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/routing/app_router.dart';

class LiveMatchPage extends StatefulWidget {
  const LiveMatchPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<LiveMatchPage> createState() => _LiveMatchPageState();
}

class _LiveMatchPageState extends State<LiveMatchPage> {
  MatchSession? _session;
  EventType? _captureType;
  DateTime? _lastActionAt;
  EventType? _lastActionType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final match =
        await AppScope.of(context).database.getMatch(widget.matchId);
    if (!mounted || match == null) return;
    _session?.dispose();
    final session = MatchSession(
      database: AppScope.of(context).database,
      match: match,
    );
    session.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _session = session);
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  void _startCapture(EventType type) {
    final now = DateTime.now();
    if (_captureType == null &&
        _lastActionType == type &&
        _lastActionAt != null &&
        now.difference(_lastActionAt!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastActionAt = now;
    _lastActionType = type;
    setState(() => _captureType = type);
  }

  Future<void> _onState(Future<void> Function() action) async {
    try {
      await action();
    } on StateError {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final match = session.match;
    final addedMinutes = match.currentState.addedTimeSeconds ~/ 60;
    final clock = formatMatchClock(session.displayedElapsed());
    final recent = match.events.reversed.take(7).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.liveMatch),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(
              AppRouter.matchSetup,
              arguments: widget.matchId,
            ),
            child: Text(l10n.setupTitle),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$clock  ${periodLabel(match.currentState.periodId, l10n)}  ${matchStatusLabel(match, l10n)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (addedMinutes > 0)
                Text(l10n.clockWithAdded(clock, addedMinutes)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (match.status == MatchStatus.ready)
                    FilledButton(
                      onPressed: () => _onState(session.kickOff),
                      child: Text(l10n.kickOff),
                    ),
                  if (match.status == MatchStatus.live)
                    FilledButton(
                      onPressed: () => _onState(session.pause),
                      child: Text(l10n.pause),
                    ),
                  if (match.status == MatchStatus.paused)
                    FilledButton(
                      onPressed: () => _onState(session.resume),
                      child: Text(l10n.resume),
                    ),
                  if ((match.status == MatchStatus.live ||
                          match.status == MatchStatus.paused) &&
                      (match.currentState.periodId == PeriodId.firstHalf ||
                          match.currentState.periodId == PeriodId.extraTime1))
                    FilledButton.tonal(
                      onPressed: () => _onState(session.halfTime),
                      child: Text(l10n.halfTime),
                    ),
                  if (match.status == MatchStatus.halfTime)
                    FilledButton(
                      onPressed: () => _onState(session.startSecondHalf),
                      child: Text(l10n.startSecondHalf),
                    ),
                  if ((match.status == MatchStatus.live ||
                          match.status == MatchStatus.paused) &&
                      match.currentState.periodId == PeriodId.secondHalf)
                    FilledButton.tonal(
                      onPressed: () => _onState(session.extraTime),
                      child: Text(l10n.extraTime),
                    ),
                  if (match.status == MatchStatus.live ||
                      match.status == MatchStatus.paused ||
                      match.status == MatchStatus.halfTime)
                    FilledButton.tonal(
                      onPressed: () => _onState(session.fullTime),
                      child: Text(l10n.fullTime),
                    ),
                  if (match.status == MatchStatus.fullTime)
                    FilledButton(
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRouter.matchSummary,
                        arguments: widget.matchId,
                      ),
                      child: Text(l10n.summary),
                    ),
                ],
              ),
              Row(
                children: [
                  Text(l10n.addedTime),
                  IconButton(
                    onPressed: () =>
                        session.setAddedMinutes(addedMinutes - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$addedMinutes'),
                  IconButton(
                    onPressed: () =>
                        session.setAddedMinutes(addedMinutes + 1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              Text(
                l10n.scoreLine(
                  homeLabel(match, l10n),
                  match.score.home,
                  match.score.away,
                  awayLabel(match, l10n),
                ),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in EventType.values)
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => _startCapture(type),
                        child: Text(eventTypeLabel(type, l10n)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              for (final event in recent)
                ListTile(
                  title: Text(
                    '${formatMatchClock(event.matchTime)}  ${eventTypeLabel(event.type, l10n)}'
                    '${event.status == EventStatus.incomplete ? ' · ${l10n.incomplete}' : ''}',
                  ),
                  subtitle: Text(
                    event.data.teamId == null
                        ? ''
                        : teamLabel(match, event.data.teamId!, l10n),
                  ),
                  onTap: () => _edit(event),
                ),
            ],
          ),
          if (session.undoEventId != null || session.canUndoFullTime)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: FilledButton.tonal(
                  onPressed: session.canUndoFullTime
                      ? session.undoFullTime
                      : session.undoLastSave,
                  child: Text(l10n.undo),
                ),
              ),
            ),
          if (_captureType != null)
            Positioned.fill(
              child: CaptureOverlay(
                match: match,
                type: _captureType!,
                onTypeChanged: (type) => setState(() => _captureType = type),
                onCancel: () => setState(() => _captureType = null),
                onSave: (type, data) async {
                  setState(() => _captureType = null);
                  await session.saveEvent(type: type, data: data);
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(MatchEvent event) async {
    final session = _session;
    if (session == null) return;
    final l10n = AppLocalizations.of(context);
    var type = event.type;
    var time = event.matchTime;
    var ownGoal = event.data.isOwnGoal ?? false;
    final next = await showModalBottomSheet<MatchEvent>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.editEvent),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final value in EventType.values)
                        ChoiceChip(
                          label: Text(eventTypeLabel(value, l10n)),
                          selected: type == value,
                          onSelected: (_) => setModal(() => type = value),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setModal(() => time = time - 30),
                        child: Text(l10n.nudgeMinus),
                      ),
                      Text(formatMatchClock(time < 0 ? 0 : time)),
                      TextButton(
                        onPressed: () => setModal(() => time += 30),
                        child: Text(l10n.nudgePlus),
                      ),
                    ],
                  ),
                  if (type == EventType.goal)
                    CheckboxListTile(
                      title: Text(l10n.ownGoal),
                      value: ownGoal,
                      onChanged: (value) =>
                          setModal(() => ownGoal = value ?? false),
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      event.copyWith(
                        type: type,
                        matchTime: time < 0 ? 0 : time,
                        data: EventData(
                          teamId: event.data.teamId,
                          player: event.data.player,
                          out: event.data.out,
                          inPlayer: event.data.inPlayer,
                          isOwnGoal: type == EventType.goal ? ownGoal : null,
                          note: event.data.note,
                          reason: event.data.reason,
                        ),
                      ),
                    ),
                    child: Text(l10n.editEvent),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (next != null) await session.updateEvent(next);
  }
}
