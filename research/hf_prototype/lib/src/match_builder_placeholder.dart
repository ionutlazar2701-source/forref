import 'package:flutter/material.dart';
import 'package:hf_v2/hf_v2.dart';

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
  late ResearchFixture _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.controller.fixture;
  }

  @override
  Widget build(BuildContext context) {
    final stacked = widget.regime == LabLayoutRegime.narrow ||
        widget.regime == LabLayoutRegime.compact;
    final steps = _StepRail(
      step: _step,
      horizontal: stacked,
      onSelect: (next) => setState(() => _step = next),
    );
    final detail = _StepDetail(
      step: _step,
      draft: _draft,
      onDraftChanged: (next) => setState(() => _draft = next),
      onApply: () => widget.controller.applyResearchFixture(_draft),
    );
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
            Flexible(
              child: Text(
                step.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: selected ? LabText.onNavyStrong : LabText.bodyStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDetail extends StatelessWidget {
  const _StepDetail({
    required this.step,
    required this.draft,
    required this.onDraftChanged,
    required this.onApply,
  });

  final MatchBuilderStep step;
  final ResearchFixture draft;
  final ValueChanged<ResearchFixture> onDraftChanged;
  final VoidCallback onApply;

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
            if (step == MatchBuilderStep.match) ...[
              const SizedBox(height: LabMetrics.gutter),
              _field('Match name', draft.matchName, (v) => onDraftChanged(draft.copyWith(matchName: v))),
              _field('Home team', draft.homeTeam, (v) => onDraftChanged(draft.copyWith(homeTeam: v))),
              _field('Away team', draft.awayTeam, (v) => onDraftChanged(draft.copyWith(awayTeam: v))),
            ],
            if (step == MatchBuilderStep.format) ...[
              const SizedBox(height: LabMetrics.gutter),
              DropdownButton<ScenarioId>(
                key: const Key('builder-scenario'),
                value: draft.scenarioId,
                isExpanded: true,
                items: [
                  for (final id in ScenarioId.values)
                    DropdownMenuItem(value: id, child: Text(id.name)),
                ],
                onChanged: (id) {
                  if (id != null) onDraftChanged(draft.copyWith(scenarioId: id));
                },
              ),
            ],
            if (step == MatchBuilderStep.review) ...[
              const SizedBox(height: LabMetrics.gutter),
              Text(_draftSummary(), style: LabText.body),
              const SizedBox(height: LabMetrics.tight),
              FilledButton(
                key: const Key('builder-apply-fixture'),
                onPressed: onApply,
                child: const Text('Load into paired lab'),
              ),
            ],
            const SizedBox(height: LabMetrics.gutter),
            const Text(
              'Non-authoritative · no Match Records · not Saved',
              key: Key('builder-reserved-note'),
              style: LabText.caption,
            ),
          ],
        ),
      ),
    );
  }

  String _draftSummary() =>
      '${draft.matchName} · ${draft.homeTeam} vs ${draft.awayTeam} · '
      'scenario ${draft.scenarioId.name} · watch ${draft.watchProfileId}';

  Widget _field(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        key: Key('builder-field-$label'),
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: onChanged,
      ),
    );
  }
}
