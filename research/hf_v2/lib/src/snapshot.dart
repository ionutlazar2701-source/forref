import 'model.dart';

/// Command meaning frozen at activation. Later edits do not change it.
final class ActivatedCommandSnapshot {
  const ActivatedCommandSnapshot({
    required this.kind,
    required this.subjectId,
    required this.subjectKind,
    required this.scope,
    required this.outId,
    required this.inId,
  });

  final FinalActionKind kind;
  final String? subjectId;
  final SubjectKind? subjectKind;
  final ResearchScope scope;
  final String? outId;
  final String? inId;
}

/// Read-only view of one research instrument.
///
/// Lists are copies. Reading a snapshot does not append a record.
final class ResearchTruthSnapshot {
  const ResearchTruthSnapshot({
    required this.scenarioId,
    required this.pitchTruth,
    required this.expectedDigitalTruth,
    required this.expectedUnfinishedTruth,
    required this.p0Failure,
    required this.priorCaution,
    required this.priorCautionLabel,
    required this.cautions,
    required this.sendOffs,
    required this.substitutions,
    required this.roster,
    required this.officials,
    required this.teamContext,
    required this.scope,
    required this.selectionKind,
    required this.yellowOffered,
    required this.directSendOffOffered,
    required this.selectedSubjectId,
    required this.selectedSubjectKind,
    required this.outId,
    required this.inId,
    required this.substitutionStage,
    required this.inFlight,
    required this.commitKind,
    required this.commitLabel,
    required this.armedKind,
    required this.predecessorKind,
    required this.successorEstablished,
    required this.activePointerCount,
    required this.freshInputEligible,
    required this.simulatedRecoveryDisclaimer,
  });

  final String scenarioId;
  final String pitchTruth;
  final String expectedDigitalTruth;
  final String expectedUnfinishedTruth;
  final String p0Failure;
  final PriorCautionKnowledge priorCaution;
  final String priorCautionLabel;
  final List<SavedCaution> cautions;
  final List<SavedSendOff> sendOffs;
  final List<SavedSubstitution> substitutions;
  final List<ResearchParticipant> roster;
  final List<ResearchOfficial> officials;
  final TeamContextKind teamContext;
  final ResearchScope scope;
  final SubjectSelectionKind selectionKind;
  final bool yellowOffered;
  final bool directSendOffOffered;
  final String? selectedSubjectId;
  final SubjectKind? selectedSubjectKind;
  final String? outId;
  final String? inId;
  final SubstitutionStage substitutionStage;
  final ActivatedCommandSnapshot? inFlight;
  final SystemCommitKind commitKind;
  final String commitLabel;
  final FinalActionKind? armedKind;
  final FinalActionKind? predecessorKind;
  final bool successorEstablished;
  final int activePointerCount;
  final bool freshInputEligible;
  final bool simulatedRecoveryDisclaimer;

  String get sendOffPresence =>
      sendOffs.isEmpty ? 'SEND_OFF absent' : 'SEND_OFF recorded ${sendOffs.length}';
}
