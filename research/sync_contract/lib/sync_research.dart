/// Research-only sync facts. Not a production transport and not Match Memory.
library;

/// How far a research row is allowed to claim support.
enum MatrixStatus { supported, simulated, missing }

/// One row of the sync readiness matrix.
final class MatrixRow {
  const MatrixRow({
    required this.item,
    required this.status,
    required this.evidence,
  });

  final String item;
  final MatrixStatus status;
  final String evidence;
}

/// What tonight's research can and cannot claim.
const syncReadinessMatrix = <MatrixRow>[
  MatrixRow(
    item: 'Production NoPeerTransport sends nothing',
    status: MatrixStatus.supported,
    evidence:
        'Phone source only. This package does not call or modify that type.',
  ),
  MatrixRow(
    item: 'Research fact transitions',
    status: MatrixStatus.simulated,
    evidence: 'In-memory labels in this package. Not a device and not Saved.',
  ),
  MatrixRow(
    item: 'Transport acknowledgement means Saved',
    status: MatrixStatus.missing,
    evidence: 'No Saved acknowledgement. Watch-origin durability is not proven.',
  ),
  MatrixRow(
    item: 'Pairing SDK',
    status: MatrixStatus.missing,
    evidence: 'No platform pairing in this package.',
  ),
  MatrixRow(
    item: 'Authenticated wire',
    status: MatrixStatus.missing,
    evidence: 'No networking dependency.',
  ),
  MatrixRow(
    item: 'Watch battery reading',
    status: MatrixStatus.missing,
    evidence: 'Battery known is an injected flag, not a sensor.',
  ),
  MatrixRow(
    item: 'Watch local D1',
    status: MatrixStatus.missing,
    evidence: 'This package has no durable store.',
  ),
  MatrixRow(
    item: 'Authority lease',
    status: MatrixStatus.missing,
    evidence:
        'Deferred. Architecture, Gene, Domain, and Tony own that contract.',
  ),
  MatrixRow(
    item: 'Production watch ready',
    status: MatrixStatus.missing,
    evidence: 'readyForThisContext is a research label only.',
  ),
];

/// Factual transitions this research machine can report.
const researchTransitions = <String>[
  'pair-rejected',
  'pair-enrolled-without-authority',
  'pair-already-enrolled',
  'assign-before-enrollment-blocked',
  'assign-match',
  'assign-training',
  'assignment-already-set',
  'capability-battery-unknown',
  'capability-stale',
  'readiness-simulated-for-context',
  'link-connected-does-not-imply-ready',
  'link-lost-does-not-transfer-authority',
  'reconnect-does-not-repair-gaps',
  'offline-watch-not-delivered',
  'duplicate-message',
  'out-of-order-preserved',
  'in-order-admitted',
  'corrupt-quarantine',
  'wrong-match',
  'sporting-record-rejected-during-training',
  'missing-sequence',
  'conflicting-sequence',
  'stale-authority-generation',
  'training-measurement-kept-out-of-sporting-records',
  'training-measurement-separated',
];

enum Enrollment { unknown, enrolled, rejected }

enum AssignmentKind { none, match, training }

enum CapabilityEvidence { missing, stale, current }

enum Readiness { unknowable, notVerified, notReady, readyForThisContext }

enum CaptureAuthority { none }

enum LinkStatus { absent, connected, lost }

enum ReplicationObservation { none, observed, gap, quarantined }

/// Delivery facts. There is no Saved value.
enum TransportAck { notSent, sent, received, admitted }

/// A transport acknowledgement. It never means Saved.
final class AckTruth {
  const AckTruth(this.ack);

  final TransportAck ack;

  bool get meansSaved => false;
}

enum EnvelopeKind { sportingRecord, trainingMeasurement }

/// One research message. It is not a Match Record.
final class ResearchEnvelope {
  const ResearchEnvelope({
    required this.messageId,
    required this.contextId,
    required this.kind,
    this.originSequence,
    this.authorityGeneration,
    this.corrupt = false,
  });

  final String messageId;
  final String contextId;
  final EnvelopeKind kind;
  final int? originSequence;
  final int? authorityGeneration;
  final bool corrupt;
}

/// A notice the research inbox accepted. Acceptance is not Saved.
final class ResearchNotice {
  const ResearchNotice({
    required this.messageId,
    required this.contextId,
    required this.originSequence,
    required this.authorityGeneration,
  });

  final String messageId;
  final String contextId;
  final int originSequence;
  final int authorityGeneration;
}

/// One labeled research step.
final class SyncObservation {
  const SyncObservation({
    required this.transition,
    required this.ack,
    required this.note,
  });

  final String transition;
  final TransportAck ack;
  final String note;

  bool get meansSaved => false;
}

/// In-memory fact machine. Link, readiness, and authority stay independent.
final class ResearchSyncMachine {
  static const expectedGeneration = 1;

  Enrollment enrollment = Enrollment.unknown;
  AssignmentKind assignmentKind = AssignmentKind.none;
  String? contextId;
  CapabilityEvidence capability = CapabilityEvidence.missing;
  bool batteryKnown = false;
  Readiness readiness = Readiness.unknowable;
  CaptureAuthority authority = CaptureAuthority.none;
  LinkStatus link = LinkStatus.absent;
  ReplicationObservation replication = ReplicationObservation.none;
  final List<ResearchNotice> sportingNotices = [];
  final List<ResearchNotice> trainingNotices = [];
  final List<String> quarantinedMessageIds = [];
  final List<String> rejectedMessageIds = [];

  SyncObservation pair({required bool protocolSupported}) {
    if (enrollment == Enrollment.enrolled) {
      return _step(
        'pair-already-enrolled',
        TransportAck.notSent,
        'A second pair does not add authority.',
      );
    }
    if (!protocolSupported) {
      enrollment = Enrollment.rejected;
      readiness = Readiness.notReady;
      return _step(
        'pair-rejected',
        TransportAck.notSent,
        'Unsupported protocol. No assignment and no authority.',
      );
    }
    enrollment = Enrollment.enrolled;
    _deriveReadiness();
    return _step(
      'pair-enrolled-without-authority',
      TransportAck.notSent,
      'Enrollment identifies a device. It does not confer capture authority.',
    );
  }

  SyncObservation assignMatch(String matchId) {
    return _assign(AssignmentKind.match, matchId, 'assign-match');
  }

  SyncObservation assignTraining(String trainingSessionId) {
    return _assign(
      AssignmentKind.training,
      trainingSessionId,
      'assign-training',
    );
  }

  SyncObservation observeCapability({
    required CapabilityEvidence capability,
    required bool batteryKnown,
  }) {
    this.capability = capability;
    this.batteryKnown = batteryKnown;
    _deriveReadiness();
    if (capability == CapabilityEvidence.stale) {
      return _step(
        'capability-stale',
        TransportAck.notSent,
        'A stale capability is not ready and not verified.',
      );
    }
    if (!batteryKnown || capability != CapabilityEvidence.current) {
      return _step(
        'capability-battery-unknown',
        TransportAck.notSent,
        'Unknown battery or capability stays unknowable.',
      );
    }
    return _step(
      'readiness-simulated-for-context',
      TransportAck.notSent,
      'Simulated readiness for this context. Not production watch ready.',
    );
  }

  SyncObservation setLink(LinkStatus next) {
    final previous = link;
    link = next;
    if (next == LinkStatus.connected && previous == LinkStatus.lost) {
      return _step(
        'reconnect-does-not-repair-gaps',
        TransportAck.notSent,
        'Reconnect does not fill gaps or move authority.',
      );
    }
    if (next == LinkStatus.connected) {
      return _step(
        'link-connected-does-not-imply-ready',
        TransportAck.notSent,
        'Connected is not ready, not latest, and not Saved.',
      );
    }
    return _step(
      'link-lost-does-not-transfer-authority',
      TransportAck.notSent,
      'The phone does not gain capture because the link dropped.',
    );
  }

  SyncObservation receive(ResearchEnvelope envelope) {
    if (link != LinkStatus.connected) {
      return _step(
        'offline-watch-not-delivered',
        TransportAck.notSent,
        'The phone has no delivery. This does not grant phone capture.',
      );
    }
    if (envelope.corrupt) {
      quarantinedMessageIds.add(envelope.messageId);
      replication = ReplicationObservation.quarantined;
      return _step(
        'corrupt-quarantine',
        TransportAck.received,
        'Corrupt bytes stay quarantined and are not admitted.',
      );
    }
    if (envelope.kind == EnvelopeKind.trainingMeasurement) {
      return _receiveTraining(envelope);
    }
    return _receiveSporting(envelope);
  }

  SyncObservation _assign(
    AssignmentKind kind,
    String id,
    String transition,
  ) {
    if (enrollment != Enrollment.enrolled) {
      return _step(
        'assign-before-enrollment-blocked',
        TransportAck.notSent,
        'Assignment requires enrollment. Pairing is not match ready.',
      );
    }
    if (assignmentKind != AssignmentKind.none &&
        (assignmentKind != kind || contextId != id)) {
      return _step(
        'assignment-already-set',
        TransportAck.notSent,
        'A second context does not replace the first.',
      );
    }
    assignmentKind = kind;
    contextId = id;
    authority = CaptureAuthority.none;
    _deriveReadiness();
    final note = kind == AssignmentKind.training
        ? 'Training assignment does not grant match authority.'
        : 'Match assignment does not grant a watch authority lease.';
    return _step(transition, TransportAck.notSent, note);
  }

  SyncObservation _receiveTraining(ResearchEnvelope envelope) {
    if (assignmentKind != AssignmentKind.training ||
        envelope.contextId != contextId) {
      rejectedMessageIds.add(envelope.messageId);
      return _step(
        'training-measurement-kept-out-of-sporting-records',
        TransportAck.received,
        'Training metrics are not sporting records.',
      );
    }
    if (trainingNotices.any((notice) => notice.messageId == envelope.messageId)) {
      return _step(
        'duplicate-message',
        TransportAck.received,
        'A repeated training message is not admitted twice.',
      );
    }
    final sequence = envelope.originSequence;
    final generation = envelope.authorityGeneration;
    if (sequence == null || generation != expectedGeneration) {
      rejectedMessageIds.add(envelope.messageId);
      return _step(
        'stale-authority-generation',
        TransportAck.received,
        'Training measurements still require a known generation.',
      );
    }
    trainingNotices.add(
      ResearchNotice(
        messageId: envelope.messageId,
        contextId: envelope.contextId,
        originSequence: sequence,
        authorityGeneration: expectedGeneration,
      ),
    );
    return _step(
      'training-measurement-separated',
      TransportAck.admitted,
      'Admitted to the training inbox only. Not Match Memory and not Saved.',
    );
  }

  SyncObservation _receiveSporting(ResearchEnvelope envelope) {
    if (assignmentKind != AssignmentKind.match ||
        envelope.contextId != contextId) {
      rejectedMessageIds.add(envelope.messageId);
      final transition = assignmentKind == AssignmentKind.training
          ? 'sporting-record-rejected-during-training'
          : 'wrong-match';
      return _step(
        transition,
        TransportAck.received,
        'The message is not admitted into this context.',
      );
    }
    if (envelope.authorityGeneration != expectedGeneration) {
      rejectedMessageIds.add(envelope.messageId);
      return _step(
        'stale-authority-generation',
        TransportAck.received,
        'A stale or missing generation is not admitted.',
      );
    }
    if (sportingNotices.any((notice) => notice.messageId == envelope.messageId)) {
      return _step(
        'duplicate-message',
        TransportAck.received,
        'A repeated message id does not create a second notice.',
      );
    }
    final sequence = envelope.originSequence;
    if (sequence == null) {
      replication = ReplicationObservation.gap;
      return _step(
        'missing-sequence',
        TransportAck.received,
        'A missing sequence is a gap. It is not filled in.',
      );
    }
    if (sportingNotices.any((notice) => notice.originSequence == sequence)) {
      quarantinedMessageIds.add(envelope.messageId);
      replication = ReplicationObservation.quarantined;
      return _step(
        'conflicting-sequence',
        TransportAck.received,
        'A different message for the same sequence is quarantined.',
      );
    }
    sportingNotices.add(
      ResearchNotice(
        messageId: envelope.messageId,
        contextId: envelope.contextId,
        originSequence: sequence,
        authorityGeneration: expectedGeneration,
      ),
    );
    final gap = _sportingGap;
    replication = gap
        ? ReplicationObservation.gap
        : ReplicationObservation.observed;
    return _step(
      gap ? 'out-of-order-preserved' : 'in-order-admitted',
      TransportAck.admitted,
      'Research admission only. Not Saved and not Match Memory.',
    );
  }

  void _deriveReadiness() {
    if (enrollment == Enrollment.rejected) {
      readiness = Readiness.notReady;
      return;
    }
    if (enrollment != Enrollment.enrolled ||
        assignmentKind == AssignmentKind.none) {
      readiness = Readiness.unknowable;
      return;
    }
    if (capability == CapabilityEvidence.stale) {
      readiness = Readiness.notVerified;
      return;
    }
    if (capability != CapabilityEvidence.current || !batteryKnown) {
      readiness = Readiness.unknowable;
      return;
    }
    readiness = Readiness.readyForThisContext;
  }

  bool get _sportingGap {
    if (sportingNotices.isEmpty) return false;
    final sequences = sportingNotices.map((notice) => notice.originSequence);
    final highest = sequences.reduce((a, b) => a > b ? a : b);
    final present = sequences.toSet();
    for (var expected = 1; expected <= highest; expected++) {
      if (!present.contains(expected)) return true;
    }
    return false;
  }

  SyncObservation _step(String transition, TransportAck ack, String note) {
    return SyncObservation(transition: transition, ack: ack, note: note);
  }
}
