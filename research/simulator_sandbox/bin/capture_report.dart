import 'dart:io';

import 'package:simulator_sandbox/simulator_sandbox.dart';

/// Prints one JSON object for a real file-backed yellow capture.
Future<void> main() async {
  final payload = await generateCaptureReport();
  stdout.writeln(encodeCaptureReport(payload));
}
