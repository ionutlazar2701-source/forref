import 'instrument.dart';
import 'model.dart';
import 'scenarios.dart';

/// A research command replayed through [ResearchInstrument] methods.
///
/// There is no step that inserts a saved record directly.
enum SemanticOp {
  offerYellow,
  offerDirectSendOff,
  tap,
  resolve,
  selectOut,
  selectIn,
  setTeamHome,
  setTeamAway,
  setScopeMatch,
  setScopeShootout,
  selectParticipant,
}

final class SemanticOpStep {
  const SemanticOpStep(
    this.op, {
    this.x = 0,
    this.y = 0,
    this.pointerId = 1,
    this.participantId,
  });

  final SemanticOp op;
  final double x;
  final double y;
  final int pointerId;
  final String? participantId;
}

ResearchInstrument replaySemanticSteps({
  required ScenarioId scenario,
  required List<SemanticOpStep> steps,
}) {
  final instrument = ResearchInstrument()..loadScenario(scenario);
  for (final step in steps) {
    switch (step.op) {
      case SemanticOp.offerYellow:
        instrument.offerRecordYellow();
      case SemanticOp.offerDirectSendOff:
        instrument.offerDirectSendOff();
      case SemanticOp.tap:
        instrument.pointerDown(
          pointerId: step.pointerId,
          x: step.x,
          y: step.y,
        );
        instrument.pointerUp(pointerId: step.pointerId, x: step.x, y: step.y);
      case SemanticOp.resolve:
        instrument.resolveSimulatedCommit();
      case SemanticOp.selectOut:
        instrument.selectOut(step.participantId ?? '');
      case SemanticOp.selectIn:
        instrument.selectIn(step.participantId ?? '');
      case SemanticOp.setTeamHome:
        instrument.setTeam(ResearchTeamSide.home);
      case SemanticOp.setTeamAway:
        instrument.setTeam(ResearchTeamSide.away);
      case SemanticOp.setScopeMatch:
        instrument.setScope(ResearchScope.match);
      case SemanticOp.setScopeShootout:
        instrument.setScope(ResearchScope.shootout);
      case SemanticOp.selectParticipant:
        instrument.selectParticipant(step.participantId ?? '');
    }
  }
  return instrument;
}

final class PointerTraceEvent {
  const PointerTraceEvent.down({
    required this.pointerId,
    required this.x,
    required this.y,
  })  : down = true,
        cancel = false;

  const PointerTraceEvent.up({
    required this.pointerId,
    required this.x,
    required this.y,
  })  : down = false,
        cancel = false;

  const PointerTraceEvent.cancel({required this.pointerId})
      : down = false,
        cancel = true,
        x = 0,
        y = 0;

  final int pointerId;
  final double x;
  final double y;
  final bool down;
  final bool cancel;
}

/// Pointer events bound to one profile and one layout-policy version.
final class PointerTrace {
  const PointerTrace({
    required this.profileId,
    required this.layoutPolicyVersion,
    required this.events,
  });

  final String profileId;
  final int layoutPolicyVersion;
  final List<PointerTraceEvent> events;
}

enum PointerReplayRefusal { none, profileMismatch, layoutMismatch }

final class PointerReplayResult {
  const PointerReplayResult(this.refusal);

  final PointerReplayRefusal refusal;
}

/// Replays pointer events through the instrument.
///
/// A different profile or layout version is refused. Refusal does not append
/// a record and does not resolve a commit.
PointerReplayResult replayPointerTrace({
  required ResearchInstrument instrument,
  required PointerTrace trace,
  required String activeProfileId,
  required int activeLayoutPolicyVersion,
}) {
  if (trace.profileId != activeProfileId) {
    instrument.noteInputRejected('pointer-replay-profile-mismatch');
    return const PointerReplayResult(PointerReplayRefusal.profileMismatch);
  }
  if (trace.layoutPolicyVersion != activeLayoutPolicyVersion) {
    instrument.noteInputRejected('pointer-replay-layout-mismatch');
    return const PointerReplayResult(PointerReplayRefusal.layoutMismatch);
  }
  for (final event in trace.events) {
    if (event.cancel) {
      instrument.pointerCancel(pointerId: event.pointerId);
    } else if (event.down) {
      instrument.pointerDown(
        pointerId: event.pointerId,
        x: event.x,
        y: event.y,
      );
    } else {
      instrument.pointerUp(pointerId: event.pointerId, x: event.x, y: event.y);
    }
  }
  return const PointerReplayResult(PointerReplayRefusal.none);
}
