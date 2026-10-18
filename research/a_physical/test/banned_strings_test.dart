import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('lib/ contains no banned certification strings', () {
    const banned = ['PHYSICAL_PASS', 'CERTIFIED', 'hardwareApproved'];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final token in banned) {
        if (text.contains(token)) {
          violations.add('${entity.path}: contains $token');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
