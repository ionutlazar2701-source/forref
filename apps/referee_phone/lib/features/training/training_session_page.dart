import 'dart:async';

import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/design/forref_components.dart';
import 'package:referee_phone/design/forref_spacing.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/training/training_session.dart';

/// Active session and, once finished, the same page as training analysis.
class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  TrainingSession? _session;
  bool _missing = false;
  Timer? _tick;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload(syncNote: true));
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _note.dispose();
    super.dispose();
  }

  Future<void> _reload({bool syncNote = false}) async {
    final store = AppScope.of(context).training;
    if (store == null) {
      if (!mounted) return;
      setState(() => _missing = true);
      return;
    }
    final session = await store.session(widget.sessionId);
    if (!mounted) return;
    if (session == null) {
      setState(() => _missing = true);
      return;
    }
    if (syncNote && _note.text != (session.note ?? '')) {
      _note.text = session.note ?? '';
    }
    setState(() => _session = session);
  }

  Future<void> _pause() async {
    await AppScope.of(context).training?.pause(widget.sessionId);
    await _reload();
  }

  Future<void> _resume() async {
    await AppScope.of(context).training?.resume(widget.sessionId);
    await _reload();
  }

  Future<void> _finish() async {
    final store = AppScope.of(context).training;
    await store?.updateNote(widget.sessionId, _note.text.trim());
    await store?.finish(widget.sessionId);
    await _reload();
  }

  Future<void> _saveNote() async {
    await AppScope.of(context)
        .training
        ?.updateNote(widget.sessionId, _note.text.trim());
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trainingTitle)),
        body: Padding(
          padding: const EdgeInsets.all(ForrefSpace.s20),
          child: ForrefNotice(
            title: l10n.trainingUnavailable,
            tone: ForrefNoticeTone.unavailable,
          ),
        ),
      );
    }
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.trainingTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final now = AppScope.of(context).training?.clock() ?? DateTime.now();
    final facts = trainingFacts(session, now.toUtc());
    final elapsed = facts.elapsed.known
        ? formatTrainingDuration(facts.elapsed.duration!)
        : l10n.trainingElapsedUnknown;
    final finished = facts.phase == TrainingPhase.finished;
    final title = session.title?.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(finished ? l10n.trainingAnalysis : l10n.trainingTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ForrefSpace.s20),
        children: [
          ForrefFixtureIdentity(
            title: title == null || title.isEmpty
                ? (session.kind == TrainingKind.preMatchWarmUp
                    ? l10n.trainingKindWarmUp
                    : l10n.trainingKindGeneral)
                : title,
            detail: _phaseLabel(l10n, facts.phase),
          ),
          const SizedBox(height: ForrefSpace.s16),
          ForrefNotice(
            title: l10n.trainingDuration,
            titleKey: const Key('training-elapsed'),
            lines: [elapsed],
            tone: facts.elapsed.known
                ? ForrefNoticeTone.neutral
                : ForrefNoticeTone.unavailable,
          ),
          const SizedBox(height: ForrefSpace.s12),
          Text(
            l10n.trainingPauseCount(facts.pauseCount),
            key: const Key('training-pause-count'),
          ),
          const SizedBox(height: ForrefSpace.s12),
          Text(
            session.linkedMatchId == null
                ? l10n.trainingNoLinkedMatch
                : '${l10n.trainingLinkedMatch}: ${session.linkedMatchId}',
            key: const Key('training-linked-match'),
          ),
          const SizedBox(height: ForrefSpace.s16),
          TextField(
            key: const Key('training-note'),
            controller: _note,
            decoration: InputDecoration(labelText: l10n.trainingNote),
            onEditingComplete: _saveNote,
          ),
          if (!finished) ...[
            const SizedBox(height: ForrefSpace.s16),
            if (facts.phase == TrainingPhase.active)
              TextButton(
                key: const Key('training-pause'),
                onPressed: _pause,
                child: Text(l10n.trainingPause),
              ),
            if (facts.phase == TrainingPhase.paused)
              TextButton(
                key: const Key('training-resume'),
                onPressed: _resume,
                child: Text(l10n.trainingResume),
              ),
          ],
        ],
      ),
      bottomNavigationBar: finished
          ? null
          : ForrefBottomAction(
              buttonKey: const Key('training-finish'),
              label: l10n.trainingFinish,
              onPressed: _finish,
            ),
    );
  }
}

String _phaseLabel(AppLocalizations l10n, TrainingPhase phase) {
  return switch (phase) {
    TrainingPhase.notStarted => l10n.trainingNotStarted,
    TrainingPhase.active => l10n.trainingActive,
    TrainingPhase.paused => l10n.trainingPaused,
    TrainingPhase.finished => l10n.trainingFinished,
  };
}
