import 'package:hf_v2/hf_v2.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

/// Research-only pairing. Not Bluetooth, not cloud, not production sync.
enum SimulatedConnectionState {
  pairActive,
  simulatedDisconnect,
}

/// Lab vocabulary for where a simulated action started.
enum SimulatedActionOrigin {
  mobileUi,
  watchUi,
  operatorFixture,
  sandboxTool,
  systemScenario,
}

extension SimulatedActionOriginLabel on SimulatedActionOrigin {
  String get label => switch (this) {
        SimulatedActionOrigin.mobileUi => 'MOBILE UI',
        SimulatedActionOrigin.watchUi => 'WATCH UI',
        SimulatedActionOrigin.operatorFixture => 'OPERATOR FIXTURE',
        SimulatedActionOrigin.sandboxTool => 'SANDBOX TOOL',
        SimulatedActionOrigin.systemScenario => 'SYSTEM SCENARIO',
      };
}

SimulatedActionOrigin originFromIntent(IntentOrigin origin) => switch (origin) {
      IntentOrigin.mobileUi => SimulatedActionOrigin.mobileUi,
      IntentOrigin.watchUi => SimulatedActionOrigin.watchUi,
      IntentOrigin.operatorFixture => SimulatedActionOrigin.operatorFixture,
    };

/// Deterministic research fixture for paired sessions. Not Match Memory.
final class ResearchFixture {
  const ResearchFixture({
    required this.matchName,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.phaseLabel,
    required this.clockLabel,
    required this.scenarioId,
    required this.watchProfileId,
    required this.phoneProfileId,
  });

  final String matchName;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String phaseLabel;
  final String clockLabel;
  final ScenarioId scenarioId;
  final String watchProfileId;
  final String phoneProfileId;

  static const defaults = ResearchFixture(
    matchName: 'Research Match',
    homeTeam: 'Home',
    awayTeam: 'Away',
    homeScore: 0,
    awayScore: 0,
    phaseLabel: '2nd half',
    clockLabel: '67:12',
    scenarioId: ScenarioId.s01YellowNoPrior,
    watchProfileId: 'huawei-watch-gt4-46',
    phoneProfileId: 'research-mobile-pane',
  );

  ResearchFixture copyWith({
    String? matchName,
    String? homeTeam,
    String? awayTeam,
    int? homeScore,
    int? awayScore,
    String? phaseLabel,
    String? clockLabel,
    ScenarioId? scenarioId,
    String? watchProfileId,
    String? phoneProfileId,
  }) {
    return ResearchFixture(
      matchName: matchName ?? this.matchName,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      phaseLabel: phaseLabel ?? this.phaseLabel,
      clockLabel: clockLabel ?? this.clockLabel,
      scenarioId: scenarioId ?? this.scenarioId,
      watchProfileId: watchProfileId ?? this.watchProfileId,
      phoneProfileId: phoneProfileId ?? this.phoneProfileId,
    );
  }
}

/// One coherent paired lab view over the same research runtime.
final class PairedSessionState {
  const PairedSessionState({
    required this.fixture,
    required this.connection,
    required this.lastOrigin,
    required this.lastIntentName,
    required this.mobileUpdated,
    required this.watchUpdated,
    required this.propagationNote,
  });

  final ResearchFixture fixture;
  final SimulatedConnectionState connection;
  final SimulatedActionOrigin? lastOrigin;
  final String? lastIntentName;
  final bool mobileUpdated;
  final bool watchUpdated;
  final String propagationNote;

  static PairedSessionState initial(ResearchFixture fixture) {
    return PairedSessionState(
      fixture: fixture,
      connection: SimulatedConnectionState.pairActive,
      lastOrigin: null,
      lastIntentName: null,
      mobileUpdated: true,
      watchUpdated: true,
      propagationNote: 'SHARED MATCH STATE · SIMULATED PAIR',
    );
  }

  PairedSessionState afterIntent({
    required SimulatedActionOrigin origin,
    required String intentName,
  }) {
    return PairedSessionState(
      fixture: fixture,
      connection: connection,
      lastOrigin: origin,
      lastIntentName: intentName,
      mobileUpdated: true,
      watchUpdated: true,
      propagationNote: switch (origin) {
        SimulatedActionOrigin.mobileUi => 'MOBILE → WATCH · presentation updated',
        SimulatedActionOrigin.watchUi => 'WATCH → MOBILE · presentation updated',
        SimulatedActionOrigin.operatorFixture =>
          'OPERATOR FIXTURE · both surfaces refreshed',
        SimulatedActionOrigin.sandboxTool =>
          'SANDBOX TOOL · journal only · not watch-originated',
        SimulatedActionOrigin.systemScenario =>
          'SYSTEM SCENARIO · fixture loaded',
      },
    );
  }
}
