import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';

import 'lab_support.dart';

void main() {
  test('generateCaptureReport succeeds in-process', () async {
    final report = await captureReportPayload();
    expect(report['successLabel'], sandboxCommittedLabel);
  });
}
