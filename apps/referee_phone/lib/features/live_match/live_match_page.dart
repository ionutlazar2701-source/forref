import 'dart:async';

import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/features/live_match/capture_overlay.dart';
import 'package:referee_phone/features/live_match/goal_time_label.dart';
import 'package:referee_phone/features/live_match/live_match_terminal_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/match/match_session.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/match_application/kick_off_authority.dart';
import 'package:referee_phone/match_application/match_started_read_model.dart';
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
  bool _kickOffPending = false;
  bool _suspensionPending = false;
  bool _resumePending = false;
  bool _periodEndPending = false;
  bool _nextPeriodPending = false;
  bool _matchEndPending = false;
  bool _matchStarted = false;
  NormalMatchEndEligibility? _terminalEligibility;
  PeriodIdentity? _activePeriod;
  PeriodIdentity? _endedPeriod;
  bool _intervalActive = false;
  bool _temporallyIncomplete = false;
  ActivePeriodElapsedProjection _elapsed =
      ActivePeriodElapsedProjection.unavailable;
  TemporalMatchProjection _temporal = TemporalMatchProjection.empty;
  MatchProjectionState? _projection;
  List<MatchRecord> _records = const [];
  TemporalEvidence? _anchor;
  TemporalEvidence? _suspensionBoundary;
  TemporalEvidence? _resumptionAnchor;
  List<TemporalEvidence> _recordedEvidence = const [];
  GoalMatchProjection _goalProjection = GoalMatchProjection.empty;
  Timer? _clockTicker;
  EventType? _captureType;
  bool _goalSideChoice = false;
  bool _goalPending = false;
  bool _goalCommitInFlight = false;
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
    await _refreshTemporal();
  }

  Future<CaptureContext?> _captureContext(AppScope scope) async {
    final matchCapture = scope.matchCaptureContext;
    if (matchCapture != null) {
      return matchCapture.captureContextFor(widget.matchId);
    }
    final identity = scope.captureIdentity;
    if (identity == null) return null;
    return identity.contextFor(widget.matchId);
  }

  Future<void> _refreshTemporal() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    if (boundary == null || identity == null) return;
    final projection = await boundary.project(
      widget.matchId,
      evaluatedAuthorityGeneration:
          identity.contextFor(widget.matchId).projectionAuthorityGeneration,
    );
    final records = await boundary.durableStore.readCommittedForMatch(
      widget.matchId,
    );
    final started = MatchStartedReadModel.from(
      projection: projection,
      records: records,
    );
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    final evidence = scope.temporalEvidence;
    final anchorId = _periodAnchorId(records, temporal.activePeriod);
    final anchor = evidence == null || anchorId == null
        ? null
        : await evidence.resolve(anchorId);
    final suspensionId = _suspensionEvidenceId(records, temporal.activePeriod);
    final suspensionBoundary = evidence == null || suspensionId == null
        ? null
        : await evidence.resolve(suspensionId);
    final resumptionId = _resumptionEvidenceId(records, temporal.activePeriod);
    final resumptionAnchor = evidence == null || resumptionId == null
        ? null
        : await evidence.resolve(resumptionId);
    final recordedEvidence = await _resolveRecordedEvidence(evidence, records);
    final goalProjection = GoalMatchProjection.derive(
      records: records,
      evidence: recordedEvidence,
    );
    final current = evidence?.currentObservation();
    final elapsed = deriveActivePeriodElapsed(
      temporal: temporal,
      projection: projection,
      records: records,
      anchor: anchor,
      current: current,
      suspensionBoundary: suspensionBoundary,
      resumptionAnchor: resumptionAnchor,
      recordedEvidence: recordedEvidence,
    );
    NormalMatchEndEligibility? terminalEligibility;
    final matchCapture = scope.matchCaptureContext;
    if (matchCapture != null && started.authoritativelyStarted) {
      terminalEligibility = await assessStoredNormalMatchEndEligibility(
        capture: matchCapture,
        matchId: widget.matchId,
        records: records,
      );
    }
    if (!mounted) return;
    setState(() {
      _matchStarted = started.authoritativelyStarted;
      _activePeriod = started.activePeriod;
      _endedPeriod = temporal.endedPeriod;
      _intervalActive = temporal.intervalActive;
      _temporallyIncomplete = started.temporallyIncomplete;
      _elapsed = elapsed;
      _temporal = temporal;
      _projection = projection;
      _records = records;
      _anchor = anchor;
      _suspensionBoundary = suspensionBoundary;
      _resumptionAnchor = resumptionAnchor;
      _recordedEvidence = recordedEvidence;
      _goalProjection = goalProjection;
      _terminalEligibility = terminalEligibility;
    });
    _syncClockTicker();
  }

  void _syncClockTicker() {
    final ticking = _activePeriod != null &&
        _elapsed.precisionSafeToShow &&
        !_elapsed.formalSuspensionActive;
    if (ticking && _clockTicker == null) {
      _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        _onClockTick();
      });
    } else if (!ticking && _clockTicker != null) {
      _clockTicker!.cancel();
      _clockTicker = null;
    }
  }

  /// Recomputes the display clock from cached authority and the live sample.
  ///
  /// Does not commit a Match Record, does not persist elapsed seconds, and
  /// does not rebuild [GoalMatchProjection]. Goal history stays at the last
  /// D1 refresh.
  void _onClockTick() {
    final evidence = AppScope.of(context).temporalEvidence;
    final projection = _projection;
    if (!mounted || evidence == null || projection == null) return;
    setState(() {
      _elapsed = deriveActivePeriodElapsed(
        temporal: _temporal,
        projection: projection,
        records: _records,
        anchor: _anchor,
        current: evidence.currentObservation(),
        suspensionBoundary: _suspensionBoundary,
        resumptionAnchor: _resumptionAnchor,
        recordedEvidence: _recordedEvidence,
      );
    });
  }

  Future<void> _resumeMatch() async {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    final boundary = scope.matchApplication;
    final evidence = scope.temporalEvidence;
    final captureContext = await _captureContext(scope);
    if (!mounted) return;
    final period = _activePeriod;
    if (boundary == null ||
        captureContext == null ||
        evidence == null ||
        period == null ||
        _resumePending ||
        !_elapsed.formalSuspensionActive) {
      return;
    }
    final suspensionStartedRecordId = findFormalSuspensionStart(
      records: _records,
      activePeriod: period,
    ).record?.recordId;
    if (suspensionStartedRecordId == null) return;
    setState(() => _resumePending = true);
    final DurableCommitResult result;
    try {
      final captured = await evidence.captureAnchor();
      result = await boundary.commitTemporarySuspensionEnded(
        captureContext,
        period: period,
        suspensionStartedRecordId: suspensionStartedRecordId,
        temporalContext: TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _resumePending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resumeNotSaved)),
      );
      return;
    }
    if (!mounted) return;
    if (result is! DurableCommitSuccess) {
      setState(() => _resumePending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resumeNotSaved)),
      );
      return;
    }
    await _refreshTemporal();
    if (!mounted) return;
    setState(() => _resumePending = false);
  }

  Future<void> _endPeriod() async {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    final boundary = scope.matchApplication;
    final evidence = scope.temporalEvidence;
    final captureContext = await _captureContext(scope);
    if (!mounted) return;
    final period = _activePeriod;
    if (boundary == null ||
        captureContext == null ||
        evidence == null ||
        period == null ||
        _periodEndPending ||
        _elapsed.formalSuspensionActive) {
      return;
    }
    final periodStartedRecordId = _periodStartRecordId(_records, period);
    if (periodStartedRecordId == null) return;
    setState(() => _periodEndPending = true);
    final DurableCommitResult result;
    try {
      final captured = await evidence.captureAnchor();
      result = await boundary.commitPeriodEnded(
        captureContext,
        period: period,
        periodStartedRecordId: periodStartedRecordId,
        temporalContext: TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _periodEndPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.periodEndNotSaved)),
      );
      return;
    }
    if (!mounted) return;
    if (result is! DurableCommitSuccess) {
      setState(() => _periodEndPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.periodEndNotSaved)),
      );
      return;
    }
    await _refreshTemporal();
    if (!mounted) return;
    setState(() => _periodEndPending = false);
  }

  Future<void> _startPeriod2() async {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    final boundary = scope.matchApplication;
    final evidence = scope.temporalEvidence;
    final captureContext = await _captureContext(scope);
    if (!mounted) return;
    if (boundary == null ||
        captureContext == null ||
        evidence == null ||
        _nextPeriodPending ||
        !_intervalActive ||
        _activePeriod != null) {
      return;
    }
    final periodEndedRecordId = findPeriodEnd(
      records: _records,
      period: const PeriodIdentity(index: 1),
    ).record?.recordId;
    if (periodEndedRecordId == null) return;
    setState(() => _nextPeriodPending = true);
    final DurableCommitResult result;
    try {
      final captured = await evidence.captureAnchor();
      result = await boundary.commitNextPeriodStarted(
        captureContext,
        period: const PeriodIdentity(index: 2),
        periodEndedRecordId: periodEndedRecordId,
        temporalContext: TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _nextPeriodPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.periodStartNotSaved)),
      );
      return;
    }
    if (!mounted) return;
    if (result is! DurableCommitSuccess) {
      setState(() => _nextPeriodPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.periodStartNotSaved)),
      );
      return;
    }
    await _refreshTemporal();
    if (!mounted) return;
    setState(() => _nextPeriodPending = false);
  }

  Future<void> _suspendMatch() async {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    final boundary = scope.matchApplication;
    final evidence = scope.temporalEvidence;
    final captureContext = await _captureContext(scope);
    if (!mounted) return;
    final period = _activePeriod;
    if (boundary == null ||
        captureContext == null ||
        evidence == null ||
        period == null ||
        _suspensionPending ||
        _elapsed.formalSuspensionActive) {
      return;
    }
    final periodStartedRecordId = _periodStartRecordId(_records, period);
    if (periodStartedRecordId == null) return;
    setState(() => _suspensionPending = true);
    final DurableCommitResult result;
    try {
      final captured = await evidence.captureAnchor();
      result = await boundary.commitTemporarySuspensionStarted(
        captureContext,
        period: period,
        periodStartedRecordId: periodStartedRecordId,
        temporalContext: TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _suspensionPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.suspensionNotSaved)),
      );
      return;
    }
    if (!mounted) return;
    if (result is! DurableCommitSuccess) {
      setState(() => _suspensionPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.suspensionNotSaved)),
      );
      return;
    }
    await _refreshTemporal();
    if (!mounted) return;
    setState(() => _suspensionPending = false);
  }

  Future<void> _endMatch() async {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    final boundary = scope.matchApplication;
    final captureContext = await _captureContext(scope);
    if (!mounted) return;
    if (boundary == null ||
        captureContext == null ||
        _matchEndPending ||
        _temporal.matchNormallyEnded ||
        _terminalEligibility != NormalMatchEndEligibility.eligible) {
      return;
    }
    final finalEnd = finalCompletedPeriodEnd(records: _records);
    if (finalEnd == null) return;
    setState(() => _matchEndPending = true);
    try {
      final result = await boundary.commitMatchEnded(
        captureContext,
        periodEndedRecordId: finalEnd.recordId,
      );
      if (!mounted) return;
      if (result is! DurableCommitSuccess) {
        setState(() => _matchEndPending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.matchEndNotSaved)),
        );
        return;
      }
      await _refreshTemporal();
      if (!mounted) return;
      setState(() => _matchEndPending = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _matchEndPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.matchEndNotSaved)),
      );
    }
  }

  Future<void> _kickOff() async {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    final boundary = scope.matchApplication;
    final captureContext = await _captureContext(scope);
    if (!mounted) return;
    if (boundary == null ||
        captureContext == null ||
        _kickOffPending ||
        _activePeriod != null) {
      return;
    }
    setState(() => _kickOffPending = true);
    try {
      final evidence = scope.temporalEvidence;
      final result = await boundary.commitKickOff(
        captureContext,
        period: const PeriodIdentity(index: 1),
        periodAnchor: evidence == null
            ? null
            : () async {
                final captured = await evidence.captureAnchor();
                return TemporalContext(
                  evidenceIds: [captured.evidenceId],
                  domainClockPolicyVersion:
                      PhoneCaptureIdentity.domainClockContract.value,
                );
              },
      );
      if (!mounted) return;
      if (result is KickOffAuthorityRejected) {
        setState(() => _kickOffPending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.kickOffNotSaved)),
        );
        return;
      }
      await _refreshTemporal();
      if (!mounted) return;
      setState(() => _kickOffPending = false);
      if (result is KickOffMatchStartedIncomplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.periodStartNotSaved)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _kickOffPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.kickOffNotSaved)),
      );
    }
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _session?.dispose();
    super.dispose();
  }

  String _cutOverClockLabel(AppLocalizations l10n) {
    final elapsed = _elapsed;
    if (elapsed.precisionSafeToShow && elapsed.exactElapsed != null) {
      return formatMatchClock(elapsed.exactElapsed!.inSeconds);
    }
    if (elapsed.continuity == TemporalContinuityStatus.boundedContinuity &&
        elapsed.elapsedLowerBound != null &&
        elapsed.elapsedUpperBound != null) {
      return '${formatMatchClock(elapsed.elapsedLowerBound!.inSeconds)}–'
          '${formatMatchClock(elapsed.elapsedUpperBound!.inSeconds)}';
    }
    return l10n.elapsedUnavailable;
  }

  String _continuityLabel(AppLocalizations l10n) {
    return switch (_elapsed.continuity) {
      TemporalContinuityStatus.exactContinuity => l10n.continuityExact,
      TemporalContinuityStatus.boundedContinuity => l10n.continuityBounded,
      TemporalContinuityStatus.continuityUnresolved => l10n.elapsedUnavailable,
    };
  }

  void _openGoalSideChoice() {
    if (_goalPending || _goalSideChoice || _goalCommitInFlight) return;
    final now = DateTime.now();
    if (_lastActionType == EventType.goal &&
        _lastActionAt != null &&
        now.difference(_lastActionAt!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastActionAt = now;
    _lastActionType = EventType.goal;
    setState(() {
      _captureType = null;
      _goalSideChoice = true;
    });
  }

  void _showGoalFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _commitGoal(CreditedSide side) async {
    if (_goalCommitInFlight) return;
    _goalCommitInFlight = true;
    final intentId = const Uuid().v4();
    final l10n = AppLocalizations.of(context);
    setState(() => _goalPending = true);
    try {
      final scope = AppScope.of(context);
      final boundary = scope.matchApplication;
      final evidence = scope.temporalEvidence;
      final captureContext = await _captureContext(scope);
      if (!mounted) return;
      if (boundary == null || captureContext == null || evidence == null) {
        setState(() => _goalPending = false);
        _showGoalFeedback(l10n.goalNotSaved);
        return;
      }
      final captured = await evidence.captureAnchor();
      final result = await boundary.commitGoal(
        captureContext,
        creditedSide: side,
        captureIntentId: intentId,
        temporalContext: TemporalContext(
          evidenceIds: [captured.evidenceId],
          domainClockPolicyVersion:
              PhoneCaptureIdentity.domainClockContract.value,
        ),
      );
      if (!mounted) return;
      if (result is! DurableCommitSuccess) {
        setState(() => _goalPending = false);
        _showGoalFeedback(l10n.goalNotSaved);
        return;
      }
      await _refreshTemporal();
      if (!mounted) return;
      setState(() {
        _goalPending = false;
        _goalSideChoice = false;
        _lastActionAt = null;
      });
      _showGoalFeedback(l10n.goalSaved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _goalPending = false);
      _showGoalFeedback(l10n.goalNotSaved);
    } finally {
      _goalCommitInFlight = false;
    }
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
    final cutOverClock = _activePeriod != null || _endedPeriod != null;
    final clock = cutOverClock
        ? _cutOverClockLabel(l10n)
        : formatMatchClock(session.displayedElapsed());
    final temporalLabel = _temporal.matchNormallyEnded
        ? l10n.matchEndedTerminal
        : _activePeriod != null
            ? l10n.activePeriodIndex(_activePeriod!.index)
            : _intervalActive
                ? l10n.interval
                : _endedPeriod != null
                    ? l10n.periodEnded(_endedPeriod!.index)
                    : _temporallyIncomplete
                        ? l10n.periodStartIncomplete
                        : '${periodLabel(match.currentState.periodId, l10n)}  ${matchStatusLabel(match, l10n)}';
    final terminalBlockedMessage = showTerminalBlockedReason(
          eligibility: _terminalEligibility,
          matchNormallyEnded: _temporal.matchNormallyEnded,
          matchStarted: _matchStarted,
        )
        ? terminalEligibilityMessage(l10n, _terminalEligibility!)
        : null;
    final legacyHalfTimeVisible = !_intervalActive &&
        _endedPeriod == null &&
        _activePeriod == null;
    final recent = match.events.reversed
        .where((event) => event.type != EventType.goal)
        .take(7)
        .toList();
    final recentGoals = _goalProjection.goals.reversed.take(7).toList();
    final boundaryAvailable =
        AppScope.of(context).matchApplication != null;
    final homeScore = boundaryAvailable
        ? _goalProjection.homeScore
        : match.score.home;
    final awayScore = boundaryAvailable
        ? _goalProjection.awayScore
        : match.score.away;

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
                '$clock  $temporalLabel',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (_intervalActive && _endedPeriod != null) ...[
                Text(l10n.periodEndedInterval(_endedPeriod!.index)),
                Text(l10n.noActivePlayingPeriod),
              ],
              if (_temporal.matchNormallyEnded) ...[
                Text(
                  l10n.matchEndedTerminal,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l10n.noActivePlayingPeriod),
              ] else if (_temporal.bothOrdinaryPeriodsEnded)
                Text(l10n.noActivePlayingPeriod),
              if (terminalBlockedMessage != null)
                Text(terminalBlockedMessage),
              if (cutOverClock &&
                  !_intervalActive &&
                  _elapsed.continuity !=
                      TemporalContinuityStatus.continuityUnresolved)
                Text(_continuityLabel(l10n)),
              if (_elapsed.formalSuspensionActive) ...[
                Text(l10n.matchSuspended),
                if (_elapsed.suspensionDurationOpen)
                  Text(l10n.suspensionOngoing),
              ],
              if (_activePeriod == null &&
                  _endedPeriod == null &&
                  addedMinutes > 0)
                Text(l10n.clockWithAdded(clock, addedMinutes)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (match.status == MatchStatus.ready &&
                      !_matchStarted &&
                      !_temporallyIncomplete)
                    FilledButton(
                      onPressed: _kickOffPending ? null : _kickOff,
                      child: Text(l10n.kickOff),
                    ),
                  if (_temporallyIncomplete)
                    FilledButton(
                      onPressed: _kickOffPending ? null : _kickOff,
                      child: Text(l10n.completePeriodStart),
                    ),
                  if (_matchStarted) Text(l10n.matchStarted),
                  if (_intervalActive)
                    FilledButton(
                      onPressed: _nextPeriodPending ? null : _startPeriod2,
                      child: Text(l10n.startPeriod2),
                    ),
                  if (_activePeriod != null &&
                      !_elapsed.formalSuspensionActive) ...[
                    FilledButton(
                      onPressed: _suspensionPending ? null : _suspendMatch,
                      child: Text(l10n.suspendMatch),
                    ),
                    FilledButton(
                      onPressed: _periodEndPending ? null : _endPeriod,
                      child: Text(l10n.endPeriod),
                    ),
                  ],
                  if (_elapsed.formalSuspensionActive)
                    FilledButton(
                      onPressed: _resumePending ? null : _resumeMatch,
                      child: Text(l10n.resumeMatch),
                    ),
                  if (showEndMatchAction(
                    eligibility: _terminalEligibility,
                    matchNormallyEnded: _temporal.matchNormallyEnded,
                    matchEndPending: _matchEndPending,
                  ))
                    FilledButton(
                      onPressed: _matchEndPending ? null : _endMatch,
                      child: Text(l10n.endMatch),
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
                  if (legacyHalfTimeVisible &&
                      (match.status == MatchStatus.live ||
                          match.status == MatchStatus.paused) &&
                      (match.currentState.periodId == PeriodId.firstHalf ||
                          match.currentState.periodId == PeriodId.extraTime1))
                    FilledButton.tonal(
                      onPressed: () => _onState(session.halfTime),
                      child: Text(l10n.halfTime),
                    ),
                  if (legacyHalfTimeVisible &&
                      match.status == MatchStatus.halfTime)
                    FilledButton(
                      onPressed: () => _onState(session.startSecondHalf),
                      child: Text(l10n.startSecondHalf),
                    ),
                  if (legacyHalfTimeVisible &&
                      (match.status == MatchStatus.live ||
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
              if (_activePeriod == null && _endedPeriod == null)
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
                  homeScore,
                  awayScore,
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
                        onPressed: type == EventType.goal
                            ? (_goalPending ? null : _openGoalSideChoice)
                            : () => _startCapture(type),
                        child: Text(eventTypeLabel(type, l10n)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              for (final goal in recentGoals)
                ListTile(
                  title: Text(
                    '${formatProjectedGoalTime(goal.temporal, l10n)}  ${l10n.goal}',
                  ),
                  subtitle: Text(
                    goal.creditedSide == CreditedSide.home
                        ? homeLabel(match, l10n)
                        : awayLabel(match, l10n),
                  ),
                ),
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
          if (_goalSideChoice)
            Positioned.fill(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.goal,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _goalPending
                                ? null
                                : () => setState(() => _goalSideChoice = false),
                            child: Text(l10n.back),
                          ),
                        ),
                        FilledButton(
                          onPressed: _goalPending
                              ? null
                              : () => _commitGoal(CreditedSide.home),
                          child: Text(homeLabel(match, l10n)),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _goalPending
                              ? null
                              : () => _commitGoal(CreditedSide.away),
                          child: Text(awayLabel(match, l10n)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_captureType != null && _captureType != EventType.goal)
            Positioned.fill(
              child: CaptureOverlay(
                match: match,
                type: _captureType!,
                onTypeChanged: (type) {
                  if (type == EventType.goal) {
                    setState(() {
                      _captureType = null;
                      _goalSideChoice = true;
                    });
                    return;
                  }
                  setState(() => _captureType = type);
                },
                onCancel: () => setState(() => _captureType = null),
                onSave: (type, data) async {
                  if (type == EventType.goal) {
                    setState(() {
                      _captureType = null;
                      _goalSideChoice = true;
                    });
                    return;
                  }
                  setState(() => _captureType = null);
                  await session.saveEvent(type: type, data: data);
                },
              ),
            ),
        ],
      ),
    );
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

  String? _periodStartRecordId(
    List<MatchRecord> records,
    PeriodIdentity period,
  ) {
    return anchoredPeriodStart(records, period)?.recordId;
  }

  String? _resumptionEvidenceId(
    List<MatchRecord> records,
    PeriodIdentity? period,
  ) {
    final ids = findFormalSuspensionStart(
          records: records,
          activePeriod: period,
        ).end?.temporalContext?.evidenceIds ??
        const <String>[];
    if (ids.isEmpty) return null;
    return ids.first;
  }

  String? _suspensionEvidenceId(
    List<MatchRecord> records,
    PeriodIdentity? period,
  ) {
    final ids = findFormalSuspensionStart(
          records: records,
          activePeriod: period,
        ).record?.temporalContext?.evidenceIds ??
        const <String>[];
    if (ids.isEmpty) return null;
    return ids.first;
  }

  String? _periodAnchorId(List<MatchRecord> records, PeriodIdentity? period) {
    if (period == null) return null;
    final ids =
        anchoredPeriodStart(records, period)?.temporalContext?.evidenceIds ??
            const <String>[];
    if (ids.isEmpty) return null;
    return ids.first;
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
