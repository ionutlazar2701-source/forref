import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/design/forref_components.dart';
import 'package:referee_phone/design/forref_spacing.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/officiate/fixture_list.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/match/match_session.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/routing/app_router.dart';

class MatchSummaryPage extends StatefulWidget {
  const MatchSummaryPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchSummaryPage> createState() => _MatchSummaryPageState();
}

class _MatchSummaryPageState extends State<MatchSummaryPage> {
  MatchSession? _session;
  ScoreProjection? _scoreProjection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final match = await AppScope.of(context).database.getMatch(widget.matchId);
    if (!mounted || match == null) return;
    _session?.dispose();
    final session = MatchSession(
      database: AppScope.of(context).database,
      match: match,
    );
    session.addListener(() {
      if (mounted) setState(() {});
    });
    final scope = AppScope.of(context);
    ScoreProjection? scoreProjection;
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    if (boundary != null && identity != null) {
      try {
        scoreProjection = await boundary.readScoreProjection(
          matchId: widget.matchId,
          evaluatedAuthorityGeneration:
              PhoneCaptureIdentity.initialAuthorityGeneration,
          homeTeamId: MatchTeamId(match.teams.home.teamId),
          awayTeamId: MatchTeamId(match.teams.away.teamId),
        );
      } catch (_) {
        scoreProjection = const ScoreUnavailable();
      }
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _scoreProjection = scoreProjection;
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
    final incomplete = session.validator.incompleteCount(session.match.events);
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.summary)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ForrefSpace.s20,
          ForrefSpace.s16,
          ForrefSpace.s20,
          ForrefSpace.s32,
        ),
        children: [
          ForrefFixtureIdentity(
            title: fixtureTitle(
              match,
              homeNotSet: l10n.homeTeamNotSet,
              awayNotSet: l10n.awayTeamNotSet,
            ),
            detail: '${match.date} · ${matchStatusLabel(match, l10n)}',
            large: true,
          ),
          const SizedBox(height: ForrefSpace.s24),
          if (_summaryScoreHeadline(context, match, l10n) != null)
            _summaryScoreHeadline(context, match, l10n)!,
          Text(
            formatMatchClock(session.displayedElapsed()),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
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
            key: const Key('open-match-record'),
            onPressed: () => Navigator.of(context).pushNamed(
              AppRouter.matchRecord,
              arguments: widget.matchId,
            ),
            child: Text(l10n.matchRecordAction),
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

  Widget? _summaryScoreHeadline(
    BuildContext context,
    Match match,
    AppLocalizations l10n,
  ) {
    final boundary = AppScope.of(context).matchApplication;
    if (boundary == null) {
      return Text(
        l10n.scoreLine(
          homeLabel(match, l10n),
          match.score.home,
          match.score.away,
          awayLabel(match, l10n),
        ),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    final projection = _scoreProjection;
    if (projection == null || projection is! KnownScore) {
      return null;
    }
    final homeId = MatchTeamId(match.teams.home.teamId);
    final awayId = MatchTeamId(match.teams.away.teamId);
    final homeScore = projection.goalsByTeam[homeId];
    final awayScore = projection.goalsByTeam[awayId];
    if (homeScore == null || awayScore == null) return null;
    return Text(
      l10n.scoreLine(
        homeLabel(match, l10n),
        homeScore,
        awayScore,
        awayLabel(match, l10n),
      ),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
