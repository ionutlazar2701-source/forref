import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/features/live_match/goal_time_label.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/match/match_session.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/match_application/goal_match_read_model.dart';
import 'package:referee_phone/routing/app_router.dart';

class MatchSummaryPage extends StatefulWidget {
  const MatchSummaryPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchSummaryPage> createState() => _MatchSummaryPageState();
}

class _MatchSummaryPageState extends State<MatchSummaryPage> {
  MatchSession? _session;
  GoalMatchReadModel? _goalRead;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final match = await scope.database.getMatch(widget.matchId);
    if (!mounted || match == null) return;
    _session?.dispose();
    final session = MatchSession(
      database: scope.database,
      match: match,
    );
    session.addListener(() {
      if (mounted) setState(() {});
    });
    final goalRead = await loadGoalMatchReadModel(
      scope,
      widget.matchId,
      legacyMatch: match,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      _goalRead = goalRead;
    });
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final session = _session;
    if (session == null) return;
    final l10n = AppLocalizations.of(context);
    final incomplete =
        session.validator.incompleteCount(session.match.events);
    if (incomplete > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text(l10n.finishIncompleteBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.reviewEvents),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.finishAnyway),
              ),
            ],
          );
        },
      );
      if (go != true) return;
    }
    await session.finish();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final match = session.match;
    final goalRead = _goalRead;
    final homeScore = goalRead?.homeScore ?? match.score.home;
    final awayScore = goalRead?.awayScore ?? match.score.away;
    final history = goalRead == null
        ? null
        : buildSummaryHistory(
            projection: goalRead.projection,
            legacyEvents: match.events,
          );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.summary)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.scoreLine(
              homeLabel(match, l10n),
              homeScore,
              awayScore,
              awayLabel(match, l10n),
            ),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(matchStatusLabel(match, l10n)),
          Text(formatMatchClock(session.displayedElapsed())),
          if (goalRead?.legacyGoalsOnly == true) ...[
            const SizedBox(height: 8),
            Text(
              l10n.legacyGoalsNotIncluded,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          if (history != null)
            for (final entry in history)
              if (entry.goal case final goal?)
                ListTile(
                  title: Text(
                    '${formatProjectedGoalTime(goal.temporal, l10n)}  ${l10n.goal}',
                  ),
                  subtitle: Text(
                    goal.creditedSide == CreditedSide.home
                        ? homeLabel(match, l10n)
                        : awayLabel(match, l10n),
                  ),
                )
              else if (entry.legacyEvent case final event?)
                ListTile(
                  title: Text(
                    '${formatMatchClock(event.matchTime)}  ${eventTypeLabel(event.type, l10n)}'
                    '${event.status == EventStatus.incomplete ? ' · ${l10n.incomplete}' : ''}',
                  ),
                )
          else
            for (final event in match.events.reversed)
              ListTile(
                title: Text(
                  '${formatMatchClock(event.matchTime)}  ${eventTypeLabel(event.type, l10n)}'
                  '${event.status == EventStatus.incomplete ? ' · ${l10n.incomplete}' : ''}',
                ),
              ),
          const SizedBox(height: 16),
          if (match.status == MatchStatus.fullTime)
            FilledButton(
              onPressed: _finish,
              child: Text(l10n.finishMatch),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(
              AppRouter.liveMatch,
              arguments: widget.matchId,
            ),
            child: Text(l10n.backToMatch),
          ),
        ],
      ),
    );
  }
}
