import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

/// Debug-only control for the local watch provision bridge.
class WatchProvisionDebugSection extends StatefulWidget {
  const WatchProvisionDebugSection({super.key});

  @override
  State<WatchProvisionDebugSection> createState() =>
      _WatchProvisionDebugSectionState();
}

class _WatchProvisionDebugSectionState extends State<WatchProvisionDebugSection> {
  final TextEditingController _installation = TextEditingController();
  WatchProvisionDebugBridge? _bridge;
  List<Match> _matches = const [];
  String? _matchId;
  String _status = '';

  @override
  void dispose() {
    _installation.dispose();
    _bridge?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(title: Text(l10n.watchProvisionTitle)),
        if (boundary == null || identity == null)
          ListTile(title: Text(l10n.watchProvisionUnavailable))
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _installation,
              decoration: InputDecoration(
                labelText: l10n.watchProvisionInstallation,
              ),
            ),
          ),
          ListTile(
            title: Text(_matchId ?? l10n.watchProvisionNoMatch),
            onTap: () => _chooseMatch(),
          ),
          ListTile(
            title: Text(l10n.watchProvisionPrepare),
            onTap: _prepare,
          ),
          if (_status.isNotEmpty) ListTile(title: Text(_status)),
          if (_bridge?.lastActivation != null)
            ListTile(
              title: Text(
                '${_bridge!.lastActivation!['matchId']} ${_bridge!.lastActivation!['installationId']}',
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _chooseMatch() async {
    final host = context;
    final matches = await AppScope.of(host).database.listNewestFirst();
    if (!mounted || !host.mounted) return;
    setState(() => _matches = matches);
    if (matches.isEmpty) {
      setState(() => _matchId = null);
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: host,
      builder: (context) {
        return ListView(
          children: [
            for (final match in matches)
              ListTile(
                title: Text(match.matchId),
                subtitle: Text(
                  '${match.teams.home.name ?? ''} — ${match.teams.away.name ?? ''}',
                ),
                onTap: () => Navigator.of(context).pop(match.matchId),
              ),
          ],
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() => _matchId = selected);
  }

  Future<void> _prepare() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    if (boundary == null || identity == null) return;
    Match? match;
    for (final item in _matches) {
      if (item.matchId == _matchId) match = item;
    }
    final support = await getApplicationSupportDirectory();
    if (!mounted) return;
    final bridge = _bridge ??
        WatchProvisionDebugBridge(
          boundary: boundary,
          phoneOriginDeviceId: identity.originDeviceId,
          correlationFile: File(
            '${support.path}/forref_watch_provision_correlation_v1.json',
          ),
        );
    _bridge = bridge;
    if (match == null) {
      setState(() => _status = 'missing');
      return;
    }
    final prepared = await bridge.prepareSavedMatch(
      match: match,
      installationId: _installation.text.trim(),
      principalId: identity.authorityPrincipalId,
    );
    if (!mounted) return;
    if (prepared.state != WatchProvisionState.configPrepared &&
        prepared.state != WatchProvisionState.phoneAuthorityLocked) {
      setState(() => _status = prepared.reason);
      return;
    }
    final listening = await bridge.start(match.matchId);
    if (!mounted) return;
    setState(() => _status = '${listening.name} ${prepared.contentHash}');
  }
}
