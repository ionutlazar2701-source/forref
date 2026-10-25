import 'dart:async';

import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/design/forref_components.dart';
import 'package:referee_phone/design/forref_spacing.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/routing/app_router.dart';
import 'package:referee_phone/training/training_match_gate.dart';
import 'package:referee_phone/training/training_session.dart';
import 'package:referee_phone/training/training_store.dart';

class TrainingListPage extends StatefulWidget {
  const TrainingListPage({super.key});

  @override
  State<TrainingListPage> createState() => _TrainingListPageState();
}

class _TrainingListPageState extends State<TrainingListPage> {
  TrainingLedger? _ledger;
  TrainingStartDenial? _denial;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    final store = AppScope.of(context).training;
    if (store == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ledger = null;
      });
      return;
    }
    final ledger = await store.load();
    if (!mounted) return;
    setState(() {
      _ledger = ledger;
      _loading = false;
    });
  }

  Future<void> _start() async {
    final scope = AppScope.of(context);
    final store = scope.training;
    if (store == null) return;
    try {
      final ledger = await store.load();
      final denial = ledger.unreadable
          ? TrainingStartDenial.ledgerUnreadable
          : await trainingMatchDenial(
              database: scope.database,
              boundary: scope.matchApplication,
              today: DateTime.now(),
              anotherSessionOpen: ledger.openSession != null,
            );
      if (!mounted) return;
      if (denial != null) {
        setState(() => _denial = denial);
        return;
      }
      final result = await store.startGeneral();
      if (!mounted) return;
      switch (result) {
        case TrainingStarted(:final session):
        case TrainingAlreadyPresent(:final session):
          await Navigator.of(context).pushNamed(
            AppRouter.trainingSession,
            arguments: session.id,
          );
        case TrainingStartBlocked(:final denial):
          setState(() => _denial = denial);
          return;
      }
      await _reload();
      if (mounted) setState(() => _denial = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _denial = TrainingStartDenial.ledgerUnreadable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = AppScope.of(context).training;
    final ledger = _ledger;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainingTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : store == null || ledger == null || ledger.unreadable
              ? Padding(
                  padding: const EdgeInsets.all(ForrefSpace.s20),
                  child: ForrefNotice(
                    title: l10n.trainingUnavailable,
                    tone: ForrefNoticeTone.unavailable,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: ForrefSpace.s24),
                  children: [
                    if (_denial != null)
                      Padding(
                        padding: const EdgeInsets.all(ForrefSpace.s20),
                        child: ForrefNotice(
                          title: _denialLabel(l10n, _denial!),
                          titleKey: const Key('training-denial'),
                          tone: ForrefNoticeTone.attention,
                        ),
                      ),
                    if (ledger.sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ForrefSpace.s20,
                          vertical: ForrefSpace.s24,
                        ),
                        child: Text(
                          l10n.trainingEmpty,
                          key: const Key('training-empty'),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final session in _newestFirst(ledger.sessions))
                      ListTile(
                        key: Key('training-session-${session.id}'),
                        title: Text(_sessionTitle(l10n, session)),
                        subtitle: Text(
                          _sessionSubtitle(
                            l10n,
                            session,
                            AppScope.of(context).training?.clock() ??
                                DateTime.now(),
                          ),
                        ),
                        onTap: () async {
                          await Navigator.of(context).pushNamed(
                            AppRouter.trainingSession,
                            arguments: session.id,
                          );
                          await _reload();
                        },
                      ),
                  ],
                ),
      bottomNavigationBar: ForrefBottomAction(
        buttonKey: const Key('training-start'),
        label: l10n.startTraining,
        onPressed:
            store == null || (ledger?.unreadable ?? false) ? null : _start,
      ),
    );
  }
}

List<TrainingSession> _newestFirst(List<TrainingSession> sessions) {
  final copy = [...sessions];
  copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return copy;
}

String _sessionTitle(AppLocalizations l10n, TrainingSession session) {
  final title = session.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  return session.kind == TrainingKind.preMatchWarmUp
      ? l10n.trainingKindWarmUp
      : l10n.trainingKindGeneral;
}

String _sessionSubtitle(
  AppLocalizations l10n,
  TrainingSession session,
  DateTime now,
) {
  final facts = trainingFacts(session, now.toUtc());
  final elapsed = facts.elapsed.known
      ? formatTrainingDuration(facts.elapsed.duration!)
      : l10n.trainingElapsedUnknown;
  return '${_phaseLabel(l10n, facts.phase)} · $elapsed';
}

String _phaseLabel(AppLocalizations l10n, TrainingPhase phase) {
  return switch (phase) {
    TrainingPhase.notStarted => l10n.trainingNotStarted,
    TrainingPhase.active => l10n.trainingActive,
    TrainingPhase.paused => l10n.trainingPaused,
    TrainingPhase.finished => l10n.trainingFinished,
  };
}

String _denialLabel(AppLocalizations l10n, TrainingStartDenial denial) {
  return switch (denial) {
    TrainingStartDenial.anotherSessionOpen => l10n.trainingBlockedAnother,
    TrainingStartDenial.matchInProgress => l10n.trainingBlockedMatchOpen,
    TrainingStartDenial.matchStateUnverified =>
      l10n.trainingBlockedMatchUnverified,
    TrainingStartDenial.ledgerUnreadable => l10n.trainingUnavailable,
  };
}
