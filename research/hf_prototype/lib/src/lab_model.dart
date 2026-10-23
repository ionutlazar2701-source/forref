import 'lab_theme.dart';

/// Primary workspaces from John Design Authority V1.
///
/// A workspace is composition only. Changing it never writes a research
/// record, changes the selected participant, or resolves an in-flight command.
enum LabWorkspace { focus, commandLab, compare, matchBuilder }

/// Secondary inspector sections. They read the loaded simulation.
enum InspectorSection { truth, eventJournal, deviceEvidence }

/// Which runtime the lab chrome names. Research is hf_v2. Integration Sandbox
/// is the file-backed SQLite session. Neither label upgrades the other.
enum LabRuntime { research, integrationSandbox }

/// Window regime for the responsive composition.
enum LabLayoutRegime { wide, desktop, compact, narrow }

LabLayoutRegime labRegimeFor(double width) {
  if (width >= LabMetrics.wideBreakpoint) return LabLayoutRegime.wide;
  if (width >= LabMetrics.desktopBreakpoint) return LabLayoutRegime.desktop;
  if (width >= LabMetrics.compactBreakpoint) return LabLayoutRegime.compact;
  return LabLayoutRegime.narrow;
}

extension LabWorkspaceLabel on LabWorkspace {
  String get label => switch (this) {
        LabWorkspace.focus => 'Simulation',
        LabWorkspace.commandLab => 'Command Lab',
        LabWorkspace.compare => 'Device Compare',
        LabWorkspace.matchBuilder => 'Match Builder',
      };

  String get question => switch (this) {
        LabWorkspace.focus =>
          'Paired mobile and watch research surfaces over one deterministic match state.',
        LabWorkspace.commandLab =>
          'Repeatable synthetic scenarios while the watch remains the interaction surface.',
        LabWorkspace.compare =>
          'One active input · identical research presentation · no cross-device pointer replay.',
        LabWorkspace.matchBuilder =>
          'Bootstrap a deterministic research fixture for the paired lab. Not authoritative.',
      };
}

extension InspectorSectionLabel on InspectorSection {
  String get label => switch (this) {
        InspectorSection.truth => 'Truth',
        InspectorSection.eventJournal => 'Event Journal',
        InspectorSection.deviceEvidence => 'Device Evidence',
      };
}

extension LabRuntimeLabel on LabRuntime {
  String get label => switch (this) {
        LabRuntime.research => 'Research',
        LabRuntime.integrationSandbox => 'Integration Sandbox',
      };

  String get footer => switch (this) {
        LabRuntime.research => 'REFERENCE UI · RESEARCH MODE',
        LabRuntime.integrationSandbox => 'REFERENCE UI · INTEGRATION SANDBOX',
      };
}

/// Origin vocabulary used on every operator control. Watch taps are traced by
/// the presentation runtime as ACTUAL WATCH UI INTERACTION.
const operatorFixtureOriginLabel = 'OPERATOR FIXTURE ACTION';
const watchUiOriginLabel = 'ACTUAL WATCH UI INTERACTION';
const sandboxOriginLabel = 'INTEGRATION SANDBOX ACTION';

/// Bounded synthetic match summary. S2.4 owns a real match builder.
const researchMatchTitle = 'Research Match';
const matchBuilderWaveLabel = 'MATCH BUILDER — S2.4';
