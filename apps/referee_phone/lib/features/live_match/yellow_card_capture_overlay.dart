import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/l10n/app_localizations.dart';

enum YellowPriorAwareness {
  loading,
  noneConfirmed,
  exists,
  unknownIdentity,
  unknownHistory,
  conflicted,
}

final class YellowParticipantOption {
  const YellowParticipantOption({
    required this.participantRef,
    required this.status,
    required this.identityConfidence,
    required this.priorAwareness,
    required this.teamLabel,
    this.shirtNumber,
    this.displayName,
  });

  final ParticipantRef participantRef;
  final ParticipantStatusAtDetermination status;
  final IdentityConfidence identityConfidence;
  final YellowPriorAwareness priorAwareness;
  final String teamLabel;
  final int? shirtNumber;
  final String? displayName;

  String get participantKey => participantRef.matchParticipantId.value;

  bool get identityBlocksCommit =>
      identityConfidence == IdentityConfidence.ambiguous ||
      identityConfidence == IdentityConfidence.conflicted;
}

class YellowCardCaptureOverlay extends StatefulWidget {
  const YellowCardCaptureOverlay({
    super.key,
    required this.homePlayers,
    required this.awayPlayers,
    required this.bench,
    required this.officials,
    required this.selected,
    required this.loading,
    required this.saving,
    required this.checking,
    required this.failed,
    required this.onSelect,
    required this.onCommit,
    required this.onCancel,
  });

  final List<YellowParticipantOption> homePlayers;
  final List<YellowParticipantOption> awayPlayers;
  final List<YellowParticipantOption> bench;
  final List<YellowParticipantOption> officials;
  final YellowParticipantOption? selected;
  final bool loading;
  final bool saving;
  final bool checking;
  final bool failed;
  final ValueChanged<YellowParticipantOption> onSelect;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  State<YellowCardCaptureOverlay> createState() =>
      _YellowCardCaptureOverlayState();
}

class _YellowCardCaptureOverlayState extends State<YellowCardCaptureOverlay> {
  bool _benchOpen = false;
  bool _officialsOpen = false;

  bool get _commitLocked => widget.saving || widget.checking;
  bool get _selectionLocked => _commitLocked || widget.failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = widget.selected;
    final canCommit = selected != null &&
        !selected.identityBlocksCommit &&
        !widget.loading &&
        !_commitLocked;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.yellow,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const Key('yellow-cancel'),
                    onPressed: _commitLocked ? null : widget.onCancel,
                    child: Text(l10n.back),
                  ),
                ],
              ),
            ),
            if (widget.loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (selected != null) ...[
                    _SelectedParticipantCard(option: selected),
                    const SizedBox(height: 12),
                  ],
                  if (widget.checking)
                    _AttentionMessage(
                      key: const Key('yellow-checking'),
                      text: l10n.checkingSaveStatus,
                      level: _AttentionLevel.high,
                    )
                  else if (widget.failed)
                    _AttentionMessage(
                      key: const Key('yellow-not-saved'),
                      text: l10n.notSaved,
                      level: _AttentionLevel.high,
                    ),
                  if (widget.checking || widget.failed)
                    const SizedBox(height: 12),
                  _TeamRegion(
                    title: l10n.homeFallback,
                    options: widget.homePlayers,
                    selected: selected,
                    locked: _selectionLocked,
                    onSelect: widget.onSelect,
                  ),
                  const SizedBox(height: 16),
                  _TeamRegion(
                    title: l10n.awayFallback,
                    options: widget.awayPlayers,
                    selected: selected,
                    locked: _selectionLocked,
                    onSelect: widget.onSelect,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('yellow-bench-toggle'),
                        onPressed: _selectionLocked
                            ? null
                            : () => setState(() => _benchOpen = !_benchOpen),
                        child: Text(l10n.bench),
                      ),
                      OutlinedButton(
                        key: const Key('yellow-officials-toggle'),
                        onPressed: _selectionLocked
                            ? null
                            : () => setState(
                                  () => _officialsOpen = !_officialsOpen,
                                ),
                        child: Text(l10n.officials),
                      ),
                    ],
                  ),
                  if (_benchOpen)
                    _SecondaryList(
                      options: widget.bench,
                      selected: selected,
                      locked: _selectionLocked,
                      emptyLabel: l10n.noBenchParticipants,
                      onSelect: widget.onSelect,
                    ),
                  if (_officialsOpen)
                    _SecondaryList(
                      options: widget.officials,
                      selected: selected,
                      locked: _selectionLocked,
                      emptyLabel: l10n.noOfficials,
                      onSelect: widget.onSelect,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                key: const Key('yellow-commit'),
                onPressed: canCommit ? widget.onCommit : null,
                child: Text(
                  widget.saving
                      ? l10n.saving
                      : widget.checking
                          ? l10n.checkingSaveStatus
                          : widget.failed
                              ? l10n.retry
                              : selected?.priorAwareness ==
                                      YellowPriorAwareness.exists
                                  ? l10n.recordSecondCaution
                                  : l10n.recordYellow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamRegion extends StatelessWidget {
  const _TeamRegion({
    required this.title,
    required this.options,
    required this.selected,
    required this.locked,
    required this.onSelect,
  });

  final String title;
  final List<YellowParticipantOption> options;
  final YellowParticipantOption? selected;
  final bool locked;
  final ValueChanged<YellowParticipantOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (options.isEmpty)
          Text(l10n.noOnFieldParticipants)
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              for (final option in options)
                _ParticipantTarget(
                  option: option,
                  selected: selected?.participantKey == option.participantKey,
                  locked: locked,
                  onSelect: onSelect,
                ),
            ],
          ),
      ],
    );
  }
}

class _SecondaryList extends StatelessWidget {
  const _SecondaryList({
    required this.options,
    required this.selected,
    required this.locked,
    required this.emptyLabel,
    required this.onSelect,
  });

  final List<YellowParticipantOption> options;
  final YellowParticipantOption? selected;
  final bool locked;
  final String emptyLabel;
  final ValueChanged<YellowParticipantOption> onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(emptyLabel),
      );
    }
    return Column(
      children: [
        for (final option in options)
          ListTile(
            key: Key('yellow-option-${option.participantKey}'),
            enabled: !locked,
            selected: selected?.participantKey == option.participantKey,
            leading: option.shirtNumber == null
                ? const Icon(Icons.person_outline)
                : CircleAvatar(child: Text('${option.shirtNumber}')),
            title: Text(option.displayName ?? option.teamLabel),
            subtitle: Text(
              '${option.teamLabel} · ${_statusLabel(context, option.status)}',
            ),
            trailing: _PriorMarker(awareness: option.priorAwareness),
            onTap: locked ? null : () => onSelect(option),
          ),
      ],
    );
  }
}

class _ParticipantTarget extends StatelessWidget {
  const _ParticipantTarget({
    required this.option,
    required this.selected,
    required this.locked,
    required this.onSelect,
  });

  final YellowParticipantOption option;
  final bool selected;
  final bool locked;
  final ValueChanged<YellowParticipantOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: _participantText(option),
      child: InkWell(
        key: Key('yellow-option-${option.participantKey}'),
        onTap: locked ? null : () => onSelect(option),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      option.shirtNumber == null
                          ? '—'
                          : '${option.shirtNumber}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    _PriorMarker(awareness: option.priorAwareness),
                  ],
                ),
                if (option.displayName != null)
                  Text(
                    option.displayName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedParticipantCard extends StatelessWidget {
  const _SelectedParticipantCard({required this.option});

  final YellowParticipantOption option;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identityMessage = switch (option.identityConfidence) {
      IdentityConfidence.resolved => null,
      IdentityConfidence.provisional => l10n.identityProvisional,
      IdentityConfidence.ambiguous => l10n.cannotIdentifyParticipantReliably,
      IdentityConfidence.conflicted => l10n.participantDetailsConflict,
    };
    final priorMessage = switch (option.priorAwareness) {
      YellowPriorAwareness.loading => l10n.checkingCautionHistory,
      YellowPriorAwareness.noneConfirmed => null,
      YellowPriorAwareness.exists => l10n.priorCautionRecorded,
      YellowPriorAwareness.unknownIdentity =>
        l10n.cannotIdentifyParticipantReliably,
      YellowPriorAwareness.unknownHistory =>
        l10n.cautionHistoryCannotBeConfirmed,
      YellowPriorAwareness.conflicted => l10n.participantDetailsConflict,
    };
    final priorLevel = option.priorAwareness == YellowPriorAwareness.exists ||
            option.priorAwareness == YellowPriorAwareness.conflicted
        ? _AttentionLevel.high
        : _AttentionLevel.amber;
    return Card(
      key: const Key('yellow-selected'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              option.teamLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              _participantText(option),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (option.status != ParticipantStatusAtDetermination.onFieldPlayer)
              Text(_statusLabel(context, option.status)),
            if (identityMessage != null) ...[
              const SizedBox(height: 8),
              _AttentionMessage(
                text: identityMessage,
                level: option.identityBlocksCommit
                    ? _AttentionLevel.high
                    : _AttentionLevel.amber,
              ),
            ],
            if (priorMessage != null && priorMessage != identityMessage) ...[
              const SizedBox(height: 8),
              _AttentionMessage(text: priorMessage, level: priorLevel),
            ],
          ],
        ),
      ),
    );
  }
}

enum _AttentionLevel { amber, high }

class _AttentionMessage extends StatelessWidget {
  const _AttentionMessage({
    super.key,
    required this.text,
    required this.level,
  });

  final String text;
  final _AttentionLevel level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final high = level == _AttentionLevel.high;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: high ? scheme.errorContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: high ? scheme.error : scheme.tertiary,
        ),
      ),
      child: Row(
        children: [
          Icon(
            high ? Icons.warning_amber_rounded : Icons.info_outline,
            color: high ? scheme.onErrorContainer : scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    high ? scheme.onErrorContainer : scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorMarker extends StatelessWidget {
  const _PriorMarker({required this.awareness});

  final YellowPriorAwareness awareness;

  @override
  Widget build(BuildContext context) {
    final visible = awareness == YellowPriorAwareness.exists;
    return SizedBox(
      width: 20,
      child: visible
          ? Icon(
              Icons.warning_amber_rounded,
              key: const Key('prior-caution-marker'),
              size: 18,
              color: Theme.of(context).colorScheme.error,
            )
          : null,
    );
  }
}

String _participantText(YellowParticipantOption option) {
  final number = option.shirtNumber == null ? null : '#${option.shirtNumber}';
  final label = [number, option.displayName]
      .whereType<String>()
      .where((part) => part.isNotEmpty)
      .join(' ');
  return label.isEmpty ? option.teamLabel : label;
}

String _statusLabel(
  BuildContext context,
  ParticipantStatusAtDetermination status,
) {
  final l10n = AppLocalizations.of(context);
  return switch (status) {
    ParticipantStatusAtDetermination.onFieldPlayer => l10n.onField,
    ParticipantStatusAtDetermination.substitute => l10n.substitute,
    ParticipantStatusAtDetermination.substitutedPlayer =>
      l10n.substitutedPlayer,
    ParticipantStatusAtDetermination.teamOfficial => l10n.teamOfficial,
    ParticipantStatusAtDetermination.seniorCoachPresent =>
      l10n.seniorCoachPresent,
  };
}
