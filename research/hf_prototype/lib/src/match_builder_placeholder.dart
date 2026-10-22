import 'package:flutter/material.dart';

import '../research_app.dart';
import 'device_hero_stage.dart';
import 'lab_theme.dart';

/// Reserved S2.4 workspace. Composition only.
///
/// Nothing here writes a record, loads a scenario, or claims a saved match.
/// The step rail is static navigation between non-authoritative descriptions.
enum MatchBuilderStep {
  match,
  teamsAndSquads,
  officialsAndCrew,
  format,
  review
}

extension MatchBuilderStepLabel on MatchBuilderStep {
  String get label => switch (this) {
        MatchBuilderStep.match => 'MATCH',
        MatchBuilderStep.teamsAndSquads => 'TEAMS & SQUADS',
        MatchBuilderStep.officialsAndCrew => 'OFFICIALS & CREW',
        MatchBuilderStep.format => 'FORMAT',
        MatchBuilderStep.review => 'REVIEW',
      };

  String get description => switch (this) {
        MatchBuilderStep.match =>
          'Competition, date, venue and kick-off context for a synthetic match. S2.4 defines the fields. Nothing is captured here.',
        MatchBuilderStep.teamsAndSquads =>
          'Home and away squads with shirt numbers and roles. The research instrument currently uses bounded synthetic rosters from hf_v2 scenarios.',
        MatchBuilderStep.officialsAndCrew =>
          'Referee, assistants, fourth official and observers for the synthetic crew. Officials remain non-authoritative research subjects.',
        MatchBuilderStep.format =>
          'Periods, extra time, shoot-out scope and timing policy. Domain Clock Policy stays upstream; the builder never defines temporal authority.',
        MatchBuilderStep.review =>
          'Read-back of the synthetic match before it loads into a research scenario. Review is not Saved. No Match Record is created.',
      };
}

class MatchBuilderPlaceholder extends StatefulWidget {
  const MatchBuilderPlaceholder({
    super.key,
    required this.controller,
    required this.regime,
  });

  final ResearchController controller;
  final LabLayoutRegime regime;

  @override
  State<MatchBuilderPlaceholder> createState() =>
      _MatchBuilderPlaceholderState();
}

class _MatchBuilderPlaceholderState extends State<MatchBuilderPlaceholder> {
  MatchBuilderStep _step = MatchBuilderStep.match;

  @override
  Widget build(BuildContext context) {
    final stacked = widget.regime == LabLayoutRegime.narrow ||
        widget.regime == LabLayoutRegime.compact;
    final steps = _StepRail(
      step: _step,
      horizontal: stacked,
      onSelect: (next) => setState(() => _step = next),
    );
    final detail = _StepDetail(step: _step);
    return Padding(
      padding: const EdgeInsets.all(LabMetrics.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceHeader(
            title: matchBuilderWaveLabel,
            subtitle: LabWorkspace.matchBuilder.question,
            trailing: const ContextChip(text: 'NON-AUTHORITATIVE · NO RECORDS'),
          ),
          const SizedBox(height: LabMetrics.gutter),
          Expanded(
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      steps,
                      const SizedBox(height: LabMetrics.gutter),
                      Expanded(child: detail),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: LabMetrics.railWidth, child: steps),
                      const SizedBox(width: LabMetrics.gutter),
                      Expanded(child: detail),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({
    required this.step,
    required this.horizontal,
    required this.onSelect,
  });

  final MatchBuilderStep step;
  final bool horizontal;
  final ValueChanged<MatchBuilderStep> onSelect;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final item in MatchBuilderStep.values)
        _StepTile(
          step: item,
          selected: item == step,
          onTap: () => onSelect(item),
        ),
    ];
    if (horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: tiles),
      );
    }
    return Container(
      padding: const EdgeInsets.all(LabMetrics.tight),
      decoration: BoxDecoration(
        color: LabColors.surface,
        border: Border.all(color: LabColors.line),
        borderRadius: BorderRadius.circular(LabMetrics.surfaceRadius),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: tiles),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.selected,
    required this.onTap,
  });

  final MatchBuilderStep step;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final index = MatchBuilderStep.values.indexOf(step) + 1;
    return InkWell(
      key: Key('builder-step-${step.name}'),
      borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? LabColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$index',
              style: selected
                  ? LabText.onNavyStrong
                  : LabText.bodyStrong.copyWith(color: LabColors.steel),
            ),
            const SizedBox(width: 10),
            Text(
              step.label,
              style: selected ? LabText.onNavyStrong : LabText.bodyStrong,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDetail extends StatelessWidget {
  const _StepDetail({required this.step});

  final MatchBuilderStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LabMetrics.pageMargin),
      decoration: BoxDecoration(
        color: LabColors.surface,
        border: Border.all(color: LabColors.line),
        borderRadius: BorderRadius.circular(LabMetrics.surfaceRadius),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.label,
                key: Key('builder-detail-${step.name}'), style: LabText.title),
            const SizedBox(height: LabMetrics.tight),
            Text(step.description, style: LabText.body),
            const SizedBox(height: LabMetrics.gutter),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LabColors.canvas,
                borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
              ),
              child: const Text(
                'Reserved for WAVE S2.4 — Complete Synthetic Match Builder. This placeholder '
                'does not create Match Records, does not touch hf_v2 history, and never shows '
                'a Saved state. The current research scenario stays the only loaded match.',
                key: Key('builder-reserved-note'),
                style: LabText.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
