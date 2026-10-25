import 'dart:async';

import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/design/forref_components.dart';
import 'package:referee_phone/design/forref_spacing.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/officiate/fixture_list.dart';
import 'package:referee_phone/officiate/match_record_view.dart';

/// Read-only Match Record. Opening it does not commit a Match Record.
class MatchRecordPage extends StatefulWidget {
  const MatchRecordPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchRecordPage> createState() => _MatchRecordPageState();
}

class _MatchRecordPageState extends State<MatchRecordPage> {
  Match? _match;
  MatchRecordView? _view;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final match = await scope.database.getMatch(widget.matchId);
    if (!mounted) return;
    if (match == null) {
      setState(() => _missing = true);
      return;
    }
    final view = await loadMatchRecordView(
      boundary: scope.matchApplication,
      matchId: widget.matchId,
      legacyStatus: match.status,
      homeTeamId: match.teams.home.teamId,
      awayTeamId: match.teams.away.teamId,
    );
    if (!mounted) return;
    setState(() {
      _match = match;
      _view = view;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = _match;
    final view = _view;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matchRecordTitle)),
      body: _missing
          ? Padding(
              padding: const EdgeInsets.all(ForrefSpace.s20),
              child: ForrefNotice(
                title: l10n.matchRecordUnavailable,
                tone: ForrefNoticeTone.unavailable,
              ),
            )
          : match == null || view == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(ForrefSpace.s20),
                  children: [
                    ForrefFixtureIdentity(
                      title: fixtureTitle(
                        match,
                        homeNotSet: l10n.homeTeamNotSet,
                        awayNotSet: l10n.awayTeamNotSet,
                      ),
                      detail: match.date,
                    ),
                    const SizedBox(height: ForrefSpace.s12),
                    Text(l10n.matchRecordReadOnly),
                    const SizedBox(height: ForrefSpace.s16),
                    ForrefNotice(
                      title: _scoreTitle(l10n, match, view),
                      titleKey: const Key('match-record-score'),
                      tone: view.scoreKind == MatchRecordScoreKind.known
                          ? ForrefNoticeTone.neutral
                          : ForrefNoticeTone.unavailable,
                      lines: [
                        if (view.availability ==
                            MatchRecordAvailability.unavailable)
                          l10n.matchRecordUnavailable,
                        if (view.availability ==
                            MatchRecordAvailability.noCommittedRecords)
                          l10n.matchRecordNoEvents,
                        if (view.phaseUnavailable &&
                            view.availability ==
                                MatchRecordAvailability.readable)
                          l10n.matchRecordPhaseUnavailable,
                        if (view.matchNormallyEnded) l10n.matchRecordEndedFact,
                        if (view.legacyFullTime && !view.matchNormallyEnded)
                          l10n.matchRecordNotComplete,
                      ],
                    ),
                    const SizedBox(height: ForrefSpace.s16),
                    for (final fact in view.facts)
                      ListTile(
                        key: Key('match-record-fact-${fact.originSequence}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(_factLabel(l10n, match, fact)),
                      ),
                  ],
                ),
    );
  }
}

String _scoreTitle(AppLocalizations l10n, Match match, MatchRecordView view) {
  if (view.scoreKind == MatchRecordScoreKind.known &&
      view.homeGoals != null &&
      view.awayGoals != null) {
    return l10n.scoreLine(
      homeLabel(match, l10n),
      view.homeGoals!,
      view.awayGoals!,
      awayLabel(match, l10n),
    );
  }
  if (view.scoreKind == MatchRecordScoreKind.conflicted) {
    return l10n.matchRecordScoreConflicted;
  }
  return l10n.matchRecordScoreUnavailable;
}

String _factLabel(AppLocalizations l10n, Match match, MatchRecordFact fact) {
  return switch (fact.kind) {
    MatchRecordFactKind.goal => l10n.matchRecordGoal(
        fact.teamId == match.teams.home.teamId
            ? homeLabel(match, l10n)
            : fact.teamId == match.teams.away.teamId
                ? awayLabel(match, l10n)
                : (fact.teamId ?? ''),
      ),
    MatchRecordFactKind.matchStarted => l10n.matchStarted,
    MatchRecordFactKind.periodStarted =>
      l10n.matchRecordPeriodStarted(fact.periodIndex ?? 0),
    MatchRecordFactKind.periodEnded =>
      l10n.matchRecordPeriodEnded(fact.periodIndex ?? 0),
    MatchRecordFactKind.matchEnded => l10n.matchRecordEndedFact,
    MatchRecordFactKind.other => l10n.matchRecordOther,
  };
}
