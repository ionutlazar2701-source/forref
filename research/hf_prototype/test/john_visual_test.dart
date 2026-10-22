import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hf_prototype/research_app.dart';
import 'package:hf_v2/hf_v2.dart';

import 'lab_support.dart';

/// S2.3.5 visual evidence. 1440 x 900, the John V1 reference width.
///
/// Every frame carries an evidence stamp in the footer and a manifest row:
/// SHA, workspace, profile, runtime, scenario, fidelity. Desktop captures
/// only. Not Windows evidence. Not device evidence.
void main() {
  testWidgets('capture the John V1 lab', (tester) async {
    await loadReadableFonts();
    final sha = headSha();
    final manifest = <Map<String, Object?>>[];
    final controller = await pumpLab(tester, size: const Size(1440, 900));

    Future<void> shot(String name, {required String scenario, String? note}) async {
      final profile = controller.deviceShellVisible ? controller.shellProfileId : 'none';
      final stamp = 'SHA $sha | workspace ${controller.workspace.name} | profileId $profile | '
          'runtime ${controller.runtime.label} | scenario $scenario | fidelity schematic shell · desktop capture';
      controller.setEvidenceStamp(stamp);
      await tester.pump();
      // Let Material colour transitions finish so labels are legible.
      await tester.pump(const Duration(milliseconds: 400));
      final path = await captureLab(tester, name);
      manifest.add({
        'file': '$name.png',
        'sha': sha,
        'workspace': controller.workspace.name,
        'profileId': profile,
        'runtime': controller.runtime.label,
        'scenario': scenario,
        'fidelity': 'schematic shell · aperture not measured · desktop capture 1440x900',
        'inspector': controller.inspector?.name,
        'watchCommit': controller.watchRuntime.watchState.commit.label,
        'cautions': controller.instrument.cautions.length,
        'sendOffs': controller.instrument.sendOffs.length,
        if (note != null) 'note': note,
        'path': path,
      });
    }

    // 01 Focus: the default launch. Device is the hero.
    await shot('01-john-focus', scenario: controller.instrument.scenarioId.name,
        note: 'default launch, inspector closed');

    // 02 Device selector over the factual catalog.
    controller.setDeviceSelectorOpen(true);
    await shot('02-john-device-selector', scenario: controller.instrument.scenarioId.name,
        note: 'four seed profiles, PROFILED only, RASTER UNKNOWN where unknown');
    controller.setDeviceSelectorOpen(false);

    // 03 Command Lab with an operator fixture action traced separately.
    controller.setWorkspace(LabWorkspace.commandLab);
    await tester.pump();
    await tester.tap(find.text('Operator fixture: yellow Home 14'));
    await tester.pump();
    await shot('03-john-command-lab', scenario: controller.instrument.scenarioId.name,
        note: 'OPERATOR FIXTURE ACTION frozen yellow, rail outside the watch');

    // 04 Compare: one ACTIVE INPUT, one READ ONLY mirror, same state.
    await controller.operatorResolveSimulatedCommit();
    controller.setWorkspace(LabWorkspace.compare);
    await shot('04-john-compare', scenario: controller.instrument.scenarioId.name,
        note: 'Huawei GT 4 active, Amazfit GTS 4 mirror');

    // 05 Truth inspector beside Focus.
    controller.setWorkspace(LabWorkspace.focus);
    controller.openInspector(InspectorSection.truth);
    await shot('05-john-truth-inspector', scenario: controller.instrument.scenarioId.name,
        note: 'ESTABLISHED / IN-FLIGHT / VISIBLE / SAFETY after SIMULATED SAVED');

    // 06 Event Journal with no sandbox action: every stage NOT OBSERVED.
    controller.openInspector(InspectorSection.eventJournal);
    await shot('06-john-event-journal-not-observed', scenario: controller.instrument.scenarioId.name,
        note: 'watch yellow did not light any sandbox stage');

    // 07 Event Journal seeded from a real file-backed sandbox capture.
    final report = _captureReport();
    controller.showJournalSnapshot(
      headline: 'Event Journal · ${report['successLabel']} · ${report['measurement']}',
      detail: 'record ${report['recordId']} bytes ${report['encodedBytes']} '
          'file ${report['fileBytesBefore']}->${report['fileBytesAfter']}',
      lines: (report['successJournal'] as List).cast<String>(),
    );
    await shot('07-john-event-journal-sandbox', scenario: 'sandbox synthetic yellow',
        note: 'INTEGRATION SANDBOX ACTION from capture_report.dart, research path separate');
    controller.leaveSandbox();
    controller.clearSandboxJournal();

    // 08 Device Evidence for the profile with unknown raster.
    controller.openDeviceShell('apple-watch-series9-45');
    controller.openInspector(InspectorSection.deviceEvidence);
    await shot('08-john-device-evidence', scenario: controller.instrument.scenarioId.name,
        note: 'UNKNOWN stays UNKNOWN, PLATFORM PROVEN not established');
    controller.closeInspector();

    // 09 Match Builder placeholder.
    controller.setWorkspace(LabWorkspace.matchBuilder);
    await shot('09-john-match-builder', scenario: controller.instrument.scenarioId.name,
        note: 'S2.4 reserved, non-authoritative');

    // 10 Watch Yellow in Focus on the GTS 4: ACTUAL WATCH UI INTERACTION.
    controller.setWorkspace(LabWorkspace.focus);
    controller.openDeviceShell('amazfit-gts4');
    await controller.operatorLoadScenario(ScenarioId.s01YellowNoPrior);
    await tester.pump();
    await tester.tap(find.text('Capture'));
    await tester.pump();
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    final home14 = find.text('home 14 · p-home-14');
    await tester.ensureVisible(home14);
    await tester.tap(home14);
    await tester.pump();
    final record = find.text('Record yellow');
    await tester.ensureVisible(record);
    await tester.tap(record);
    await tester.pump();
    final resolve = find.text('Resolve simulated outcome');
    await tester.ensureVisible(resolve);
    await tester.tap(resolve);
    await tester.pump();
    expect(controller.instrument.cautions, hasLength(1));
    await shot('10-john-watch-yellow', scenario: ScenarioId.s01YellowNoPrior.name,
        note: 'SIMULATED SAVED — not production D1, ACTUAL WATCH UI INTERACTION');

    // Responsive evidence beyond the reference width.
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pump();
    await tester.pump();
    controller.setWorkspace(LabWorkspace.commandLab);
    controller.setCommandRailOpen(true);
    await shot('11-john-compact-900', scenario: ScenarioId.s01YellowNoPrior.name,
        note: 'compact regime, commands drawer');
    controller.setCommandRailOpen(false);
    await tester.binding.setSurfaceSize(const Size(760, 900));
    await tester.pump();
    await tester.pump();
    controller.setWorkspace(LabWorkspace.compare);
    await shot('12-john-narrow-760', scenario: ScenarioId.s01YellowNoPrior.name,
        note: 'narrow regime, one device at a time');

    final json = const JsonEncoder.withIndent('  ').convert({
      'wave': 'S2.3.5',
      'surface': '1440x900 unless noted',
      'sha': sha,
      'frames': manifest,
    });
    for (final directory in [
      Directory('${Directory.systemTemp.path}${Platform.pathSeparator}forref-sim-v2'),
      Directory('/opt/cursor/artifacts'),
    ]) {
      if (!directory.existsSync()) continue;
      File('${directory.path}${Platform.pathSeparator}john-evidence-manifest.json')
          .writeAsStringSync(json);
    }
  });
}

Map<String, Object?> _captureReport() {
  final result = Process.runSync(
    'dart',
    ['run', 'bin/capture_report.dart'],
    workingDirectory: '../simulator_sandbox',
  );
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}
