import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/match_application/match_read_path.dart';
import 'package:referee_phone/routing/app_router.dart';

/// Read-only Match Report. Sporting lines come from [readMatchReport].
class MatchReportPage extends StatefulWidget {
  const MatchReportPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchReportPage> createState() => _MatchReportPageState();
}

class _MatchReportPageState extends State<MatchReportPage> {
  _ReportView _view = const _ReportLoading();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _view = const _ReportLoading());
    final scope = AppScope.of(context);
    try {
      final match = await scope.database.getMatch(widget.matchId);
      final path = await resolveMatchReadPath(
        boundary: scope.matchApplication,
        legacyMatch: match,
        matchId: widget.matchId,
      );
      if (!mounted) return;
      if (path != MatchReadPath.matchMemory) {
        setState(() => _view = _ReportClosed(path));
        return;
      }
      if (match == null) {
        setState(() => _view = const _ReportClosed(MatchReadPath.unavailable));
        return;
      }
      final boundary = scope.matchApplication;
      final identity = scope.captureIdentity;
      if (boundary == null || identity == null) {
        setState(() => _view = const _ReportClosed(MatchReadPath.unknown));
        return;
      }
      final report = await boundary.readMatchReport(
        matchId: widget.matchId,
        evaluatedAuthorityGeneration:
            PhoneCaptureIdentity.initialAuthorityGeneration,
        homeTeamId: MatchTeamId(match.teams.home.teamId),
        awayTeamId: MatchTeamId(match.teams.away.teamId),
      );
      if (!mounted) return;
      if (report.readiness != MatchReportReadiness.readable) {
        setState(() => _view = const _ReportClosed(MatchReadPath.unavailable));
        return;
      }
      setState(() => _view = _ReportReady(match: match, report: report));
    } catch (_) {
      if (!mounted) return;
      setState(() => _view = const _ReportFailed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RepaintBoundary(
      key: const Key('match-report-capture'),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.matchReport),
          leading: IconButton(
            tooltip: l10n.back,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              onPressed: _load,
              child: Text(l10n.matchReportRefresh),
            ),
            Expanded(
              child: switch (_view) {
                _ReportLoading() => const Center(
                    key: Key('match-report-loading'),
                    child: CircularProgressIndicator(),
                  ),
                _ReportFailed() => _ClosedBody(
                    message: l10n.matchReportReadFailed,
                    actionLabel: l10n.matchReportRetry,
                    onAction: _load,
                  ),
                _ReportClosed(:final path) => _closedBody(l10n, path),
                _ReportReady(:final match, :final report) => _ReadyBody(
                    match: match, report: report, matchId: widget.matchId),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _closedBody(AppLocalizations l10n, MatchReadPath path) {
    return switch (path) {
      MatchReadPath.legacyOnly => _ClosedBody(
          message: l10n.matchReportLegacyOnly,
          actionLabel: l10n.matchReportOpenSummary,
          onAction: () => Navigator.of(context).pushNamed(
            AppRouter.matchSummary,
            arguments: widget.matchId,
          ),
        ),
      MatchReadPath.unknown => _ClosedBody(message: l10n.matchReportUnknown),
      MatchReadPath.ambiguous =>
        _ClosedBody(message: l10n.matchReportAmbiguous),
      MatchReadPath.unavailable => _ClosedBody(
          message: l10n.matchReportUnreadable,
          actionLabel: l10n.matchReportRetry,
          onAction: _load,
        ),
      MatchReadPath.matchMemory =>
        _ClosedBody(message: l10n.matchReportUnknown),
    };
  }
}

class _ClosedBody extends StatelessWidget {
  const _ClosedBody({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.match,
    required this.report,
    required this.matchId,
  });

  final Match match;
  final MatchReportProjection report;
  final String matchId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final yellows = report.entries.whereType<YellowReportEntry>().length;
    final sendOffs = report.entries.whereType<SendOffReportEntry>().length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.matchReportMatchId(matchId),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(homeLabel(match, l10n)),
          Text(awayLabel(match, l10n)),
          Text(
            l10n.matchReportLabelsAreNotProof,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _scoreLine(context, l10n),
          const SizedBox(height: 8),
          for (final facet in report.facets)
            Text(
              l10n.matchReportFacetLine(
                _facetLabel(facet.facetId, l10n),
                _classificationLabel(facet.classification, l10n),
              ),
            ),
          for (final id in report.unsupportedRecordIds)
            Text(l10n.matchReportUnsupported(id)),
          if (report.entries.isEmpty && report.unsupportedRecordIds.isEmpty)
            Text(l10n.matchReportNoLines),
          if (yellows >= 2 && sendOffs == 0)
            Text(l10n.matchReportTwoYellowsAreNotSendOff),
          const SizedBox(height: 8),
          for (final entry in report.entries)
            _EntryTile(match: match, entry: entry),
        ],
      ),
    );
  }

  Widget _scoreLine(BuildContext context, AppLocalizations l10n) {
    final score = report.score;
    final style = Theme.of(context).textTheme.headlineMedium;
    return switch (score) {
      KnownScore() => _knownScore(l10n, score, style),
      ScoreConflicted() => Text(l10n.matchReportScoreConflict, style: style),
      ScoreUnavailable() =>
        Text(l10n.matchReportScoreUnavailable, style: style),
    };
  }

  Widget _knownScore(
    AppLocalizations l10n,
    KnownScore score,
    TextStyle? style,
  ) {
    final home = score.goalsByTeam[MatchTeamId(match.teams.home.teamId)];
    final away = score.goalsByTeam[MatchTeamId(match.teams.away.teamId)];
    if (home == null || away == null) {
      return Text(l10n.matchReportScoreUnavailable, style: style);
    }
    return Text(
      l10n.scoreLine(
          homeLabel(match, l10n), home, away, awayLabel(match, l10n)),
      style: style,
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.match, required this.entry});

  final Match match;
  final MatchReportEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeLabel = switch (entry.timeFact) {
      MatchReportTimeFact.exactMatchTimeUnavailable =>
        l10n.matchReportTimeUnavailable,
    };
    final kind = _kindLabel(entry, l10n);
    final classification = _classificationLabel(entry.classification, l10n);
    return Semantics(
      container: true,
      label: '$kind, $classification, $timeLabel',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kind, key: ValueKey('report-line-${entry.recordId}')),
            Text(classification),
            Text(timeLabel),
            ..._details(l10n),
            Text(
              l10n.matchReportRecord(entry.recordId),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(AppLocalizations l10n) {
    final entry = this.entry;
    return switch (entry) {
      GoalReportEntry() => [
          Text(_teamLabel(entry.scoringTeamId.value, l10n)),
        ],
      YellowReportEntry() => [
          Text(l10n.matchReportSubject),
        ],
      SendOffReportEntry() => [
          Text(l10n.matchReportSubject),
          Text(
            entry.pathway == SendOffPathway.direct
                ? l10n.matchReportDirect
                : l10n.matchReportSecondCaution,
          ),
          Text(_dependencyLabel(entry.dependencyStatus, l10n)),
          Text(
            entry.legallyEffective
                ? l10n.matchReportLegallyEffective
                : l10n.matchReportNotLegallyEffective,
          ),
        ],
      SubstitutionReportEntry() => [
          Text(l10n.matchReportSubject),
          Text(_teamLabel(entry.teamId.value, l10n)),
          Text(
            entry.legallyEffective
                ? l10n.matchReportLegallyEffective
                : l10n.matchReportNotLegallyEffective,
          ),
        ],
      TemporalReportEntry() => const [],
    };
  }

  String _teamLabel(String teamId, AppLocalizations l10n) {
    if (teamId == match.teams.home.teamId) return homeLabel(match, l10n);
    if (teamId == match.teams.away.teamId) return awayLabel(match, l10n);
    return l10n.matchReportTeam;
  }
}

String _kindLabel(MatchReportEntry entry, AppLocalizations l10n) {
  return switch (entry) {
    GoalReportEntry() => l10n.goal,
    YellowReportEntry() => l10n.matchReportYellowCard,
    SendOffReportEntry() => l10n.matchReportSendOff,
    SubstitutionReportEntry() => l10n.matchReportSubstitution,
    TemporalReportEntry() => _temporalLabel(entry, l10n),
  };
}

String _temporalLabel(TemporalReportEntry entry, AppLocalizations l10n) {
  final period = entry.period;
  return switch (entry.semanticType) {
    V1SemanticTypeCode.matchStarted => l10n.matchReportMatchStarted,
    V1SemanticTypeCode.periodStarted when period != null =>
      l10n.matchReportPeriodStarted(period.index),
    V1SemanticTypeCode.periodEnded when period != null =>
      l10n.matchReportPeriodEnded(period.index),
    V1SemanticTypeCode.temporarySuspensionStarted =>
      l10n.matchReportSuspensionStarted,
    V1SemanticTypeCode.temporarySuspensionEnded =>
      l10n.matchReportSuspensionEnded,
    V1SemanticTypeCode.matchAbandoned => l10n.matchReportMatchAbandoned,
    V1SemanticTypeCode.matchEnded => l10n.matchReportMatchEnded,
    V1SemanticTypeCode.temporalCorrection => l10n.matchReportTemporalCorrection,
    V1SemanticTypeCode.refereeEnteredFieldForMatchStart =>
      l10n.matchReportRefereeEntered,
    _ => l10n.matchReportTemporal,
  };
}

String _classificationLabel(
  MatchReportClassification classification,
  AppLocalizations l10n,
) {
  return switch (classification) {
    MatchReportClassification.known => l10n.matchReportClassificationKnown,
    MatchReportClassification.conflict =>
      l10n.matchReportClassificationConflict,
    MatchReportClassification.unavailable =>
      l10n.matchReportClassificationUnavailable,
    MatchReportClassification.unverified =>
      l10n.matchReportClassificationUnverified,
    MatchReportClassification.incomplete =>
      l10n.matchReportClassificationIncomplete,
  };
}

String _facetLabel(MatchReportFacetId facetId, AppLocalizations l10n) {
  return switch (facetId) {
    MatchReportFacetId.score => l10n.matchReportFacetScore,
    MatchReportFacetId.temporal => l10n.matchReportFacetTemporal,
    MatchReportFacetId.goal => l10n.matchReportFacetGoal,
    MatchReportFacetId.yellow => l10n.matchReportFacetYellow,
    MatchReportFacetId.sendOff => l10n.matchReportFacetSendOff,
    MatchReportFacetId.substitution => l10n.matchReportFacetSubstitution,
  };
}

String _dependencyLabel(
  SendOffDependencyStatus status,
  AppLocalizations l10n,
) {
  return switch (status) {
    SendOffDependencyStatus.ready => l10n.matchReportDependencyReady,
    SendOffDependencyStatus.unavailable =>
      l10n.matchReportDependencyUnavailable,
    SendOffDependencyStatus.conflicted => l10n.matchReportDependencyConflict,
  };
}

sealed class _ReportView {
  const _ReportView();
}

final class _ReportLoading extends _ReportView {
  const _ReportLoading();
}

final class _ReportFailed extends _ReportView {
  const _ReportFailed();
}

final class _ReportClosed extends _ReportView {
  const _ReportClosed(this.path);

  final MatchReadPath path;
}

final class _ReportReady extends _ReportView {
  const _ReportReady({required this.match, required this.report});

  final Match match;
  final MatchReportProjection report;
}
