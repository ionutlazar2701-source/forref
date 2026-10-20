import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('geometry package does not depend on Flutter or production authority', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final token in [
      'flutter',
      'forref_match_core',
      'forref_match_persistence',
      'match_core',
      'firebase',
      'hf_v2',
    ]) {
      expect(pubspec.toLowerCase(), isNot(contains(token)), reason: token);
    }
    final forbidden = [
      'package:flutter',
      'forref_match_persistence',
      'forref_match_core',
      'package:match_core',
      'firebase',
      'DurableCommitPort',
    ];
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final token in forbidden) {
        if (text.contains(token)) hits.add('${entity.path}: $token');
      }
    }
    expect(hits, isEmpty);
  });

  test('the phone app and root workspace do not import the simulator', () {
    final root = File('../../pubspec.yaml').readAsStringSync();
    expect(root, isNot(contains('simulator_geometry')));
    expect(root, isNot(contains('hf_prototype')));
    expect(root, isNot(contains('hf_v2')));
    final phone = Directory('../../apps/referee_phone/lib');
    final hits = <String>[];
    for (final entity in phone.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final token in ['simulator_geometry', 'hf_prototype', 'hf_v2']) {
        if (text.contains(token)) hits.add('${entity.path}: $token');
      }
    }
    expect(hits, isEmpty);
  });
}
