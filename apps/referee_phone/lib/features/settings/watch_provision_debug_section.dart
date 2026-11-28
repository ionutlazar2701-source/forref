import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
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

class _WatchProvisionDebugSectionState
    extends State<WatchProvisionDebugSection> {
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
    final storage = scope.storageRoot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(title: Text(l10n.watchProvisionTitle)),
        if (boundary == null || identity == null || storage == null)
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
          ListTile(
            title: Text(l10n.watchProvisionInspect),
            onTap: _inspect,
          ),
          ListTile(
            title: Text(l10n.watchProvisionCancel),
            onTap: _cancelPrepared,
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
    final root = scope.storageRoot;
    if (root == null || !mounted) return;
    final bridge = _bridge ??
        WatchProvisionDebugBridge(
          boundary: boundary,
          phoneOriginDeviceId: identity.originDeviceId,
          correlationFile: File(
            '${root.path}/forref_watch_provision_correlation_v1.json',
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
      final report =
          await _loadInspection(match, identity.authorityPrincipalId);
      if (!mounted) return;
      final line = report == null ? '' : report.line;
      setState(() => _status =
          line.isEmpty ? prepared.reason : '${prepared.reason} $line');
      return;
    }
    final listening = await bridge.start(match.matchId);
    if (!mounted) return;
    setState(() => _status = '${listening.name} ${prepared.contentHash}');
  }

  Future<void> _inspect() async {
    final scope = AppScope.of(context);
    final identity = scope.captureIdentity;
    final match = _selectedMatch();
    if (identity == null || match == null) {
      setState(() => _status = 'missing');
      return;
    }
    final report = await _loadInspection(match, identity.authorityPrincipalId);
    if (!mounted) return;
    final correlation = describeDebugCorrelation(_correlationText());
    setState(() => _status =
        report == null ? 'match $correlation' : '${report.line} $correlation');
  }

  Future<void> _cancelPrepared() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    final match = _selectedMatch();
    if (boundary == null || identity == null || match == null) {
      setState(() => _status = 'missing');
      return;
    }
    final report = await _loadInspection(match, identity.authorityPrincipalId);
    if (!mounted) return;
    if (report == null || !report.present) {
      setState(() => _status = 'not-prepared');
      return;
    }
    final outcome = await boundary.cancelPreparedWatchMatch(
      matchId: report.matchId,
      contentHash: report.contentHash,
    );
    if (!mounted) return;
    setState(() => _status = outcome.reason);
  }

  String? _correlationText() {
    final root = AppScope.of(context).storageRoot;
    if (root == null) return null;
    final file =
        File('${root.path}/forref_watch_provision_correlation_v1.json');
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  Match? _selectedMatch() {
    for (final item in _matches) {
      if (item.matchId == _matchId) return item;
    }
    return null;
  }

  Future<WatchProvisionInspection?> _loadInspection(
    Match match,
    String principalId,
  ) async {
    final boundary = AppScope.of(context).matchApplication;
    if (boundary == null) return null;
    final document = documentForSavedMatch(
      match: match,
      principalId: principalId,
      installationId: _installation.text.trim(),
    );
    if (document == null) return null;
    return boundary.inspectWatchProvision(
      matchId: match.matchId,
      requestedContentHash: document.contentHash,
      requestedWriterDeviceId: document.writerDeviceId,
      requestedPrincipalId: document.principalId,
    );
  }
}
