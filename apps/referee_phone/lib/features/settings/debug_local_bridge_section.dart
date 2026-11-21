import 'dart:async';

import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/design/forref_spacing.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/officiate/local_configuration_bridge.dart';

/// Debug control for the loopback configuration server.
///
/// Callers build this only when [kDebugMode] is true.
class DebugLocalBridgeSection extends StatefulWidget {
  const DebugLocalBridgeSection({
    super.key,
    required this.bridge,
    required this.database,
  });

  final LocalConfigurationBridge bridge;
  final LocalMatchDatabase database;

  @override
  State<DebugLocalBridgeSection> createState() =>
      _DebugLocalBridgeSectionState();
}

class _DebugLocalBridgeSectionState extends State<DebugLocalBridgeSection> {
  List<Match> _matches = const [];
  String? _selectedMatchId;
  LocalBridgeDisposition? _notice;

  @override
  void initState() {
    super.initState();
    _selectedMatchId = widget.bridge.selectedMatchId;
    unawaited(_load());
  }

  Future<void> _load() async {
    final matches = await widget.database.listNewestFirst();
    if (!mounted) return;
    setState(() => _matches = matches);
  }

  Future<void> _choose(String matchId) async {
    setState(() {
      _selectedMatchId = matchId;
      _notice = null;
    });
    if (!widget.bridge.isListening) return;
    final result = await widget.bridge.select(matchId);
    if (!mounted) return;
    setState(() => _notice = result);
  }

  Future<void> _toggle() async {
    final bridge = widget.bridge;
    if (bridge.isListening) {
      await bridge.stop();
      if (!mounted) return;
      setState(() => _notice = null);
      return;
    }
    final matchId = _selectedMatchId;
    if (matchId == null) return;
    final result = await bridge.start(matchId);
    if (!mounted) return;
    setState(() => _notice = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bridge = widget.bridge;
    return ListenableBuilder(
      listenable: bridge,
      builder: (context, _) {
        final address = bridge.isListening
            ? bridge.loopbackEndpoint
            : '127.0.0.1:${bridge.port}';
        final status = _status(l10n, bridge, address);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ForrefSpace.s20,
                ForrefSpace.s16,
                ForrefSpace.s20,
                ForrefSpace.s8,
              ),
              child: Text(
                l10n.localBridgeTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ForrefSpace.s20,
                0,
                ForrefSpace.s20,
                ForrefSpace.s8,
              ),
              child: Text(l10n.localBridgeBody(address)),
            ),
            const Divider(height: 1),
            if (_matches.isEmpty)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ForrefSpace.s20,
                ),
                title: Text(l10n.localBridgeNone),
              )
            else
              for (final match in _matches)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: ForrefSpace.s20,
                  ),
                  title: Text(_names(l10n, match)),
                  trailing: _selectedMatchId == match.matchId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => _choose(match.matchId),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ForrefSpace.s20,
                ForrefSpace.s8,
                ForrefSpace.s20,
                ForrefSpace.s8,
              ),
              child: Text(status),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ForrefSpace.s20),
              child: FilledButton(
                onPressed: _selectedMatchId == null && !bridge.isListening
                    ? null
                    : _toggle,
                child: Text(
                  bridge.isListening
                      ? l10n.localBridgeStop
                      : l10n.localBridgeStart,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _status(
    AppLocalizations l10n,
    LocalConfigurationBridge bridge,
    String address,
  ) {
    if (bridge.isListening) return l10n.localBridgeListening(address);
    return switch (_notice) {
      LocalBridgeDisposition.missing => l10n.localBridgeMissing,
      LocalBridgeDisposition.failed => l10n.localBridgeFailed,
      LocalBridgeDisposition.refused => l10n.localBridgeStopped,
      _ => _selectedMatchId == null
          ? l10n.localBridgeSelect
          : l10n.localBridgeStopped,
    };
  }

  String _names(AppLocalizations l10n, Match match) {
    return '${_team(match.teams.home.name, l10n.homeTeamNotSet)} — '
        '${_team(match.teams.away.name, l10n.awayTeamNotSet)}';
  }

  String _team(String? name, String fallback) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }
}
