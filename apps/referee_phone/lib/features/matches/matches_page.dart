import 'dart:async';

import 'package:flutter/material.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/design/forref_components.dart';
import 'package:referee_phone/design/forref_spacing.dart';
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
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appTitle, style: Theme.of(context).textTheme.labelMedium),
            Text(l10n.matchesTitle),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.settingsPath),
            child: Text(l10n.settings),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: ForrefSpace.s16),
                  Text(l10n.checkingMatchState),
                ],
              ),
            )
          : sections.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ForrefSpace.s20,
                  ),
                  child: Center(
                    child: Text(
                      l10n.emptyMatches,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: ForrefSpace.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final section in sections) ...[
                        ForrefSectionHeader(
                          title: _groupLabel(l10n, section.group),
                          quiet: section.group == FixtureGroup.completed ||
                              section.group == FixtureGroup.notStarted,
                        ),
                        const Divider(height: 1),
                        for (final fixture in section.fixtures)
                          _FixtureTile(
                            fixture: fixture,
                            group: section.group,
                            onTap: () => _open(fixture),
                          ),
                      ],
                    ],
                  ),
                ),
      bottomNavigationBar: ForrefBottomAction(
        label: l10n.newMatch,
        onPressed: _newMatch,
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
    required this.group,
    required this.onTap,
  });

  final ListedFixture fixture;
  final FixtureGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
    final quiet =
        group == FixtureGroup.completed || group == FixtureGroup.notStarted;
    final current = group == FixtureGroup.current;
    final identity = ForrefFixtureIdentity(
      title: title,
      detail: details.join(' · '),
      large: current,
      color: quiet ? theme.colorScheme.onSurfaceVariant : null,
    );
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ForrefSpace.s20,
        vertical: ForrefSpace.s12,
      ),
      child: current
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: ForrefSpace.s12),
                Text(
                  l10n.liveMatch,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            )
          : identity,
    );
    return Material(
      color:
          current ? theme.colorScheme.surfaceContainerHigh : Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
