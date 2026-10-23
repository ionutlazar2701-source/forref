import 'package:simulator_sandbox/simulator_sandbox.dart';
import 'package:test/test.dart';

void main() {
  test('generateCaptureReport succeeds in-process', () async {
    final report = await generateCaptureReport();
    expect(report['successLabel'], sandboxCommittedLabel);
    expect(report['failureLabel'], sandboxFailedLabel);
    expect(report['recordId'], isNotNull);
    expect(report['successJournal'], isA<List>());
  });
}
