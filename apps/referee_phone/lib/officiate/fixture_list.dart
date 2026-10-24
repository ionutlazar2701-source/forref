import 'package:match_core/match_core.dart';

import 'preparation_assessment.dart';

/// Match-list groups. A fixture is in exactly one group.
enum FixtureGroup {
  current,
  upcoming,
  needsAttention,
  notStarted,
  completed,
}

/// Authoritative start/end when Match Memory has been read.
///
/// Both flags stay false when that read is unavailable. Legacy status is then
/// the only lifecycle evidence, and a missing read is not treated as started.
final class FixtureEvidence {
  const FixtureEvidence({
    required this.authoritativelyStarted,
    required this.authoritativelyEnded,
  });

  const FixtureEvidence.none()
      : authoritativelyStarted = false,
        authoritativelyEnded = false;

  final bool authoritativelyStarted;
  final bool authoritativelyEnded;
}

final class ListedFixture {
  const ListedFixture({required this.match, required this.evidence});

  final Match match;
  final FixtureEvidence evidence;
}

final class FixtureSection {
  const FixtureSection({required this.group, required this.fixtures});

  final FixtureGroup group;
  final List<ListedFixture> fixtures;
}

const fixtureGroupOrder = <FixtureGroup>[
  FixtureGroup.current,
  FixtureGroup.upcoming,
  FixtureGroup.needsAttention,
  FixtureGroup.notStarted,
  FixtureGroup.completed,
];

bool fixtureIdentityComplete(Match match) {
  return _named(match.teams.home.name) &&
      _named(match.teams.away.name) &&
      match.settings.halfDurationSeconds > 0;
}

String fixtureTitle(
  Match match, {
  required String homeNotSet,
  required String awayNotSet,
}) {
  final home = _named(match.teams.home.name)
      ? match.teams.home.name!.trim()
      : homeNotSet;
  final away = _named(match.teams.away.name)
      ? match.teams.away.name!.trim()
      : awayNotSet;
  return '$home — $away';
}

FixtureGroup classifyFixture({
  required Match match,
  required FixtureEvidence evidence,
  required DateTime today,
}) {
  if (evidence.authoritativelyEnded || match.status == MatchStatus.completed) {
    return FixtureGroup.completed;
  }
  if (evidence.authoritativelyStarted || _legacyInProgress(match.status)) {
    return FixtureGroup.current;
  }
  if (!fixtureIdentityComplete(match)) return FixtureGroup.needsAttention;
  final day = _parseDay(match.date);
  final todayDay = DateTime(today.year, today.month, today.day);
  if (day != null && day.isBefore(todayDay)) return FixtureGroup.notStarted;
  return FixtureGroup.upcoming;
}

List<FixtureSection> groupFixtures({
  required List<ListedFixture> fixtures,
  required DateTime today,
}) {
  final grouped = <FixtureGroup, List<ListedFixture>>{};
  for (final fixture in fixtures) {
    final group = classifyFixture(
      match: fixture.match,
      evidence: fixture.evidence,
      today: today,
    );
    grouped.putIfAbsent(group, () => []).add(fixture);
  }
  return [
    for (final group in fixtureGroupOrder)
      if (grouped[group] != null)
        FixtureSection(
          group: group,
          fixtures: _sorted(grouped[group]!),
        ),
  ];
}

/// First concrete identity blocker, when the stored fixture is incomplete.
PreparationBlocker? fixtureAttention(Match match) {
  if (!_named(match.teams.home.name)) {
    return PreparationBlocker.homeTeamRequired;
  }
  if (!_named(match.teams.away.name)) {
    return PreparationBlocker.awayTeamRequired;
  }
  if (match.settings.halfDurationSeconds <= 0) {
    return PreparationBlocker.halfLengthRequired;
  }
  return null;
}

bool _legacyInProgress(MatchStatus status) {
  return status == MatchStatus.live ||
      status == MatchStatus.paused ||
      status == MatchStatus.halfTime ||
      status == MatchStatus.fullTime;
}

bool _named(String? name) => name != null && name.trim().isNotEmpty;

DateTime? _parseDay(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

List<ListedFixture> _sorted(List<ListedFixture> fixtures) {
  final copy = [...fixtures];
  copy.sort((a, b) {
    final byDate = b.match.date.compareTo(a.match.date);
    if (byDate != 0) return byDate;
    return a.match.matchId.compareTo(b.match.matchId);
  });
  return copy;
}
