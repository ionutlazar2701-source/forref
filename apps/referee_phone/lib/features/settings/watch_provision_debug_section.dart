import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/officiate/watch_enroll_session.dart';
import 'package:referee_phone/officiate/watch_match_transfer.dart';
import 'package:referee_phone/officiate/watch_pairing_session.dart';
import 'package:referee_phone/officiate/watch_provision_debug_bridge.dart';

/// Debug-only control for the local watch provision bridge.
class WatchProvisionDebugSection extends StatefulWidget {
  const WatchProvisionDebugSection({super.key});

  @override
  State<WatchProvisionDebugSection> createState() =>
      _WatchProvisionDebugSectionState();
}

class _WatchProvisionDebugSectionState extends State<WatchProvisionDebugSection>
    with WidgetsBindingObserver {
  final TextEditingController _installation = TextEditingController();
  WatchProvisionDebugBridge? _bridge;
  WatchProvisionDebugBridge? _enrollBridge;
  WatchProvisionDebugBridge? _pairBridge;
  WatchProvisionDebugBridge? _transferBridge;
  String _transferStatus = '';
  List<Match> _matches = const [];
  String? _matchId;
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _installation.dispose();
    _bridge?.stop();
    _enrollBridge?.stop();
    _pairBridge?.stop();
    _transferBridge?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pairBridge?.resumePairing();
      _transferBridge?.resumeTransfer();
    }
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
          ListTile(
            title: Text(l10n.watchPairConnect),
            subtitle: Text(_pairSubtitle(l10n)),
            onTap: _connectWatch,
          ),
          ListTile(
            title: Text(l10n.watchTransferSend),
            subtitle: Text(_transferSubtitle(l10n)),
            onTap: _sendToWatch,
          ),
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
            title: Text(l10n.watchProvisionListen),
            onTap: _listen,
          ),
          ListTile(
            title: Text(l10n.watchProvisionInspect),
            onTap: _inspect,
          ),
          ListTile(
            title: Text(l10n.watchProvisionCancel),
            onTap: _cancelPrepared,
          ),
          ListTile(
            title: Text(l10n.watchProvisionEnroll),
            onTap: _enroll,
          ),
          ListTile(
            title: Text(l10n.watchProvisionReadEnroll),
            onTap: _readEnroll,
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

  String _pairSubtitle(AppLocalizations l10n) {
    final result = _pairBridge?.pairingResult;
    if (result == null) return l10n.watchPairHint;
    final stored = watchInstallationPreview(result.storedWriter);
    final request = watchInstallationPreview(result.requestInstallation);
    return switch (result.code) {
      'waiting' => l10n.watchPairWaiting,
      'verified' => l10n.watchPairVerified(request),
      'replay' => l10n.watchPairReplay(request),
      'writer-kept' => l10n.watchPairWriterKept(stored, request),
      _ => l10n.watchPairFailed(result.reason),
    };
  }

  String _transferSubtitle(AppLocalizations l10n) {
    final result = _transferBridge?.transferResult;
    final code = result?.code ?? _transferStatus;
    if (code.isEmpty) return l10n.watchTransferHint;
    final minutes = (result?.halfDurationMs ?? 0) ~/ 60000;
    final home = result?.homeName ?? '';
    final away = result?.awayName ?? '';
    return switch (code) {
      'waiting' => l10n.watchTransferWaiting,
      'verified' => l10n.watchTransferVerified(home, away, minutes),
      'replay' => l10n.watchTransferReplay(home, away, minutes),
      'writer-kept' => l10n.watchTransferKept(result?.reason ?? ''),
      'unpaired' => l10n.watchTransferUnpaired,
      'fixture' => l10n.watchTransferFixture,
      'started' => l10n.watchTransferStarted,
      'conflict' => l10n.watchTransferConflict,
      _ => l10n.watchTransferFailed(
          result != null && result.reason.isNotEmpty ? result.reason : code),
    };
  }

  Future<void> _sendToWatch() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    final root = scope.storageRoot;
    final database = scope.database;
    final match = _selectedMatch();
    if (boundary == null || identity == null || root == null || match == null) {
      setState(() => _status = 'missing');
      return;
    }
    await _bridge?.stop();
    await _enrollBridge?.stop();
    await _pairBridge?.stop();
    final bridge = _transferBridge ??
        WatchProvisionDebugBridge(
          boundary: boundary,
          phoneOriginDeviceId: identity.originDeviceId,
          correlationFile: File('${root.path}/$transferWatchCorrelationName'),
        );
    _transferBridge = bridge;
    bridge.removeListener(_onTransfer);
    bridge.addListener(_onTransfer);
    final opened = await sendMatchToWatch(
      storageRoot: root,
      database: database,
      boundary: boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      match: match,
      transferBridge: bridge,
      historicalBridge: _bridge,
      pairBridge: _pairBridge,
      enrollBridge: _enrollBridge,
    );
    if (!mounted) return;
    setState(() => _transferStatus = opened.status);
  }

  void _onTransfer() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _connectWatch() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    final root = scope.storageRoot;
    final database = scope.database;
    if (boundary == null || identity == null || root == null) {
      setState(() => _status = 'missing');
      return;
    }
    await _bridge?.stop();
    await _enrollBridge?.stop();
    await _transferBridge?.stop();
    final bridge = _pairBridge ??
        WatchProvisionDebugBridge(
          boundary: boundary,
          phoneOriginDeviceId: identity.originDeviceId,
          correlationFile: File('${root.path}/$pairWatchCorrelationName'),
        );
    _pairBridge = bridge;
    bridge.removeListener(_onPairing);
    bridge.addListener(_onPairing);
    final opened = await openWatchPairing(
      storageRoot: root,
      database: database,
      boundary: boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      pairBridge: bridge,
      historicalBridge: _bridge,
    );
    if (!mounted) return;
    setState(() => _status = opened.line);
  }

  void _onPairing() {
    if (!mounted) return;
    setState(() {});
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
    await _enrollBridge?.stop();
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

  Future<void> _listen() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    final root = scope.storageRoot;
    final match = _selectedMatch();
    if (boundary == null || identity == null || root == null || match == null) {
      setState(() => _status = 'missing');
      return;
    }
    await _enrollBridge?.stop();
    final bridge = _bridge ??
        WatchProvisionDebugBridge(
          boundary: boundary,
          phoneOriginDeviceId: identity.originDeviceId,
          correlationFile: File(
            '${root.path}/forref_watch_provision_correlation_v1.json',
          ),
        );
    _bridge = bridge;
    final listening = await bridge.start(match.matchId);
    if (!mounted) return;
    setState(() => _status = listening.name);
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

  Future<void> _enroll() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final identity = scope.captureIdentity;
    final root = scope.storageRoot;
    final database = scope.database;
    if (boundary == null || identity == null || root == null) {
      setState(() => _status = 'missing');
      return;
    }
    final enroll = _enrollBridge ??
        WatchProvisionDebugBridge(
          boundary: boundary,
          phoneOriginDeviceId: identity.originDeviceId,
          correlationFile: File('${root.path}/$enrollWatchCorrelationName'),
        );
    _enrollBridge = enroll;
    final opened = await openWatchEnrollment(
      storageRoot: root,
      database: database,
      boundary: boundary,
      phoneOriginDeviceId: identity.originDeviceId,
      principalId: identity.authorityPrincipalId,
      installationId: _installation.text.trim(),
      enrollBridge: enroll,
      historicalBridge: _bridge,
    );
    if (!mounted) return;
    setState(() => _status = opened.line);
  }

  Future<void> _readEnroll() async {
    final scope = AppScope.of(context);
    final boundary = scope.matchApplication;
    final root = scope.storageRoot;
    if (boundary == null || root == null) {
      setState(() => _status = 'missing');
      return;
    }
    final line = await describeWatchEnrollment(
      storageRoot: root,
      store: boundary.durableStore,
      database: scope.database,
      installationId: _installation.text.trim(),
    );
    if (!mounted) return;
    setState(() => _status = line);
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
