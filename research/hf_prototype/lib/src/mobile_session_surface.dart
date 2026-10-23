import 'dart:math' as math;

import 'package:flutter/material.dart' hide ActivateIntent;
import 'package:simulator_presentation/simulator_presentation.dart';

import '../research_app.dart';
import 'john_frames.dart';
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
    final matchRunning = state.clock.available && !state.clock.kickOffAvailable;
    final canAct = !disconnected && matchRunning;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 620.0;
        final width = math.min(constraints.maxWidth, height * 0.50);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: height,
            child: PhoneBezel(
              child: Material(
      key: const Key('mobile-session'),
      color: controller.phoneDark ? const Color(0xFF081420) : const Color(0xFF10283F),
      child: Padding(
          padding: const EdgeInsets.all(10),
          child: Theme(
            data: Theme.of(context).copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.clock.phaseLabel != _timeLine(state, fixture))
                Text(
                state.clock.phaseLabel,
                key: const Key('mobile-phase'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF26C0CA),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                _timeLine(state, fixture),
                key: const Key('mobile-clock'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFF4F9FC),
                  fontSize: state.navigation.route == WatchRoute.liveCore ? 40 : 22,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
              Text(
                _scoreLine(state, fixture),
                key: const Key('mobile-score'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF4F9FC),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                disconnected ? 'SIMULATED DISCONNECT' : 'SIMULATED CONNECTION · PAIR ACTIVE',
                style: _phoneMeta.copyWith(
                  color: disconnected ? LabColors.unknownFact : LabColors.steel,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                const Text('Recent research state', style: _phoneMeta),
                const SizedBox(height: 4),
                Text(state.commit.label, style: const TextStyle(color: Color(0xFFF4F9FC), fontSize: 14, fontWeight: FontWeight.w700)),
                if (state.frozenCommand != null)
                  Text(
                      'In flight: ${state.frozenCommand!.action.name} '
                      '${state.frozenCommand!.subjectId ?? ''}',
                      style: _phoneMeta),
              ],
              const SizedBox(height: 8),
              if (state.clock.kickOffAvailable)
                _KickOffButton(
                  enabled: !disconnected,
                  inputEpoch: controller.inputEpoch,
                  onArm: () => controller.dispatchMobile(
                    const ArmKickOffIntent(origin: IntentOrigin.mobileUi),
                  ),
                  onConfirm: () => controller.dispatchMobile(
                    const ConfirmKickOffIntent(origin: IntentOrigin.mobileUi),
                  ),
                ),
              _PhoneActionGrid(
                controller: controller,
                canAct: canAct,
                disconnected: disconnected,
                roomy: state.navigation.route == WatchRoute.liveCore,
              ),
              if (state.navigation.route == WatchRoute.yellowFlow) ...[
                const SizedBox(height: 8),
                const Text('MOBILE YELLOW', style: _phoneMeta),
                if (state.clock.label != null)
                  Text(
                    'Match time ${state.clock.label}',
                    key: const Key('mobile-yellow-review-time'),
                  ),
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
                const Text('MOBILE SEND-OFF', style: _phoneMeta),
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
                const Text('MOBILE SUBSTITUTION', style: _phoneMeta),
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
                const Text('MOBILE GOAL', style: _phoneMeta),
                Text(
                  state.goalFlow.reviewMatchTimeLabel ?? 'Kick-off required',
                  key: const Key('mobile-goal-review-time'),
                ),
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
              const Text('Recent events', style: _phoneMeta),
              for (final entry in state.matchReport.entries)
                Text(
                  _mobileReportLine(entry),
                  key: Key('mobile-match-report-entry-${entry.sequence}'),
                  style: _phoneBody,
                ),
              if (state.matchReport.entries.isEmpty)
                const Text('No established events', style: _phoneMeta),
              const SizedBox(height: 4),
              const Text(
                'Research phone · not the production app',
                style: _phoneMeta,
              ),
            ],
          ),
          ),
        ),
      ),
            ),
          ),
          ),
        );
      },
    );
  }

  String _timeLine(WatchPresentationState state, ResearchFixture fixture) {
    if (state.clock.kickOffAvailable) return 'Not started';
    if (state.clock.available && state.clock.label != null) {
      return state.clock.label!;
    }
    if (!state.clock.available) return 'Clock unavailable';
    return fixture.clockLabel;
  }

  String _scoreLine(WatchPresentationState state, ResearchFixture fixture) {
    if (!state.score.available) return 'Score unavailable';
    final home = state.score.homeGoals;
    final away = state.score.awayGoals;
    if (home != null && away != null) {
      return 'Home $home  —  $away Away';
    }
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
}

const _phoneMeta = TextStyle(color: Color(0xFFB7C9D6), fontSize: 11, height: 1.3);
const _phoneBody = TextStyle(color: Color(0xFFF4F9FC), fontSize: 13, height: 1.35);

class _PhoneActionGrid extends StatelessWidget {
  const _PhoneActionGrid({
    required this.controller,
    required this.canAct,
    required this.disconnected,
    required this.roomy,
  });

  final ResearchController controller;
  final bool canAct;
  final bool disconnected;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 24 ? 0.0 : 8.0;
        return Column(
      children: [
        Row(
          children: [
            Expanded(child: _card(
              key: const Key('mobile-open-capture'),
              icon: Icons.sports_soccer,
              title: 'Capture event',
              onPressed: canAct
                  ? () => controller.dispatchMobile(
                        const OpenRouteIntent(WatchRoute.captureMenu, origin: IntentOrigin.mobileUi),
                      )
                  : null,
            )),
            SizedBox(width: gap),
            Expanded(child: _card(
              key: const Key('mobile-goal'),
              icon: Icons.flag_outlined,
              title: 'Goal',
              onPressed: canAct
                  ? () => controller.dispatchMobile(
                        const OfferGoalIntent(origin: IntentOrigin.mobileUi),
                      )
                  : null,
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _card(
              key: const Key('mobile-yellow'),
              icon: Icons.square,
              iconColor: const Color(0xFFEAB308),
              title: 'Caution',
              onPressed: canAct
                  ? () => controller.dispatchMobile(
                        const OfferYellowIntent(origin: IntentOrigin.mobileUi),
                      )
                  : null,
            )),
            SizedBox(width: gap),
            Expanded(child: _card(
              key: const Key('mobile-sendoff'),
              icon: Icons.square,
              iconColor: const Color(0xFFDC2626),
              title: 'Send off',
              onPressed: canAct
                  ? () => controller.dispatchMobile(
                        const OpenRouteIntent(WatchRoute.sendOffFlow, origin: IntentOrigin.mobileUi),
                      )
                  : null,
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _card(
              key: const Key('mobile-substitution'),
              icon: Icons.swap_horiz,
              title: 'Substitution',
              onPressed: canAct
                  ? () => controller.dispatchMobile(
                        const OpenRouteIntent(WatchRoute.substitutionFlow, origin: IntentOrigin.mobileUi),
                      )
                  : null,
            )),
            SizedBox(width: gap),
            Expanded(child: _card(
              key: const Key('mobile-match-report'),
              icon: Icons.receipt_long,
              title: 'Reports',
              onPressed: disconnected
                  ? null
                  : () => controller.dispatchMobile(
                        const OpenRouteIntent(WatchRoute.matchReport, origin: IntentOrigin.mobileUi),
                      ),
            )),
          ],
        ),
      ],
        );
      },
    );
  }

  Widget _card({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback? onPressed,
    Color iconColor = const Color(0xFF0B2743),
  }) {
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF7FBFD),
        foregroundColor: const Color(0xFF0B2743),
        disabledBackgroundColor: const Color(0xFFE4EDF3),
        disabledForegroundColor: const Color(0xFF5C7080),
        elevation: 0,
        minimumSize: Size(0, roomy ? 64 : 34),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: roomy ? 10 : 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: onPressed == null ? const Color(0xFF8AA0B3) : iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: Color(0xFF0B2743),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KickOffButton extends StatefulWidget {
  const _KickOffButton({
    required this.enabled,
    required this.inputEpoch,
    required this.onArm,
    required this.onConfirm,
  });

  final bool enabled;
  final int inputEpoch;
  final VoidCallback onArm;
  final VoidCallback onConfirm;

  @override
  State<_KickOffButton> createState() => _KickOffButtonState();
}

class _KickOffButtonState extends State<_KickOffButton> {
  int? _pointer;
  int? _epoch;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled
          ? (event) {
              _pointer = event.pointer;
              _epoch = widget.inputEpoch;
              widget.onArm();
            }
          : null,
      onPointerUp: widget.enabled
          ? (event) {
              final confirm =
                  _pointer == event.pointer && _epoch == widget.inputEpoch;
              _pointer = null;
              if (confirm) widget.onConfirm();
            }
          : null,
      onPointerCancel: (_) => _pointer = null,
      child: FilledButton(
        key: const Key('mobile-kick-off'),
        onPressed: widget.enabled ? () {} : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF26C0CA),
          foregroundColor: const Color(0xFF0B2743),
          disabledBackgroundColor: const Color(0xFF1A3A56),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'KICK-OFF',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF0B2743),
          ),
        ),
      ),
    );
  }
}
