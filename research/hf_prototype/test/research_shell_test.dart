import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

void main() {
  testWidgets('the shell launches as a research prototype', (tester) async {
    final controller = await pumpLab(tester);
    expect(find.text('FORREF SIMULATOR LAB'), findsOneWidget);
    expect(find.text('FORREF'), findsWidgets);
    expect(find.text('RESEARCH / NON-PRODUCTION'), findsOneWidget);
    // The device is the hero: the factual shell and the reference UI are the
    // first thing on screen. The Night I geometry stage is an advanced route.
    expect(controller.workspace, LabWorkspace.focus);
    expect(controller.inspectorOpen, isFalse);
    expect(find.byType(WatchReferenceApp), findsOneWidget);
    expect(find.byKey(const Key('research-capture')), findsNothing);
    expect(find.text('Scenario'), findsNothing);
    expect(find.text('SCENARIO'), findsNothing);
    expect(find.byKey(const Key('research-operator')), findsNothing);

    controller.openGeometryStage();
    await tester.pump();
    expect(find.byKey(const Key('research-capture')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('research-capture')),
        matching: find.text('Scenario'),
      ),
      findsNothing,
    );
  });

  testWidgets('a repeat tap on yellow does not record a sending-off',
      (tester) async {
    final controller = await pumpLab(tester);
    controller.openGeometryStage();
    controller.load(ScenarioId.s07RapidRepeatAfterY2);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await openInspectorTab(tester, InspectorSection.truth);

    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    expect(find.text('Two cautions recorded'), findsOneWidget);
    expect(find.text('Sending-off recorded'), findsNothing);

    final yellow = tester.getRect(find.text('Record yellow'));
    final sendOff = tester.getRect(find.text('Record sending-off'));
    expect(yellow.overlaps(sendOff), isFalse);

    await tester.tapAt(yellow.center);
    await tester.pump();
    expect(find.text('Sending-off recorded'), findsNothing);
    expect(controller.instrument.sendOffs, isEmpty);
    expect(controller.instrument.productionMatchMemoryWrites, isFalse);
  });

  testWidgets('rebuild keeps the research signature', (tester) async {
    final controller = ResearchController();
    controller.openGeometryStage();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.load(ScenarioId.s02YellowOnePrior);
    await tester.pump();
    final signature = controller.instrument.behaviorSignature;
    await tester.pumpWidget(ResearchApp(controller: controller));
    await tester.pump();
    expect(controller.instrument.behaviorSignature, signature);
  });

  testWidgets('team change invalidates Home 14', (tester) async {
    final controller = await pumpLab(tester);
    controller.load(ScenarioId.s09Home14ThenAway14);
    await tester.pump();
    await openWorkspace(tester, LabWorkspace.commandLab);
    await openInspectorTab(tester, InspectorSection.truth);
    expect(inTruthInspector(find.textContaining('p-home-14')), findsOneWidget);
    await tester.tap(find.text('Team: Away'));
    await tester.pump();
    expect(
        inTruthInspector(find.textContaining('invalidated')), findsOneWidget);
    expect(controller.instrument.selectedParticipantId, isNull);
  });

  testWidgets('scenario controls stay off the device stage', (tester) async {
    await pumpLab(tester);
    expect(find.text('SCENARIO'), findsNothing);
    await openWorkspace(tester, LabWorkspace.commandLab);
    expect(find.byKey(const Key('command-stage')), findsOneWidget);
    expect(find.byKey(const Key('research-operator')), findsOneWidget);
    expect(find.text('SCENARIO'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('command-stage')),
        matching: find.text('SCENARIO'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(WatchReferenceApp),
        matching: find.byKey(const Key('scenario-dropdown')),
      ),
      findsNothing,
    );
  });

  testWidgets('shoot-out scope does not inherit the match caution count',
      (tester) async {
    final controller = await pumpLab(tester);
    controller.load(ScenarioId.s18MatchToShootout);
    await tester.pump();
    await openWorkspace(tester, LabWorkspace.commandLab);
    await openInspectorTab(tester, InspectorSection.truth);
    expect(inTruthInspector(find.textContaining('match cautions 1')),
        findsOneWidget);
    await tester.tap(find.text('Scope: shoot-out'));
    await tester.pump();
    expect(inTruthInspector(find.textContaining('shootout cautions 0')),
        findsOneWidget);
    expect(
      controller.instrument.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.match,
      ),
      1,
    );
  });

  testWidgets('naming OUT and IN does not record the substitution',
      (tester) async {
    final controller = await pumpLab(tester);
    controller.openGeometryStage();
    controller.load(ScenarioId.s11SubstitutionOutFirst);
    controller.show(ResearchPage.substitution);
    await tester.pump();
    await tester.ensureVisible(find.text('Out p-home-9'));
    await tester.tap(find.text('Out p-home-9'));
    await tester.pump();
    await tester.ensureVisible(find.text('In p-home-7'));
    await tester.tap(find.text('In p-home-7'));
    await tester.pump();
    expect(controller.instrument.outId, 'p-home-9');
    expect(controller.instrument.inId, 'p-home-7');
    expect(controller.instrument.substitutionRecorded, isFalse);
  });

  test('the prototype is outside production phone routing', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('forref_match_persistence')));
    expect(pubspec, isNot(contains('forref_match_core')));
    expect(pubspec, contains('simulator_geometry'));
    expect(pubspec, contains('hf_v2'));
    final phone = Directory('../../apps/referee_phone/lib');
    final hits = <String>[];
    for (final entity in phone.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final token in ['hf_prototype', 'hf_v2', 'simulator_geometry']) {
        if (text.contains(token)) hits.add('${entity.path}: $token');
      }
    }
    expect(hits, isEmpty);
  });
}
