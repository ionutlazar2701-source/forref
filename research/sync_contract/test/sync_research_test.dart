import 'package:sync_contract/sync_research.dart';
import 'package:test/test.dart';

void main() {
  test('readiness matrix names supported, simulated, and missing', () {
    expect(
      syncReadinessMatrix.map((row) => row.status).toSet(),
      MatrixStatus.values.toSet(),
    );
    expect(
      syncReadinessMatrix
          .where((row) => row.item.contains('Authority lease'))
          .single
          .status,
      MatrixStatus.missing,
    );
    expect(
      syncReadinessMatrix
          .where((row) => row.item.contains('Saved'))
          .single
          .status,
      MatrixStatus.missing,
    );
    expect(researchTransitions.length, greaterThanOrEqualTo(12));
    for (final name in researchTransitions) {
      expect(researchTransitions.where((item) => item == name), hasLength(1));
    }
  });

  test('no transport acknowledgement means Saved', () {
    expect(
      TransportAck.values.map((ack) => ack.name),
      isNot(contains('saved')),
    );
    expect(
      TransportAck.values.map((ack) => ack.name),
      isNot(contains('committed')),
    );
    for (final ack in TransportAck.values) {
      expect(AckTruth(ack).meansSaved, isFalse);
    }
  });

  test('pairing does not confer authority or readiness', () {
    final machine = ResearchSyncMachine();
    final rejected = machine.pair(protocolSupported: false);
    expect(rejected.transition, 'pair-rejected');
    expect(rejected.meansSaved, isFalse);
    expect(machine.enrollment, Enrollment.rejected);
    expect(machine.authority, CaptureAuthority.none);
    expect(machine.readiness, Readiness.notReady);
    expect(machine.assignmentKind, AssignmentKind.none);

    final enrolled = ResearchSyncMachine()..pair(protocolSupported: true);
    expect(enrolled.enrollment, Enrollment.enrolled);
    expect(enrolled.authority, CaptureAuthority.none);
    expect(enrolled.readiness, Readiness.unknowable);
    expect(enrolled.assignmentKind, AssignmentKind.none);
  });

  test('assignment before enrollment is blocked', () {
    final machine = ResearchSyncMachine();
    final blocked = machine.assignMatch('match-1');
    expect(blocked.transition, 'assign-before-enrollment-blocked');
    expect(machine.assignmentKind, AssignmentKind.none);
    expect(machine.contextId, isNull);
  });

  test('match assignment does not lease authority', () {
    final machine = _enrolled();
    final assigned = machine.assignMatch('match-1');
    expect(assigned.transition, 'assign-match');
    expect(machine.assignmentKind, AssignmentKind.match);
    expect(machine.contextId, 'match-1');
    expect(machine.authority, CaptureAuthority.none);
    expect(machine.readiness, Readiness.unknowable);
    expect(
      machine.assignTraining('training-1').transition,
      'assignment-already-set',
    );
    expect(machine.assignmentKind, AssignmentKind.match);
  });

  test('training assignment never grants match authority', () {
    final machine = _enrolled();
    final assigned = machine.assignTraining('training-1');
    expect(assigned.transition, 'assign-training');
    expect(machine.authority, CaptureAuthority.none);
    expect(machine.sportingNotices, isEmpty);
    final sporting = machine
      ..setLink(LinkStatus.connected)
      ..receive(_sporting(messageId: 'goal-1', contextId: 'match-1'));
    expect(sporting.sportingNotices, isEmpty);
    expect(
      sporting.rejectedMessageIds,
      contains('goal-1'),
    );
  });

  test('unknown battery stays unknowable', () {
    final machine = _assignedMatch();
    final observed = machine.observeCapability(
      capability: CapabilityEvidence.current,
      batteryKnown: false,
    );
    expect(observed.transition, 'capability-battery-unknown');
    expect(machine.readiness, Readiness.unknowable);
    expect(machine.authority, CaptureAuthority.none);
  });

  test('a stale capability is not verified ready', () {
    final machine = _readyMatch();
    expect(machine.readiness, Readiness.readyForThisContext);
    final stale = machine.observeCapability(
      capability: CapabilityEvidence.stale,
      batteryKnown: true,
    );
    expect(stale.transition, 'capability-stale');
    expect(machine.readiness, Readiness.notVerified);
    expect(machine.authority, CaptureAuthority.none);
  });

  test('simulated readiness is not a link and not Saved', () {
    final machine = _readyMatch();
    expect(machine.readiness, Readiness.readyForThisContext);
    expect(machine.link, LinkStatus.absent);
    expect(machine.authority, CaptureAuthority.none);
    expect(machine.replication, ReplicationObservation.none);
  });

  test('a connected link does not imply ready or latest', () {
    final machine = _assignedMatch();
    final connected = machine.setLink(LinkStatus.connected);
    expect(connected.transition, 'link-connected-does-not-imply-ready');
    expect(connected.meansSaved, isFalse);
    expect(machine.link, LinkStatus.connected);
    expect(machine.readiness, Readiness.unknowable);
    expect(machine.replication, ReplicationObservation.none);
  });

  test('link loss does not transfer capture to the phone', () {
    final machine = _readyMatch()..setLink(LinkStatus.connected);
    final lost = machine.setLink(LinkStatus.lost);
    expect(lost.transition, 'link-lost-does-not-transfer-authority');
    expect(machine.authority, CaptureAuthority.none);
    expect(machine.readiness, Readiness.readyForThisContext);
    expect(machine.sportingNotices, isEmpty);
  });

  test('reconnect does not repair a gap', () {
    final machine = _receivingMatch();
    machine.receive(
      _sporting(messageId: 'goal-2', contextId: 'match-1', sequence: 2),
    );
    expect(machine.replication, ReplicationObservation.gap);
    machine.setLink(LinkStatus.lost);
    final reconnected = machine.setLink(LinkStatus.connected);
    expect(reconnected.transition, 'reconnect-does-not-repair-gaps');
    expect(machine.replication, ReplicationObservation.gap);
    expect(machine.sportingNotices, hasLength(1));
    expect(machine.authority, CaptureAuthority.none);
  });

  test('an offline watch is not delivered to the phone', () {
    final machine = _readyMatch();
    final offline = machine.receive(
      _sporting(messageId: 'goal-1', contextId: 'match-1', sequence: 1),
    );
    expect(offline.transition, 'offline-watch-not-delivered');
    expect(offline.ack, TransportAck.notSent);
    expect(offline.meansSaved, isFalse);
    expect(machine.sportingNotices, isEmpty);
    expect(machine.authority, CaptureAuthority.none);
  });

  test('a duplicate message is not admitted twice', () {
    final machine = _receivingMatch();
    final first = machine.receive(
      _sporting(messageId: 'goal-1', contextId: 'match-1', sequence: 1),
    );
    expect(first.ack, TransportAck.admitted);
    expect(first.meansSaved, isFalse);
    final duplicate = machine.receive(
      _sporting(messageId: 'goal-1', contextId: 'match-1', sequence: 1),
    );
    expect(duplicate.transition, 'duplicate-message');
    expect(duplicate.ack, TransportAck.received);
    expect(machine.sportingNotices, hasLength(1));
  });

  test('an out-of-order record keeps the gap', () {
    final machine = _receivingMatch();
    final second = machine.receive(
      _sporting(messageId: 'goal-2', contextId: 'match-1', sequence: 2),
    );
    expect(second.transition, 'out-of-order-preserved');
    expect(second.ack, TransportAck.admitted);
    expect(machine.replication, ReplicationObservation.gap);
    expect(machine.sportingNotices.single.originSequence, 2);
    final first = machine.receive(
      _sporting(messageId: 'goal-1', contextId: 'match-1', sequence: 1),
    );
    expect(first.transition, 'in-order-admitted');
    expect(machine.replication, ReplicationObservation.observed);
    expect(machine.sportingNotices, hasLength(2));
  });

  test('a corrupt message is quarantined', () {
    final machine = _receivingMatch();
    final corrupt = machine.receive(
      _sporting(
        messageId: 'bad-1',
        contextId: 'match-1',
        sequence: 1,
        corrupt: true,
      ),
    );
    expect(corrupt.transition, 'corrupt-quarantine');
    expect(corrupt.ack, TransportAck.received);
    expect(machine.sportingNotices, isEmpty);
    expect(machine.quarantinedMessageIds, ['bad-1']);
    expect(machine.replication, ReplicationObservation.quarantined);
  });

  test('a wrong match is not admitted', () {
    final machine = _receivingMatch();
    final wrong = machine.receive(
      _sporting(messageId: 'other-1', contextId: 'match-2', sequence: 1),
    );
    expect(wrong.transition, 'wrong-match');
    expect(machine.sportingNotices, isEmpty);
    expect(machine.rejectedMessageIds, ['other-1']);
  });

  test('a missing sequence stays a gap', () {
    final machine = _receivingMatch();
    final missing = machine.receive(
      _sporting(messageId: 'gap-1', contextId: 'match-1', omitSequence: true),
    );
    expect(missing.transition, 'missing-sequence');
    expect(machine.sportingNotices, isEmpty);
    expect(machine.replication, ReplicationObservation.gap);
  });

  test('a stale authority generation is rejected', () {
    final machine = _receivingMatch();
    final stale = machine.receive(
      _sporting(
        messageId: 'old-1',
        contextId: 'match-1',
        sequence: 1,
        generation: 0,
      ),
    );
    expect(stale.transition, 'stale-authority-generation');
    expect(machine.sportingNotices, isEmpty);
    expect(machine.authority, CaptureAuthority.none);
  });

  test('training measurements stay out of sporting notices', () {
    final match = _receivingMatch();
    final blocked = match.receive(
      ResearchEnvelope(
        messageId: 'hr-1',
        contextId: 'training-1',
        kind: EnvelopeKind.trainingMeasurement,
        originSequence: 1,
        authorityGeneration: 1,
      ),
    );
    expect(
      blocked.transition,
      'training-measurement-kept-out-of-sporting-records',
    );
    expect(match.sportingNotices, isEmpty);
    expect(match.trainingNotices, isEmpty);

    final training = _enrolled()..assignTraining('training-1');
    training.setLink(LinkStatus.connected);
    final admitted = training.receive(
      ResearchEnvelope(
        messageId: 'hr-1',
        contextId: 'training-1',
        kind: EnvelopeKind.trainingMeasurement,
        originSequence: 1,
        authorityGeneration: 1,
      ),
    );
    expect(admitted.transition, 'training-measurement-separated');
    expect(admitted.ack, TransportAck.admitted);
    expect(admitted.meansSaved, isFalse);
    expect(training.trainingNotices, hasLength(1));
    expect(training.sportingNotices, isEmpty);
    expect(training.authority, CaptureAuthority.none);
  });

  test('the script covers at least twelve factual transitions', () {
    final seen = <String>{};
    final cold = ResearchSyncMachine();
    seen.add(cold.pair(protocolSupported: false).transition);
    seen.add(cold.assignMatch('match-1').transition);

    final match = _receivingMatch();
    seen.add(match.setLink(LinkStatus.lost).transition);
    seen.add(match.setLink(LinkStatus.connected).transition);
    seen.add(
      match
          .receive(
            _sporting(messageId: 'goal-2', contextId: 'match-1', sequence: 2),
          )
          .transition,
    );
    seen.add(
      match
          .receive(
            _sporting(
              messageId: 'bad',
              contextId: 'match-1',
              sequence: 3,
              corrupt: true,
            ),
          )
          .transition,
    );
    seen.add(
      match
          .receive(
            _sporting(messageId: 'other', contextId: 'match-9', sequence: 1),
          )
          .transition,
    );
    seen.add(
      match
          .receive(
            _sporting(
              messageId: 'gap',
              contextId: 'match-1',
              omitSequence: true,
            ),
          )
          .transition,
    );
    seen.add(
      match
          .receive(
            _sporting(
              messageId: 'old',
              contextId: 'match-1',
              sequence: 4,
              generation: 2,
            ),
          )
          .transition,
    );
    final offline = _readyMatch();
    seen.add(
      offline
          .receive(
            _sporting(messageId: 'away', contextId: 'match-1', sequence: 1),
          )
          .transition,
    );

    final training = _enrolled();
    seen.add(training.assignTraining('training-9').transition);
    training.setLink(LinkStatus.connected);
    seen.add(
      training
          .receive(
            ResearchEnvelope(
              messageId: 'load-1',
              contextId: 'training-9',
              kind: EnvelopeKind.trainingMeasurement,
              originSequence: 1,
              authorityGeneration: 1,
            ),
          )
          .transition,
    );
    expect(seen.length, greaterThanOrEqualTo(12));
    expect(researchTransitions.toSet().containsAll(seen), isTrue);
  });
}

ResearchSyncMachine _enrolled() {
  final machine = ResearchSyncMachine()..pair(protocolSupported: true);
  return machine;
}

ResearchSyncMachine _assignedMatch() {
  return _enrolled()..assignMatch('match-1');
}

ResearchSyncMachine _readyMatch() {
  final machine = _assignedMatch();
  final ready = machine.observeCapability(
    capability: CapabilityEvidence.current,
    batteryKnown: true,
  );
  expect(ready.transition, 'readiness-simulated-for-context');
  expect(ready.meansSaved, isFalse);
  return machine;
}

ResearchSyncMachine _receivingMatch() {
  return _readyMatch()..setLink(LinkStatus.connected);
}

ResearchEnvelope _sporting({
  required String messageId,
  required String contextId,
  int? sequence = 1,
  int? generation = 1,
  bool omitSequence = false,
  bool corrupt = false,
}) {
  return ResearchEnvelope(
    messageId: messageId,
    contextId: contextId,
    kind: EnvelopeKind.sportingRecord,
    originSequence: omitSequence ? null : sequence,
    authorityGeneration: generation,
    corrupt: corrupt,
  );
}
