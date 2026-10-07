import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/features/live_match/yellow_card_read_surface.dart';
import 'package:referee_phone/features/match_summary/match_summary_read_surface.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/match/match_session.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/routing/app_router.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';

class MatchSummaryPage extends StatefulWidget {
  const MatchSummaryPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchSummaryPage> createState() => _MatchSummaryPageState();
}

class _MatchSummaryPageState extends State<MatchSummaryPage> {
  MatchSession? _session;
  GoalMatchProjection _goalProjection = GoalMatchProjection.empty;
  DisciplinaryMatchProjection? _disciplinaryProjection;
  ParticipantIdentityProjection _participantIdentities =
      ParticipantIdentityProjection.empty;
  List<MatchRecord> _records = const [];
  List<TemporalEvidence> _recordedEvidence = const [];
  List<PhoneParticipantRegistryEntry> _registryEntries = const [];
  bool _authorityReady = false;

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
    await _refreshAuthority();
  }

  Future<void> _refreshAuthority() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    if (boundary == null || identity == null) {
      if (mounted) setState(() => _authorityReady = true);
      return;
    }
    final records = await boundary.durableStore.readCommittedForMatch(
      widget.matchId,
    );
    final captureContext = await scope.matchCaptureContext
            ?.captureContextFor(widget.matchId) ??
        identity.contextFor(widget.matchId);
    final registryEntries =
        await scope.participantRegistry?.loadForMatch(widget.matchId) ??
            const [];
    final evidenceStore = scope.temporalEvidence;
    final recordedEvidence = await _resolveRecordedEvidence(
      evidenceStore,
      records,
    );
    final goalProjection = GoalMatchProjection.derive(
      records: records,
      evidence: recordedEvidence,
    );
    final disciplinaryProjection = DisciplinaryMatchProjection.derive(
      records: records,
      evaluatedAuthorityGeneration: captureContext.projectionAuthorityGeneration,
      competitionRules: captureContext.competitionRulesContext,
    );
    final participantIdentities =
        ParticipantIdentityProjection.derive(records: records);
    if (!mounted) return;
    setState(() {
      _records = records;
      _recordedEvidence = recordedEvidence;
      _goalProjection = goalProjection;
      _disciplinaryProjection = disciplinaryProjection;
      _participantIdentities = participantIdentities;
      _registryEntries = registryEntries;
      _authorityReady = true;
    });
  }

  Future<List<TemporalEvidence>> _resolveRecordedEvidence(
    PhoneTemporalEvidenceStore? evidence,
    List<MatchRecord> records,
  ) async {
    if (evidence == null) return const [];
    final ids = <String>{};
    for (final record in records) {
      ids.addAll(record.temporalContext?.evidenceIds ?? const <String>[]);
    }
    final resolved = <TemporalEvidence>[];
    for (final id in ids) {
      final item = await evidence.resolve(id);
      if (item != null) resolved.add(item);
    }
    return resolved;
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
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    if (session == null || !_authorityReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final match = session.match;
    final disciplinary = _disciplinaryProjection;
    final yellowPolicy = disciplinary == null
        ? LegacyYellowDataPolicy.authorityOnly
        : legacyYellowDataPolicy(
            legacyEvents: match.events,
            disciplinary: disciplinary,
          );
    final yellowPolicyNotice = legacyYellowPolicyNotice(yellowPolicy, l10n);
    final summaryRows = disciplinary == null
        ? [
            for (final event in match.events.reversed)
              MatchSummaryRow(
                kind: MatchSummaryRowKind.legacyEvent,
                sortKey: 0,
                title:
                    '${formatMatchClock(event.matchTime)}  ${eventTypeLabel(event.type, l10n)}'
                    '${event.status == EventStatus.incomplete ? ' · ${l10n.incomplete}' : ''}',
                subtitle: event.data.teamId == null
                    ? ''
                    : teamLabel(match, event.data.teamId!, l10n),
              ),
          ]
        : buildMatchSummaryRows(
            match: match,
            goalProjection: _goalProjection,
            disciplinary: disciplinary,
            identities: _participantIdentities,
            records: _records,
            evidenceById: temporalEvidenceById(_recordedEvidence),
            l10n: l10n,
            registryEntries: _registryEntries,
          );
    final boundaryAvailable = AppScope.of(context).matchApplication != null;
    final homeScore =
        boundaryAvailable ? _goalProjection.homeScore : match.score.home;
    final awayScore =
        boundaryAvailable ? _goalProjection.awayScore : match.score.away;

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
          if (yellowPolicyNotice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              yellowPolicyNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          for (final row in summaryRows)
            ListTile(
              key: row.kind == MatchSummaryRowKind.yellowAuthority
                  ? Key('summary-yellow-${row.title}')
                  : null,
              title: Text(row.title),
              subtitle: row.subtitle.isEmpty ? null : Text(row.subtitle),
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
