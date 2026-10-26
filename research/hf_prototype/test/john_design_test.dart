import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_presentation/simulator_presentation.dart';
import 'package:simulator_sandbox/simulator_sandbox.dart';
import 'package:watch_reference_ui/watch_reference_ui.dart';

import 'lab_support.dart';

/// S2.3.5 John Design Integration gates.
///
/// Composition changes must write nothing. The watch is the only interaction
/// surface for sporting capture. Research and Integration Sandbox stay apart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReadableFonts);

  group('default launch', () {
    testWidgets('the device is the hero and complexity is on demand', (tester) async {
      final controller = await pumpLab(tester, size: const Size(1440, 900));
      expect(controller.workspace, LabWorkspace.focus);
      expect(controller.inspectorOpen, isFalse);
      expect(controller.deviceShellVisible, isTrue);
      expect(controller.shellProfileId, 'huawei-watch-gt4-46');
      expect(controller.watchRuntime.watchState.profileId, 'huawei-watch-gt4-46');
      expect(find.byType(WatchReferenceApp), findsOneWidget);
      expect(find.byKey(const Key('focus-stage')), findsOneWidget);
      // Calm chrome: match, device, runtime, inspector control, identity.
      expect(find.byKey(const Key('top-match')), findsOneWidget);
      expect(find.text('Research Match'), findsWidgets);
      expect(find.byKey(const Key('device-summary')), findsOneWidget);
      expect(find.text('Research'), findsOneWidget);
      expect(find.text('RESEARCH / NON-PRODUCTION'), findsOneWidget);
      // Nothing permanent that belongs to an engineering console.
      expect(find.textContaining('SHA '), findsNothing);
      expect(find.text('huawei-watch-gt4-46'), findsNothing);
      expect(find.text('SCENARIO'), findsNothing);
      expect(find.byKey(const Key('research-operator')), findsNothing);
      expect(find.byKey(const Key('lab-inspector')), findsNothing);
      expect(find.byKey(const Key('evidence-stamp')), findsNothing);
      expect(find.text('DIAGNOSTIC VIEWPORT'), findsNothing);
      expect(find.byKey(const Key('research-capture')), findsNothing);
      // Only the computed stage is shown. No fabricated tier.
      expect(find.textContaining('PROFILED'), findsWidgets);
      expect(find.textContaining('SIMULATION READY'), findsNothing);
      expect(find.textContaining('PLATFORM PROVEN'), findsNothing);
      expect(find.textContaining('FORREF CERTIFIED'), findsNothing);
      // The honest fidelity line stays one glance away, under the stage.
      final fidelity = tester.widget<Text>(find.byKey(const Key('stage-fidelity')));
      expect(fidelity.data, contains('SCHEMATIC SHELL'));
      expect(fidelity.data, contains('APERTURE NOT MEASURED'));
      expect(fidelity.data, contains('UNCALIBRATED VIEW'));
      expect(fidelity.data, contains('466 × 466'));
    });
  });

  group('workspace navigation', () {
    testWidgets('switching workspaces and inspector sections writes nothing', (tester) async {
      final controller = await pumpLab(tester);
      controller.load(ScenarioId.s09Home14ThenAway14);
      await tester.pump();
      final signature = controller.instrument.behaviorSignature;
      final subject = controller.instrument.snapshot.selectedSubjectId;
      for (final workspace in LabWorkspace.values) {
        await openWorkspace(tester, workspace);
        expect(controller.workspace, workspace);
        for (final section in InspectorSection.values) {
          await openInspectorTab(tester, section);
          expect(controller.inspector, section);
        }
        await tester.tap(find.byKey(const Key('inspector-close')));
        await tester.pump();
        expect(controller.inspectorOpen, isFalse);
      }
      expect(controller.instrument.behaviorSignature, signature);
      expect(controller.instrument.snapshot.selectedSubjectId, subject);
      expect(controller.instrument.cautions, isEmpty);
      expect(controller.instrument.snapshot.inFlight, isNull);
      expect(controller.sandboxSession, isNull);
      expect(controller.instrument.productionMatchMemoryWrites, isFalse);
    });

    testWidgets('the inspector toggle opens Truth and closes again', (tester) async {
      final controller = await pumpLab(tester);
      await tester.tap(find.byKey(const Key('inspector-toggle')));
      await tester.pump();
      expect(controller.inspector, InspectorSection.truth);
      expect(find.byKey(const Key('truth-inspector')), findsOneWidget);
      expect(find.text('ESTABLISHED'), findsOneWidget);
      expect(find.text('IN-FLIGHT / UNFINISHED'), findsOneWidget);
      expect(find.text('VISIBLE ON DEVICE'), findsOneWidget);
      expect(find.text('SAFETY / CONTEXT'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inspector-toggle')));
      await tester.pump();
      expect(controller.inspectorOpen, isFalse);
      expect(find.byKey(const Key('truth-inspector')), findsNothing);
    });
  });

  group('device selector', () {
    testWidgets('cards show facts only and switch the shell without writing', (tester) async {
      final controller = await pumpLab(tester);
      controller.load(ScenarioId.s02YellowOnePrior);
      await tester.pump();
      final before = controller.instrument.cautions.length;
      await tester.tap(find.byKey(const Key('device-summary')));
      await tester.pump();
      expect(find.byKey(const Key('device-selector')), findsOneWidget);
      for (final id in [
        'amazfit-gts4',
        'huawei-watch-gt4-46',
        'apple-watch-series9-45',
        'garmin-approach-s60',
      ]) {
        expect(find.byKey(Key('device-card-$id')), findsOneWidget);
      }
      final selector = find.byKey(const Key('device-selector'));
      expect(find.descendant(of: selector, matching: find.text('PROFILED')), findsNWidgets(4));
      expect(find.descendant(of: selector, matching: find.text('SELECTED')), findsOneWidget);
      expect(find.descendant(of: selector, matching: find.textContaining('RASTER UNKNOWN')), findsNWidgets(2));
      expect(find.descendant(of: selector, matching: find.textContaining('shape unknown')), findsOneWidget);
      expect(find.descendant(of: selector, matching: find.textContaining('390 × 450')), findsOneWidget);
      expect(find.descendant(of: selector, matching: find.textContaining('SIMULATION READY')), findsNothing);
      expect(find.descendant(of: selector, matching: find.textContaining('PLATFORM PROVEN')), findsNothing);

      await tester.tap(find.byKey(const Key('device-card-amazfit-gts4')));
      await tester.pump();
      expect(controller.deviceSelectorOpen, isFalse);
      expect(find.byKey(const Key('device-selector')), findsNothing);
      expect(controller.shellProfileId, 'amazfit-gts4');
      expect(controller.watchRuntime.watchState.profileId, 'amazfit-gts4');
      expect(find.byType(WatchReferenceApp), findsOneWidget);
      expect(controller.instrument.cautions, hasLength(before));
      final model = tester.widget<Text>(find.byKey(const Key('device-summary-model')));
      expect(model.data, 'GTS 4');
      // The old Compare partner collided with the new shell and was moved.
      expect(controller.compareProfileId, isNot('amazfit-gts4'));
    });

    testWidgets('the scrim closes the selector without selecting', (tester) async {
      final controller = await pumpLab(tester);
      await tester.tap(find.byKey(const Key('device-summary')));
      await tester.pump();
      await tester.tapAt(const Offset(20, 900));
      await tester.pump();
      expect(controller.deviceSelectorOpen, isFalse);
      expect(controller.shellProfileId, 'huawei-watch-gt4-46');
    });
  });

  group('compare', () {
    testWidgets('one input owner; the mirror ignores pointers; switching cancels a press',
        (tester) async {
      final controller = await pumpLab(tester, size: const Size(1440, 900));
      await openWorkspace(tester, LabWorkspace.compare);
      expect(find.byType(WatchReferenceApp), findsNWidgets(2));
      expect(find.text('ACTIVE INPUT'), findsOneWidget);
      expect(find.text('READ ONLY'), findsOneWidget);
      final active = find.byKey(const Key('watch-huawei-watch-gt4-46-active'));
      final mirror = find.byKey(const Key('watch-amazfit-gts4-mirror'));
      expect(active, findsOneWidget);
      expect(mirror, findsOneWidget);

      // A tap on the mirror's Capture does nothing.
      final mirrorCapture = find.descendant(of: mirror, matching: find.text('Capture'));
      await tester.tap(mirrorCapture, warnIfMissed: false);
      await tester.pump();
      expect(controller.watchRuntime.watchState.navigation.route, WatchRoute.liveCore);

      // The same tap on the active device moves both shells to the same route.
      await tester.tap(
        find.descendant(of: active, matching: find.byKey(const Key('watch-capture-ring'))),
      );
      await tester.pump();
      expect(controller.watchRuntime.watchState.navigation.route, WatchRoute.captureMenu);
      expect(find.descendant(of: mirror, matching: find.text('Yellow')), findsOneWidget);
      expect(find.descendant(of: active, matching: find.text('Yellow')), findsOneWidget);
      expect(controller.watchRuntime.intentTrace.last.origin, IntentOrigin.watchUi);

      // Switching the owner during a held press cancels it; nothing commits.
      await tester.tap(find.descendant(of: active, matching: find.text('Yellow')));
      await tester.pump();
      await syncWatchYellowFlow(controller);
      await tester.pump();
      await controller.dispatchWatch(
        const SelectParticipantIntent('p-home-14',
            origin: IntentOrigin.watchUi),
      );
      await tester.pump();
      await tester.pump();
      final record = find.descendant(of: active, matching: find.text('Record yellow'));
      await tester.ensureVisible(record);
      final gesture = await tester.startGesture(tester.getCenter(record));
      await tester.pump();
      await tester.tap(find.byKey(const Key('compare-make-active-amazfit-gts4')));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(controller.compareInputOwnerId, 'amazfit-gts4');
      expect(controller.instrument.snapshot.inFlight, isNull);
      expect(controller.instrument.cautions, isEmpty);
      expect(find.text('ACTIVE INPUT'), findsOneWidget);
      expect(find.text('READ ONLY'), findsOneWidget);
      expect(find.byKey(const Key('watch-amazfit-gts4-active')), findsOneWidget);
      expect(find.byKey(const Key('watch-huawei-watch-gt4-46-mirror')), findsOneWidget);
    });

    testWidgets('narrow compare shows one device and never two active inputs', (tester) async {
      final controller = await pumpLab(tester, size: const Size(760, 900));
      await openWorkspace(tester, LabWorkspace.compare);
      expect(find.byType(WatchReferenceApp), findsOneWidget);
      expect(find.text('ACTIVE INPUT'), findsOneWidget);
      expect(find.text('READ ONLY'), findsNothing);
      await tester.tap(find.byKey(const Key('compare-switch-narrow')));
      await tester.pump();
      expect(controller.compareInputOwnerId, 'amazfit-gts4');
      expect(find.byType(WatchReferenceApp), findsOneWidget);
      expect(find.text('ACTIVE INPUT'), findsOneWidget);
    });
  });

  group('watch safety in the hero stage', () {
    testWidgets('Yellow from the watch is SIMULATED SAVED and never sandbox D1', (tester) async {
      final controller = await pumpLab(tester, size: const Size(1440, 900));
      await selectDevice(tester, 'amazfit-gts4');
      await tapWatch(tester, 'Capture');
      await tester.pump();
      await tapWatch(tester, 'Yellow');
      await tester.pump();
      await syncWatchYellowFlow(controller);
      await tester.pump();
      await controller.dispatchWatch(
        const SelectParticipantIntent('p-home-14',
            origin: IntentOrigin.watchUi),
      );
      await tester.pump();
      controller.focusLost();
      await tester.pump();
      await controller.dispatchWatch(
        const ActivateIntent(PresentationAction.yellow,
            origin: IntentOrigin.watchUi),
      );
      await tester.pump();
      expect(controller.instrument.snapshot.inFlight, isNull);
      expect(controller.instrument.cautions, hasLength(1));
      expect(controller.instrument.cautions.single.subjectId, 'p-home-14');
      expect(controller.instrument.sendOffs, isEmpty);
      final label = tester.widget<Text>(find.byKey(const Key('outcome-label')));
      expect(label.data, ResearchCommitPhrases.simulatedSaved);
      expect(label.data, contains('not production D1'));
      final origin = tester.widget<Text>(find.byKey(const Key('intent-origin-trace')));
      expect(origin.data, contains('ACTUAL WATCH UI INTERACTION'));
      expect(find.textContaining(sandboxCommittedLabel), findsNothing);
      expect(controller.sandboxSession, isNull);
      expect(controller.runtime, LabRuntime.research);
      expect(controller.instrument.productionMatchMemoryWrites, isFalse);
    });

    testWidgets('a rapid repeat after the second caution records no send-off', (tester) async {
      final controller = await pumpLab(tester, size: const Size(1440, 900));
      await openWorkspace(tester, LabWorkspace.commandLab);
      await controller.operatorLoadScenario(ScenarioId.s07RapidRepeatAfterY2);
      await tester.pump();
      expect(controller.instrument.cautions, hasLength(1));
      await tapWatch(tester, 'Capture');
      await tester.pump();
      await tapWatch(tester, 'Yellow');
      await tester.pump();
      await syncWatchYellowFlow(controller);
      await tester.pump();
      await controller.dispatchWatch(
        const SelectParticipantIntent('p-home-9', origin: IntentOrigin.watchUi),
      );
      await tester.pump();
      await tester.pump();
      final record = find.text('Record yellow');
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pump();
      expect(controller.instrument.cautions, hasLength(2));
      expect(controller.instrument.sendOffs, isEmpty);
      // The finger taps the same place again.
      if (find.text('Record yellow').evaluate().isNotEmpty) {
        await tester.tap(find.text('Record yellow'), warnIfMissed: false);
        await tester.pump();
      }
      expect(controller.instrument.sendOffs, isEmpty);
      await openInspectorTab(tester, InspectorSection.truth);
      expect(inTruthInspector(find.text('Two cautions recorded')), findsOneWidget);
      expect(inTruthInspector(find.text('Sending-off recorded')), findsNothing);
    });

    testWidgets('a regime change during a press invalidates it', (tester) async {
      final controller = await pumpLab(tester, size: const Size(1440, 900));
      await tapWatch(tester, 'Capture');
      await tester.pump();
      await tapWatch(tester, 'Yellow');
      await tester.pump();
      await syncWatchYellowFlow(controller);
      await tester.pump();
      await controller.dispatchWatch(
        const SelectParticipantIntent('p-home-14',
            origin: IntentOrigin.watchUi),
      );
      await tester.pump();
      await tester.pump();
      final record = find.text('Record yellow');
      await tester.ensureVisible(record);
      final epoch = controller.inputEpoch;
      final gesture = await tester.startGesture(tester.getCenter(record));
      await tester.pump();
      await tester.binding.setSurfaceSize(const Size(900, 700));
      await tester.pump();
      await tester.pump();
      expect(controller.layoutEpoch, 1);
      expect(controller.inputEpoch, greaterThan(epoch));
      await gesture.up();
      await tester.pump();
      expect(controller.instrument.snapshot.inFlight, isNull);
      expect(controller.instrument.cautions, isEmpty);
      expect(controller.instrument.snapshot.selectedSubjectId, 'p-home-14');
    });

    testWidgets('losing window focus during a press records nothing', (tester) async {
      final controller = await pumpLab(tester, size: const Size(1440, 900));
      await tapWatch(tester, 'Capture');
      await tester.pump();
      await tapWatch(tester, 'Yellow');
      await tester.pump();
      await syncWatchYellowFlow(controller);
      await tester.pump();
      await controller.dispatchWatch(
        const SelectParticipantIntent('p-home-14',
            origin: IntentOrigin.watchUi),
      );
      await tester.pump();
      await tester.pump();
      final record = find.text('Record yellow');
      await tester.ensureVisible(record);
      final gesture = await tester.startGesture(tester.getCenter(record));
      controller.focusLost();
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(controller.instrument.snapshot.inFlight, isNull);
      expect(controller.instrument.cautions, isEmpty);
    });
  });

  group('event journal', () {
    testWidgets('with no sandbox action every causal stage is NOT OBSERVED', (tester) async {
      final controller = await pumpLab(tester);
      await openInspectorTab(tester, InspectorSection.eventJournal);
      expect(find.byKey(const Key('event-journal')), findsOneWidget);
      for (final kind in JournalEventKind.values) {
        final status = tester.widget<Text>(find.byKey(Key('stage-${kind.name}')));
        expect(status.data, 'NOT OBSERVED', reason: kind.name);
      }
      expect(find.text('No sandbox capture observed'), findsOneWidget);
      expect(find.byKey(const Key('journal-origin-warning')), findsOneWidget);
      expect(find.textContaining('DESKTOP SANDBOX MEASUREMENT'), findsOneWidget);
      expect(find.textContaining(sandboxCommittedLabel), findsNothing);
      expect(controller.sandboxSession, isNull);
    });

    testWidgets('a watch Yellow does not light a sandbox stage', (tester) async {
      final controller = await pumpLab(tester);
      await tapWatch(tester, 'Capture');
      await tester.pump();
      await tapWatch(tester, 'Yellow');
      await tester.pump();
      await syncWatchYellowFlow(controller);
      await tester.pump();
      await controller.dispatchWatch(
        const SelectParticipantIntent('p-home-14',
            origin: IntentOrigin.watchUi),
      );
      await tester.pump();
      await tester.pump();
      final record = find.text('Record yellow');
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pump();
      expect(controller.instrument.cautions, hasLength(1));
      await openInspectorTab(tester, InspectorSection.eventJournal);
      for (final kind in JournalEventKind.values) {
        final status = tester.widget<Text>(find.byKey(Key('stage-${kind.name}')));
        expect(status.data, 'NOT OBSERVED', reason: kind.name);
      }
      final research = tester.widget<Text>(find.byKey(const Key('journal-research-commit')));
      expect(research.data, ResearchCommitPhrases.simulatedSaved);
      expect(find.text('RESEARCH WATCH PATH · hf_v2 · NOT SQLITE D1'), findsOneWidget);
      expect(controller.runtime, LabRuntime.research);
      final footer = tester.widget<Text>(find.byKey(const Key('footer-runtime')));
      expect(footer.data, 'REFERENCE UI · RESEARCH MODE');
    });

    testWidgets('a seeded sandbox snapshot derives stages only from observed lines', (tester) async {
      final controller = await pumpLab(tester);
      controller.showJournalSnapshot(
        headline: 'Event Journal · seeded',
        detail: 'partial journal',
        lines: const [
          '1 intentReceived yellow sim-p-14 intent x',
          '2 commandFrozen yellow sim-p-14 match',
          '3 captureAdmissionStarted YellowCaptureIntentFirstAdmission',
          '4 commitRequested sim-yellow-x',
          '5 commitReturned DurableCommitFailure injected',
        ],
      );
      await tester.pump();
      expect(controller.inspector, InspectorSection.eventJournal);
      String status(JournalEventKind kind) =>
          tester.widget<Text>(find.byKey(Key('stage-${kind.name}'))).data!;
      expect(status(JournalEventKind.intentReceived), 'OBSERVED');
      expect(status(JournalEventKind.commitRequested), 'OBSERVED');
      expect(status(JournalEventKind.commitReturned), 'OBSERVED · FAILED');
      expect(status(JournalEventKind.recordReadBack), 'NOT OBSERVED');
      expect(status(JournalEventKind.projectionRebuilt), 'NOT OBSERVED');
      expect(status(JournalEventKind.presentationUpdated), 'NOT OBSERVED');
      expect(controller.runtime, LabRuntime.integrationSandbox);
      expect(find.text('Integration Sandbox'), findsOneWidget);
    });
  });

  group('device evidence', () {
    testWidgets('unknown facts stay UNKNOWN and no tier is fabricated', (tester) async {
      final controller = await pumpLab(tester);
      await selectDevice(tester, 'apple-watch-series9-45');
      await tester.tap(find.byKey(const Key('view-device-evidence')));
      await tester.pump();
      expect(controller.inspector, InspectorSection.deviceEvidence);
      for (final group in ['IDENTITY', 'DISPLAY', 'CASE', 'INPUT', 'FIDELITY', 'PROVENANCE']) {
        expect(find.byKey(Key('evidence-group-$group')), findsOneWidget);
      }
      String value(String group, String label) =>
          tester.widget<Text>(find.byKey(Key('evidence-value-$group-$label'))).data!;
      expect(value('DISPLAY', 'Raster width'), 'UNKNOWN');
      expect(value('DISPLAY', 'Raster height'), 'UNKNOWN');
      expect(value('DISPLAY', 'Safe area'), 'UNKNOWN');
      expect(value('DISPLAY', 'Shell aperture'), 'UNKNOWN');
      expect(value('FIDELITY', 'Evidence stage'), 'PROFILED');
      expect(value('FIDELITY', 'PLATFORM PROVEN'), 'NOT ESTABLISHED');
      expect(value('FIDELITY', 'FORREF CERTIFIED'), 'NOT ESTABLISHED');
      expect(find.textContaining('SIMULATION READY'), findsNothing);

      await selectDevice(tester, 'garmin-approach-s60');
      await tester.pump();
      expect(value('CASE', 'Case width'), 'UNKNOWN');
      expect(value('DISPLAY', 'Shape'), 'UNKNOWN');
      expect(value('DISPLAY', 'Raster width'), 'UNKNOWN');

      await selectDevice(tester, 'huawei-watch-gt4-46');
      await tester.pump();
      expect(value('DISPLAY', 'Raster width'), '466 px');
      expect(value('DISPLAY', 'Shape'), 'round');
      expect(value('DISPLAY', 'Safe area'), 'UNKNOWN');
      expect(value('DISPLAY', 'Shell aperture'), 'UNKNOWN');
    });
  });

  group('match builder placeholder', () {
    testWidgets('S2.4 placeholder navigates sections and creates nothing', (tester) async {
      final controller = await pumpLab(tester);
      final signature = controller.instrument.behaviorSignature;
      await openWorkspace(tester, LabWorkspace.matchBuilder);
      expect(find.text('MATCH BUILDER — S2.4'), findsOneWidget);
      expect(find.text('NON-AUTHORITATIVE · NO RECORDS'), findsOneWidget);
      for (final step in ['match', 'teamsAndSquads', 'officialsAndCrew', 'format', 'review']) {
        await tester.tap(find.byKey(Key('builder-step-$step')));
        await tester.pump();
        expect(find.byKey(Key('builder-detail-$step')), findsOneWidget);
      }
      expect(find.text('REVIEW'), findsNWidgets(2));
      // Honest negations ("is not Saved") are allowed. A success state is not.
      expect(find.text('Saved'), findsNothing);
      expect(find.textContaining('SAVED'), findsNothing);
      expect(find.textContaining('Match created'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byKey(const Key('builder-reserved-note')), findsOneWidget);
      expect(controller.instrument.behaviorSignature, signature);
      expect(controller.sandboxSession, isNull);
      expect(controller.instrument.productionMatchMemoryWrites, isFalse);
    });
  });

  group('responsive regimes', () {
    for (final width in [1600.0, 1440.0, 1280.0, 1100.0, 900.0, 760.0]) {
      testWidgets('every workspace lays out at $width without overflow', (tester) async {
        final controller = await pumpLab(tester, size: Size(width, 900));
        controller.load(ScenarioId.s09Home14ThenAway14);
        for (final workspace in LabWorkspace.values) {
          controller.setWorkspace(workspace);
          await tester.pump();
          expect(find.text('RESEARCH / NON-PRODUCTION'), findsOneWidget, reason: '$workspace');
          if (workspace == LabWorkspace.commandLab) {
            if (width >= 1100) {
              expect(find.byKey(const Key('research-operator')), findsOneWidget);
              expect(find.byKey(const Key('commands-drawer-button')), findsNothing);
            } else {
              expect(find.byKey(const Key('research-operator')), findsNothing);
              await tester.tap(find.byKey(const Key('commands-drawer-button')));
              await tester.pump();
              expect(find.byKey(const Key('research-operator')), findsOneWidget);
              expect(find.text('SCENARIO'), findsOneWidget);
              await tester.tap(find.byKey(const Key('commands-drawer-close')));
              await tester.pump();
              expect(find.byKey(const Key('research-operator')), findsNothing);
            }
          }
          if (workspace == LabWorkspace.compare) {
            expect(find.text('ACTIVE INPUT'), findsOneWidget);
            expect(find.byType(WatchReferenceApp), findsNWidgets(width < 800 ? 1 : 2));
          }
          for (final section in InspectorSection.values) {
            controller.openInspector(section);
            await tester.pump();
            expect(find.byKey(const Key('lab-inspector')), findsOneWidget);
          }
          controller.closeInspector();
          await tester.pump();
        }
        controller.setDeviceSelectorOpen(true);
        await tester.pump();
        expect(find.byKey(const Key('device-selector')), findsOneWidget);
        controller.setDeviceSelectorOpen(false);
        controller.openGeometryStage();
        controller.setWorkspace(LabWorkspace.focus);
        await tester.pump();
        expect(find.byKey(const Key('research-capture')), findsOneWidget);
        expect(controller.instrument.cautions, isEmpty);
        expect(controller.instrument.snapshot.selectedSubjectId, 'p-home-14');
      });
    }

    testWidgets('narrow windows use the workspace dropdown', (tester) async {
      final controller = await pumpLab(tester, size: const Size(760, 900));
      expect(find.byKey(const Key('workspace-dropdown')), findsOneWidget);
      expect(find.byKey(const Key('workspace-focus')), findsNothing);
      await tester.tap(find.byKey(const Key('workspace-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Match Builder').last);
      await tester.pumpAndSettle();
      expect(controller.workspace, LabWorkspace.matchBuilder);
      expect(find.text('MATCH BUILDER — S2.4'), findsOneWidget);
    });
  });
}
