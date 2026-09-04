import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/routing/app_router.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  List<Match> _matches = const [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  Future<void> _reload() async {
    final db = AppScope.of(context).database;
    final list = await db.listNewestFirst();
    if (!mounted) return;
    setState(() {
      _matches = list;
      _loading = false;
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

  Future<void> _open(Match match) async {
    final route = switch (match.status) {
      MatchStatus.setup => AppRouter.matchSetup,
      MatchStatus.completed => AppRouter.matchSummary,
      _ => AppRouter.liveMatch,
    };
    await Navigator.of(context).pushNamed(route, arguments: match.matchId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          : _matches.isEmpty
              ? Center(child: Text(l10n.emptyMatches))
              : ListView(
                  children: [
                    for (final section in _sections(l10n)) ...[
                      ListTile(title: Text(section.label)),
                      for (final match in section.matches)
                        ListTile(
                          title: Text(
                            l10n.scoreLine(
                              homeLabel(match, l10n),
                              match.score.home,
                              match.score.away,
                              awayLabel(match, l10n),
                            ),
                          ),
                          subtitle: Text(matchStatusLabel(match, l10n)),
                          onTap: () => _open(match),
                        ),
                    ],
                  ],
                ),
      floatingActionButton: SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: _newMatch,
          child: Text(l10n.newMatch),
        ),
      ),
    );
  }

  List<_DaySection> _sections(AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<Match>>{};
    for (final match in _matches) {
      final parsed = DateTime.tryParse(match.date);
      final day = parsed == null
          ? today
          : DateTime(parsed.year, parsed.month, parsed.day);
      final label = day == today
          ? l10n.today
          : day == yesterday
              ? l10n.yesterday
              : l10n.older;
      groups.putIfAbsent(label, () => []).add(match);
    }
    return [
      for (final label in [l10n.today, l10n.yesterday, l10n.older])
        if (groups[label] != null)
          _DaySection(label: label, matches: groups[label]!),
    ];
  }
}

final class _DaySection {
  const _DaySection({required this.label, required this.matches});

  final String label;
  final List<Match> matches;
}
