import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

void main() {
  testWidgets('painted yellow target matches the instrument rectangle',
      (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.show(ResearchPage.yellow);
    await tester.pump();

    final stage = tester.getRect(find.byKey(const Key('research-capture')));
    final painted = tester.getRect(find.byKey(const Key('target-yellow')));
    final view = assessView(
      profile: illustrativePhonePortrait,
      stageWidth: stage.width,
      stageHeight: stage.height,
      requested: CalibrationMode.fit,
    );
    final mapped =
        view.transform.toStageRect(const DeviceRect(16, 180, 150, 48));
    expect(painted.left, closeTo(stage.left + mapped.left, 1));
    expect(painted.top, closeTo(stage.top + mapped.top, 1));
    expect(painted.width, closeTo(mapped.width, 1));
    expect(painted.height, closeTo(mapped.height, 1));
    expect(controller.instrument.layout.yellow.left, 16);
    expect(controller.instrument.cautions, isEmpty);
  });

  testWidgets('C profile switch cancels an open pointer', (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.show(ResearchPage.yellow);
    await tester.pump();
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Record yellow')));
    await tester.pump();
    await tester.tap(find.text('Round watch'));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(controller.instrument.cautions, isEmpty);
    expect(controller.instrument.commitKind, isNot(SystemCommitKind.saved));
    expect(controller.instrument.sendOffs, isEmpty);
  });

  testWidgets('D a round-watch corner does not activate a target',
      (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.selectProfile(illustrativeRoundWatch.profileId);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    final stage = tester.getRect(find.byKey(const Key('research-capture')));
    await tester.tapAt(stage.topLeft + const Offset(1, 1));
    await tester.pump();
    expect(controller.instrument.cautions, isEmpty);
    expect(controller.instrument.commitKind, isNot(SystemCommitKind.saved));
    expect(find.text('Screen shape: round'), findsWidgets);
  });

  testWidgets('E F G held resolution keeps the frozen command', (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.setHold(true);
    controller.load(ScenarioId.s09Home14ThenAway14);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    expect(controller.instrument.snapshot.inFlight?.subjectId, 'p-home-14');
    expect(controller.instrument.cautions, isEmpty);
    await tester.tap(find.text('Away'));
    await tester.pump();
    expect(controller.instrument.snapshot.inFlight?.subjectId, 'p-home-14');
    expect(controller.instrument.snapshot.selectedSubjectId, isNull);
    controller.resolveHeldCommit();
    await tester.pump();
    expect(controller.instrument.cautions.single.subjectId, 'p-home-14');

    controller.setHold(true);
    controller.load(ScenarioId.s01YellowNoPrior);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    await tester.tap(find.text('Shoot-out scope'));
    await tester.pump();
    expect(controller.instrument.snapshot.inFlight?.scope, ResearchScope.match);
    controller.resolveHeldCommit();
    await tester.pump();
    expect(
      controller.instrument.savedCautionCount(
        'p-home-9',
        SubjectKind.participant,
        ResearchScope.match,
      ),
      1,
    );

    controller.setHold(true);
    controller.load(ScenarioId.s11SubstitutionOutFirst);
    controller.show(ResearchPage.substitution);
    await tester.pump();
    await tester.ensureVisible(find.text('Out p-home-9'));
    await tester.tap(find.text('Out p-home-9'));
    await tester.pump();
    await tester.ensureVisible(find.text('In p-home-7'));
    await tester.tap(find.text('In p-home-7'));
    await tester.pump();
    await tester.tap(find.text('Record substitution'));
    await tester.pump();
    await tester.ensureVisible(find.text('In p-home-14'));
    await tester.tap(find.text('In p-home-14'));
    await tester.pump();
    expect(controller.instrument.snapshot.inFlight?.outId, 'p-home-9');
    expect(controller.instrument.snapshot.inFlight?.inId, 'p-home-7');
    controller.resolveHeldCommit();
    await tester.pump();
    expect(controller.instrument.substitutions.single.inId, 'p-home-7');
    expect(controller.instrument.substitutions.single.outId, 'p-home-9');
  });

  testWidgets('H unknown outcome is not saved and not a known failure',
      (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.load(ScenarioId.s16SaveNotVerified);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    expect(find.textContaining('SAVE NOT VERIFIED'), findsWidgets);
    expect(find.textContaining('SIMULATED SAVED'), findsNothing);
    expect(find.textContaining('NOT SAVED — known simulated failure'),
        findsNothing);
    expect(controller.instrument.cautions, isEmpty);
    expect(controller.instrument.snapshot.freshInputEligible, isFalse);
  });

  testWidgets('I unknown touch is not treated as supported', (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.importProfile(_touch('unknown'));
    await tester.pump();
    expect(controller.activeProfile.touchClaimedSupported, isFalse);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    expect(controller.instrument.cautions, isEmpty);
    controller.setTouchOverride(true);
    await tester.pump();
    await tester.tap(find.text('Record yellow'));
    await tester.pump();
    expect(controller.instrument.cautions, hasLength(1));
    expect(controller.activeProfile.capability(InputChannel.touchscreen),
        CapabilityStatus.unknown);
  });

  testWidgets('J rebuild, resize, inspection, and comparison write nothing',
      (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    final before = controller.instrument.cautions.length;
    final signature = controller.instrument.behaviorSignature;
    await tester.pumpWidget(ResearchApp(controller: controller));
    await tester.pump();
    controller.openInspector(InspectorSection.truth);
    controller.setWorkspace(LabWorkspace.compare);
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    await tester.pump();
    await tester.pump();
    expect(controller.instrument.cautions, hasLength(before));
    expect(controller.instrument.sendOffs, isEmpty);
    expect(controller.instrument.behaviorSignature, signature);
    expect(find.text('READ ONLY'), findsOneWidget);
    expect(find.text('ACTIVE INPUT'), findsOneWidget);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('O a certified import is rejected', (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    final before = controller.activeProfile.profileId;
    controller.importProfile(
      _touch('supported').replaceAll(
        '"classification": "illustrative"',
        '"classification": "illustrative", "forrefCertified": true',
      ),
    );
    await tester.pump();
    expect(controller.importAccepted, isFalse);
    expect(controller.activeProfile.profileId, before);
    expect(find.text('Certification: not claimed'), findsOneWidget);
    expect(find.text('FORREF CERTIFIED'), findsNothing);
  });

  testWidgets('P physical calibration without evidence stays uncalibrated',
      (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.setCalibration(CalibrationMode.physical1to1);
    await tester.pump();
    expect(find.text('Calibration: NOT CALIBRATED'), findsOneWidget);
    expect(find.text('Physical fidelity: NOT CALIBRATED'), findsOneWidget);
    expect(find.text('PHYSICAL TARGET SIZE UNKNOWN'), findsOneWidget);
    expect(find.text('Calibration: PHYSICAL_1_TO_1'), findsNothing);
  });

  testWidgets('layout not fit hides action targets', (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.importProfile(_tinyRound);
    controller.show(ResearchPage.yellow);
    await tester.pump();
    expect(find.text('LAYOUT NOT FIT FOR THIS PROFILE'), findsOneWidget);
    expect(find.text('Record yellow'), findsNothing);
    expect(controller.instrument.cautions, isEmpty);
  });

  testWidgets('K L M N focus, direct pathway, officials, and roles',
      (tester) async {
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.openGeometryStage();
    controller.show(ResearchPage.yellow);
    await tester.pump();
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Record yellow')));
    controller.focusLost();
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(controller.instrument.cautions, isEmpty);

    controller.load(ScenarioId.s08DirectRedWithPriorYellow);
    controller.show(ResearchPage.red);
    await tester.pump();
    await tester.tap(find.text('Record sending-off'));
    await tester.pump();
    expect(controller.instrument.sendOffs.single.pathway,
        SendOffPathwayLabel.direct);
    expect(controller.instrument.cautions, hasLength(1));

    controller.load(ScenarioId.s10SimilarOfficials);
    controller.show(ResearchPage.officials);
    await tester.pump();
    expect(find.text('Alex Popescu — assistant coach'), findsOneWidget);
    expect(find.text('Alex Popescu — team doctor'), findsOneWidget);
    expect(controller.instrument.selectedOfficialId, isNull);
    await tester.tap(find.text('Alex Popescu — team doctor'));
    await tester.pump();
    expect(controller.instrument.selectedOfficialId, 'o-alex-doctor');

    controller.load(ScenarioId.s12SubstitutionInFirst);
    controller.show(ResearchPage.substitution);
    await tester.pump();
    await tester.ensureVisible(find.text('In p-home-7'));
    await tester.tap(find.text('In p-home-7'));
    await tester.pump();
    await tester.ensureVisible(find.text('Out p-home-9'));
    await tester.tap(find.text('Out p-home-9'));
    await tester.pump();
    controller.instrument.reorderRoster(['p-home-7', 'p-home-9']);
    await tester.pump();
    expect(controller.instrument.outId, 'p-home-9');
    expect(controller.instrument.inId, 'p-home-7');
    expect(controller.instrument.substitutionRecorded, isFalse);
  });

  testWidgets('comparison keeps one history and one active surface',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ResearchController();
    await tester.pumpWidget(ResearchApp(controller: controller));
    controller.setWorkspace(LabWorkspace.compare);
    await tester.pump();
    // Two factual shells, one presentation runtime, one hf_v2 history.
    expect(find.byType(WatchReferenceApp), findsNWidgets(2));
    expect(find.text('ACTIVE INPUT'), findsOneWidget);
    expect(find.text('READ ONLY'), findsOneWidget);
    expect(controller.compareInputOwnerId, controller.shellProfileId);
    final before = controller.instrument.cautions.length;
    final secondary = controller.compareProfileId;
    await tester.tap(find.byKey(Key('compare-make-active-$secondary')));
    await tester.pump();
    expect(controller.compareInputOwnerId, secondary);
    expect(find.text('ACTIVE INPUT'), findsOneWidget);
    expect(find.text('READ ONLY'), findsOneWidget);
    expect(controller.instrument.cautions, hasLength(before));
    expect(controller.instrument.sendOffs, isEmpty);
  });
}

String _touch(String touch) {
  return '''
{
  "schemaVersion": 1,
  "profileId": "candidate-touch-$touch",
  "displayName": "Candidate touch $touch",
  "deviceClass": "smartwatch",
  "screenShape": "rectangle",
  "classification": "illustrative",
  "logicalViewport": {"width": 200, "height": 240},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "insets", "left": 8, "top": 8, "right": 8, "bottom": 8},
  "edgeClipping": "none",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "$touch",
    "crown": "unknown",
    "physicalButtons": "unknown",
    "rotatingBezel": "unsupported",
    "gestureInput": "unknown",
    "accessibilityInvocation": "unknown"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "FORREF research fixture. Dimensions are illustrative, not a measured product.",
    "observedDate": null,
    "measurementMethod": null
  }
}
''';
}

const _tinyRound = '''
{
  "schemaVersion": 1,
  "profileId": "tiny-round",
  "displayName": "Tiny round",
  "deviceClass": "smartwatch",
  "screenShape": "round",
  "classification": "illustrative",
  "logicalViewport": {"width": 80, "height": 80},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "circularInset", "inset": 4},
  "edgeClipping": "circularMask",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "supported",
    "crown": "unknown",
    "physicalButtons": "unknown",
    "rotatingBezel": "unknown",
    "gestureInput": "unknown",
    "accessibilityInvocation": "unknown"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "FORREF research fixture. Dimensions are illustrative, not a measured product.",
    "observedDate": null,
    "measurementMethod": null
  }
}
''';
