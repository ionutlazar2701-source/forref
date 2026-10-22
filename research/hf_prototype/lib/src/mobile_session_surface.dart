import 'package:flutter/material.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import '../research_app.dart';
import 'lab_theme.dart';
import 'paired_session.dart';

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
                ],
              ),
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
