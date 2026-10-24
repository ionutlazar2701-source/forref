import 'dart:async';

import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/l10n/preparation_labels.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/officiate/fixture_evidence.dart';
import 'package:referee_phone/officiate/fixture_list.dart';
import 'package:referee_phone/routing/app_router.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  List<ListedFixture> _fixtures = const [];
  bool _loading = true;
  int _evidenceGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _evidenceGeneration++;
    super.dispose();
  }

  Future<void> _reload() async {
    final scope = AppScope.of(context);
    final list = await scope.database.listNewestFirst();
    if (!mounted) return;
    setState(() {
      _fixtures = [
        for (final match in list)
          ListedFixture(match: match, evidence: const FixtureEvidence.none()),
      ];
      _loading = false;
    });
    final generation = ++_evidenceGeneration;
    final boundary = scope.matchApplication;
    // The frame future ends here. Match Memory reads run on the root event
    // loop so a widget-test pump is not left waiting on sqlite, and store
    // close is not queued behind a read that the fake zone will never run.
    Zone.root.scheduleMicrotask(() {
      unawaited(() async {
        final fixtures = await fixturesWithEvidence(
          boundary: boundary,
          matches: list,
          cancelled: () => !mounted || generation != _evidenceGeneration,
        );
        if (!mounted || generation != _evidenceGeneration) return;
        if (fixtures.length != list.length) return;
        setState(() => _fixtures = fixtures);
      }());
    });
  }

  Future<void> _newMatch() async {
    final db = AppScope.of(context).database;
    final match = newLocalMatch(DateTime.now());
    await db.upsertMatch(match);
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      AppRouter.matchSetup,
      arguments: match.matchId,
    );
    await _reload();
  }

  Future<void> _open(ListedFixture fixture) async {
    final group = classifyFixture(
      match: fixture.match,
      evidence: fixture.evidence,
      today: DateTime.now(),
    );
    final route = switch (group) {
      FixtureGroup.current => AppRouter.liveMatch,
      FixtureGroup.completed => AppRouter.matchSummary,
      FixtureGroup.upcoming ||
      FixtureGroup.needsAttention ||
      FixtureGroup.notStarted =>
        AppRouter.matchSetup,
    };
    await Navigator.of(context)
        .pushNamed(route, arguments: fixture.match.matchId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = groupFixtures(fixtures: _fixtures, today: DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.matchesTitle),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.settingsPath),
            child: Text(l10n.settings),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : sections.isEmpty
              ? Center(child: Text(l10n.emptyMatches))
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final section in sections) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          _groupLabel(l10n, section.group),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Divider(height: 1),
                      for (final fixture in section.fixtures)
                        _FixtureTile(
                          fixture: fixture,
                          emphasized: section.group == FixtureGroup.current,
                          onTap: () => _open(fixture),
                        ),
                    ],
                  ],
                ),
      floatingActionButton: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _newMatch,
          child: Text(l10n.newMatch),
        ),
      ),
    );
  }

  String _groupLabel(AppLocalizations l10n, FixtureGroup group) {
    return switch (group) {
      FixtureGroup.current => l10n.fixtureGroupCurrent,
      FixtureGroup.upcoming => l10n.fixtureGroupUpcoming,
      FixtureGroup.needsAttention => l10n.fixtureGroupNeedsAttention,
      FixtureGroup.notStarted => l10n.fixtureGroupNotStarted,
      FixtureGroup.completed => l10n.fixtureGroupCompleted,
    };
  }
}

class _FixtureTile extends StatelessWidget {
  const _FixtureTile({
    required this.fixture,
    required this.emphasized,
    required this.onTap,
  });

  final ListedFixture fixture;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = fixture.match;
    final attention = fixtureAttention(match);
    final competition = match.competition?.trim();
    final details = <String>[
      match.date,
      if (competition != null && competition.isNotEmpty) competition,
      matchStatusLabel(match, l10n),
      if (attention != null) preparationBlockerLabel(l10n, attention),
    ];
    final title = fixtureTitle(
      match,
      homeNotSet: l10n.homeTeamNotSet,
      awayNotSet: l10n.awayTeamNotSet,
    );
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title),
      subtitle: Text(details.join(' · ')),
      onTap: onTap,
    );
    if (!emphasized) return tile;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: tile,
    );
  }
}
