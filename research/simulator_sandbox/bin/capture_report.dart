import 'dart:convert';
import 'dart:io';

import 'package:simulator_sandbox/simulator_sandbox.dart';

/// Prints one JSON object for a real file-backed yellow capture.
Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('forref-sim-report-');
  final session = await SandboxSession.open(
    simulatorRoot: root,
    sessionId: 'report001',
  );
  final success = await session.commitYellow(
    captureIntentId: 'sim-intent-report-yellow',
    participantId: sandboxParticipantId,
  );
  final successJournal = [
    for (final entry in session.journal.entries)
      '${entry.sequence} ${entry.kind.name} ${entry.detail}',
  ];
  session.journal.clear();
  session.failNextCommit();
  final failure = await session.commitYellow(
    captureIntentId: 'sim-intent-report-abort',
    participantId: sandboxParticipantId,
  );
  final failureJournal = [
    for (final entry in session.journal.entries)
      '${entry.sequence} ${entry.kind.name} ${entry.detail}',
  ];
  final recordId = success.recordId!;
  await session.close();
  final reopened = await SandboxSession.open(
    simulatorRoot: root,
    sessionId: 'report001',
  );
  final stored = await reopened.readBack(recordId);
  final ids = await reopened.rebuildProjection();
  final payload = {
    'successLabel': success.label,
    'recordId': recordId,
    'encodedBytes': success.encodedBytes,
    'fileBytesBefore': success.fileBytesBefore,
    'fileBytesAfter': success.fileBytesAfter,
    'recordCount': success.recordCount,
    'measurement': success.measurementLabel,
    'successJournal': successJournal,
    'failureLabel': failure.label,
    'failureJournal': failureJournal,
    'reopenRecord': stored?.recordId,
    'projectionIds': ids,
    'database': reopened.path.file.path,
  };
  await reopened.close();
  stdout.writeln(jsonEncode(payload));
}
