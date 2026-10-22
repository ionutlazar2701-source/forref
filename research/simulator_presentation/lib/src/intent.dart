import 'state.dart';

/// Who asked for the intent. The trace must keep these apart.
enum IntentOrigin { watchUi, mobileUi, operatorFixture }

const String watchUiTraceLabel = 'ACTUAL WATCH UI INTERACTION';

const String mobileUiTraceLabel = 'MOBILE UI ACTION';

const String operatorFixtureTraceLabel = 'OPERATOR FIXTURE ACTION';

String intentOriginLabel(IntentOrigin origin) {
  return switch (origin) {
    IntentOrigin.watchUi => watchUiTraceLabel,
    IntentOrigin.mobileUi => mobileUiTraceLabel,
    IntentOrigin.operatorFixture => operatorFixtureTraceLabel,
  };
}

sealed class WatchIntent {
  const WatchIntent({required this.origin});

  final IntentOrigin origin;

  String get name;
}

final class OpenRouteIntent extends WatchIntent {
  const OpenRouteIntent(this.route, {required super.origin});

  final WatchRoute route;

  @override
  String get name => 'openRoute:${route.name}';
}

final class SetTeamIntent extends WatchIntent {
  const SetTeamIntent(this.team, {required super.origin});

  final PresentationTeam team;

  @override
  String get name => 'setTeam:${team.name}';
}

final class SelectParticipantIntent extends WatchIntent {
  const SelectParticipantIntent(this.participantId, {required super.origin});

  final String participantId;

  @override
  String get name => 'selectParticipant:$participantId';
}

final class SelectOfficialIntent extends WatchIntent {
  const SelectOfficialIntent(this.officialId, {required super.origin});

  final String officialId;

  @override
  String get name => 'selectOfficial:$officialId';
}

final class SetScopeIntent extends WatchIntent {
  const SetScopeIntent(this.scope, {required super.origin});

  final PresentationScope scope;

  @override
  String get name => 'setScope:${scope.name}';
}

final class OfferYellowIntent extends WatchIntent {
  const OfferYellowIntent({required super.origin});

  @override
  String get name => 'offerYellow';
}

final class OfferDirectSendOffIntent extends WatchIntent {
  const OfferDirectSendOffIntent({required super.origin});

  @override
  String get name => 'offerDirectSendOff';
}

final class SelectOutIntent extends WatchIntent {
  const SelectOutIntent(this.participantId, {required super.origin});

  final String participantId;

  @override
  String get name => 'selectOut:$participantId';
}

final class SelectInIntent extends WatchIntent {
  const SelectInIntent(this.participantId, {required super.origin});

  final String participantId;

  @override
  String get name => 'selectIn:$participantId';
}

/// Requests an already-offered final action.
///
/// The runtime must refuse this when the action is not eligible. It must not
/// append a caution, send-off, or substitution by itself.
final class ActivateIntent extends WatchIntent {
  const ActivateIntent(this.action, {required super.origin});

  final PresentationAction action;

  @override
  String get name => 'activate:${action.name}';
}

final class ResolveSimulatedCommitIntent extends WatchIntent {
  const ResolveSimulatedCommitIntent({required super.origin});

  @override
  String get name => 'resolveSimulatedCommit';
}

final class AcknowledgeUnknownIntent extends WatchIntent {
  const AcknowledgeUnknownIntent({required super.origin});

  @override
  String get name => 'acknowledgeUnknown';
}

final class FocusLostIntent extends WatchIntent {
  const FocusLostIntent({required super.origin});

  @override
  String get name => 'focusLost';
}

final class CancelForDeviceChangeIntent extends WatchIntent {
  const CancelForDeviceChangeIntent(this.profileId, {required super.origin});

  final String profileId;

  @override
  String get name => 'cancelForDeviceChange:$profileId';
}

final class BindProfileIntent extends WatchIntent {
  const BindProfileIntent(this.profileId, {required super.origin});

  final String profileId;

  @override
  String get name => 'bindProfile:$profileId';
}

final class LoadScenarioIntent extends WatchIntent {
  const LoadScenarioIntent(this.scenarioId, {required super.origin});

  final String scenarioId;

  @override
  String get name => 'loadScenario:$scenarioId';
}

final class IntentTraceEntry {
  const IntentTraceEntry({
    required this.sequence,
    required this.origin,
    required this.intentName,
    required this.detail,
  });

  final int sequence;
  final IntentOrigin origin;
  final String intentName;
  final String detail;

  String get originLabel => intentOriginLabel(origin);
}
