import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';

enum _CaptureStep { team, player, subOut, subIn }

class CaptureOverlay extends StatefulWidget {
  const CaptureOverlay({
    super.key,
    required this.match,
    required this.type,
    required this.onSave,
    required this.onCancel,
    required this.onTypeChanged,
  });

  final Match match;
  final EventType type;
  final void Function(EventType type, EventData data) onSave;
  final VoidCallback onCancel;
  final ValueChanged<EventType> onTypeChanged;

  @override
  State<CaptureOverlay> createState() => _CaptureOverlayState();
}

class _CaptureOverlayState extends State<CaptureOverlay> {
  late EventType _type;
  _CaptureStep _step = _CaptureStep.team;
  String? _teamId;
  PlayerRef? _out;
  final _number = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.type;
  }

  @override
  void didUpdateWidget(CaptureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      setState(() => _type = widget.type);
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  List<Player> get _squad {
    final match = widget.match;
    if (_teamId == match.teams.home.teamId) return match.squads.home.players;
    if (_teamId == match.teams.away.teamId) return match.squads.away.players;
    return const [];
  }

  void _pickTeam(String teamId) {
    setState(() {
      _teamId = teamId;
      _step = _type == EventType.substitution
          ? _CaptureStep.subOut
          : _CaptureStep.player;
    });
  }

  void _choose(PlayerRef ref) {
    if (_step == _CaptureStep.player) {
      widget.onSave(
        _type,
        EventData(teamId: _teamId, player: ref, isOwnGoal: false),
      );
      return;
    }
    if (_step == _CaptureStep.subOut) {
      setState(() {
        _out = ref;
        _step = _CaptureStep.subIn;
        _number.clear();
      });
      return;
    }
    widget.onSave(
      _type,
      EventData(teamId: _teamId, out: _out, inPlayer: ref),
    );
  }

  void _useNumber() {
    final n = int.tryParse(_number.text.trim());
    if (n == null) return;
    _choose(PlayerRef(shirtNumber: n, isUnknown: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final type in EventType.values)
                    FilledButton.tonal(
                      onPressed: () {
                        widget.onTypeChanged(type);
                        setState(() {
                          _type = type;
                          if (_teamId != null) {
                            _step = type == EventType.substitution
                                ? (_out == null
                                    ? _CaptureStep.subOut
                                    : _CaptureStep.subIn)
                                : _CaptureStep.player;
                          }
                        });
                      },
                      child: Text(eventTypeLabel(type, l10n)),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onCancel,
                  child: Text(l10n.back),
                ),
              ),
              if (_step == _CaptureStep.team) ...[
                FilledButton(
                  onPressed: () =>
                      _pickTeam(widget.match.teams.home.teamId),
                  child: Text(homeLabel(widget.match, l10n)),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      _pickTeam(widget.match.teams.away.teamId),
                  child: Text(awayLabel(widget.match, l10n)),
                ),
              ] else ...[
                Text(
                  _step == _CaptureStep.subOut
                      ? l10n.playerOut
                      : _step == _CaptureStep.subIn
                          ? l10n.playerIn
                          : eventTypeLabel(_type, l10n),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () =>
                      _choose(const PlayerRef(isUnknown: true)),
                  child: Text(l10n.unknown),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _number,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: l10n.freeNumber),
                        onSubmitted: (_) => _useNumber(),
                      ),
                    ),
                    FilledButton(
                      onPressed: _useNumber,
                      child: Text(l10n.freeNumber),
                    ),
                  ],
                ),
                for (final player in _squad)
                  ListTile(
                    title: Text(
                      '#${player.shirtNumber ?? '—'} ${player.name ?? ''}'
                          .trim(),
                    ),
                    onTap: () => _choose(
                      PlayerRef(
                        playerId: player.playerId,
                        shirtNumber: player.shirtNumber,
                        name: player.name,
                        isUnknown: false,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
