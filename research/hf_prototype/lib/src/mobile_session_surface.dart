import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:simulator_presentation/simulator_presentation.dart';

import '../research_app.dart';
import 'lab_theme.dart';
/// Research Mobile Session pane. Not the production phone app.
class MobileSessionSurface extends StatelessWidget {
  const MobileSessionSurface({
    super.key,
    required this.controller,
    required this.compact,
  });

  final ResearchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = controller.watchRuntime.watchState;
    final fixture = controller.paired.fixture;
    final disconnected =
        controller.paired.connection == SimulatedConnectionState.simulatedDisconnect;
    return Material(
      key: const Key('mobile-session'),
      color: LabColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: LabColors.line),
          borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(LabMetrics.gutter),
          child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('FORREF MOBILE SESSION', style: LabText.label),
              const SizedBox(height: 4),
              Text(fixture.matchName,
                  style: LabText.panelTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              _row('Phase', fixture.phaseLabel),
              _row('Time', _timeLine(state, fixture)),
              _row('Score', _scoreLine(state, fixture)),
              Text(
                _scoreLine(state, fixture),
                key: const Key('mobile-score'),
                style: LabText.numeric,
              ),
              const SizedBox(height: 8),
              Text(
                disconnected ? 'SIMULATED DISCONNECT' : 'SIMULATED CONNECTION · PAIR ACTIVE',
                style: LabText.caption.copyWith(
                  color: disconnected ? LabColors.unknownFact : LabColors.steel,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                const Text('Recent research state', style: LabText.caption),
                const SizedBox(height: 4),
                Text(state.commit.label, style: LabText.bodyStrong),
                if (state.frozenCommand != null)
                  Text(
                      'In flight: ${state.frozenCommand!.action.name} '
                      '${state.frozenCommand!.subjectId ?? ''}',
                      style: LabText.caption),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    key: const Key('mobile-open-capture'),
                    onPressed: disconnected
                        ? null
                        : () => controller.dispatchMobile(
                              const OpenRouteIntent(WatchRoute.captureMenu,
                                  origin: IntentOrigin.mobileUi),
                            ),
                    child: const Text('Capture'),
                  ),
                  FilledButton.tonal(
                    key: const Key('mobile-yellow'),
                    onPressed: disconnected
                        ? null
                        : () => controller.dispatchMobile(
                              const OfferYellowIntent(origin: IntentOrigin.mobileUi),
                            ),
                    child: const Text('Yellow'),
                  ),
                  FilledButton.tonal(
                    key: const Key('mobile-sendoff'),
                    onPressed: disconnected
                        ? null
                        : () => controller.dispatchMobile(
                              const OpenRouteIntent(WatchRoute.sendOffFlow,
                                  origin: IntentOrigin.mobileUi),
                            ),
                    child: const Text('Sending-off'),
                  ),
                  FilledButton.tonal(
                    key: const Key('mobile-substitution'),
                    onPressed: disconnected
                        ? null
                        : () => controller.dispatchMobile(
                              const OpenRouteIntent(
                                  WatchRoute.substitutionFlow,
                                  origin: IntentOrigin.mobileUi),
                            ),
                    child: const Text('Substitution'),
                  ),
                  FilledButton.tonal(
                    key: const Key('mobile-goal'),
                    onPressed: disconnected
                        ? null
                        : () => controller.dispatchMobile(
                              const OfferGoalIntent(origin: IntentOrigin.mobileUi),
                            ),
                    child: const Text('Goal'),
                  ),
                  FilledButton.tonal(
                    key: const Key('mobile-match-report'),
                    onPressed: disconnected
                        ? null
                        : () => controller.dispatchMobile(
                              const OpenRouteIntent(WatchRoute.matchReport,
                                  origin: IntentOrigin.mobileUi),
                            ),
                    child: const Text('Match Report'),
                  ),
                ],
              ),
              if (state.navigation.route == WatchRoute.yellowFlow) ...[
                const SizedBox(height: 8),
                const Text('MOBILE YELLOW', style: LabText.caption),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      key: const Key('mobile-yellow-team-home'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.home,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.homeTeam),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-yellow-team-away'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.away,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.awayTeam),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-record-yellow'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const ActivateIntent(PresentationAction.yellow,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: const Text('Record Yellow'),
                    ),
                  ],
                ),
                for (final person in state.roster)
                  if (_teamFilter(state, person.team))
                    FilledButton.tonal(
                      key: Key('mobile-yellow-subject-${person.id}'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                SelectParticipantIntent(person.id,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text('#${person.shirtLabel} ${person.name}'),
                    ),
              ],
              if (state.navigation.route == WatchRoute.sendOffFlow) ...[
                const SizedBox(height: 8),
                const Text('MOBILE SEND-OFF', style: LabText.caption),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      key: const Key('mobile-sendoff-team-home'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.home,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.homeTeam),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-sendoff-team-away'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.away,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.awayTeam),
                    ),
                    FilledButton.tonal(
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const OfferDirectSendOffIntent(
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: const Text('Offer direct'),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-record-direct-sendoff'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const ActivateIntent(
                                    PresentationAction.directSendOff,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: const Text('Record direct send-off'),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-record-second-sendoff'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const ActivateIntent(
                                    PresentationAction.secondCautionSendOff,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: const Text('Record second-caution send-off'),
                    ),
                  ],
                ),
                for (final person in state.roster)
                  if (_teamFilter(state, person.team))
                    FilledButton.tonal(
                      key: Key('mobile-sendoff-subject-${person.id}'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                SelectParticipantIntent(person.id,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text('#${person.shirtLabel} ${person.name}'),
                    ),
              ],
              if (state.navigation.route == WatchRoute.substitutionFlow) ...[
                const SizedBox(height: 8),
                const Text('MOBILE SUBSTITUTION', style: LabText.caption),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      key: const Key('mobile-sub-team-home'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.home,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.homeTeam),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-sub-team-away'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.away,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.awayTeam),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-record-substitution'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const ActivateIntent(
                                    PresentationAction.substitution,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: const Text('Record substitution'),
                    ),
                  ],
                ),
                for (final person in state.roster)
                  if (_teamFilter(state, person.team)) ...[
                    FilledButton.tonal(
                      key: Key('mobile-sub-out-${person.id}'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                SelectOutIntent(person.id,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text('OUT #${person.shirtLabel}'),
                    ),
                    FilledButton.tonal(
                      key: Key('mobile-sub-in-${person.id}'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                SelectInIntent(person.id,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text('IN #${person.shirtLabel}'),
                    ),
                  ],
              ],
              if (state.navigation.route == WatchRoute.goalFlow) ...[
                const SizedBox(height: 8),
                const Text('MOBILE GOAL', style: LabText.caption),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      key: const Key('mobile-goal-team-home'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.home,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.homeTeam),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-goal-team-away'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                const SetTeamIntent(PresentationTeam.away,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text(fixture.awayTeam),
                    ),
                    FilledButton.tonal(
                      key: const Key('mobile-record-goal'),
                      onPressed: disconnected || !state.goalFlow.canRecord
                          ? null
                          : () => controller.dispatchMobile(
                                const ActivateIntent(PresentationAction.goal,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: const Text('Record Goal'),
                    ),
                  ],
                ),
                for (final person in state.roster)
                  if (person.team == state.goalFlow.scoringTeam)
                    FilledButton.tonal(
                      key: Key('mobile-goal-scorer-${person.id}'),
                      onPressed: disconnected
                          ? null
                          : () => controller.dispatchMobile(
                                SelectParticipantIntent(person.id,
                                    origin: IntentOrigin.mobileUi),
                              ),
                      child: Text('#${person.shirtLabel} ${person.name}'),
                    ),
              ],
              const SizedBox(height: 8),
              const Text('MATCH REPORT', style: LabText.caption),
              for (final entry in state.matchReport.entries)
                Text(
                  _mobileReportLine(entry),
                  key: Key('mobile-match-report-entry-${entry.sequence}'),
                  style: LabText.body,
                ),
              if (state.matchReport.entries.isEmpty)
                const Text('No established events', style: LabText.caption),
              const SizedBox(height: 4),
              const Text(
                'MOBILE UI · research pane · not production phone',
                style: LabText.caption,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  String _timeLine(WatchPresentationState state, ResearchFixture fixture) {
    if (state.clock.available && state.clock.label != null) {
      return state.clock.label!;
    }
    if (!state.clock.available) return 'Clock unavailable';
    return fixture.clockLabel;
  }

  String _scoreLine(WatchPresentationState state, ResearchFixture fixture) {
    if (!state.score.available) return 'Score unavailable';
    return state.score.label;
  }

  bool _teamFilter(WatchPresentationState state, PresentationTeam personTeam) {
    final ctx = state.header.teamContext;
    return switch (ctx) {
      PresentationTeamContext.home => personTeam == PresentationTeam.home,
      PresentationTeamContext.away => personTeam == PresentationTeam.away,
      PresentationTeamContext.absent || PresentationTeamContext.ambiguous =>
        true,
    };
  }

  String _mobileReportLine(MatchReportEntryPresentation entry) {
    final kind = matchReportKindLabel(entry.kind);
    final buffer = StringBuffer(
      '${entry.matchTimeLabel} $kind ${entry.teamLabel} ${entry.participantDisplay}',
    );
    if (entry.details != null) buffer.write(' ${entry.details}');
    if (entry.scoreAfterLabel != null) {
      buffer.write(' ${entry.scoreAfterLabel}');
    }
    return buffer.toString();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: LabText.caption)),
          Expanded(child: Text(value, style: LabText.numeric)),
        ],
      ),
    );
  }
}
