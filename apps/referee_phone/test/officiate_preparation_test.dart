import 'package:flutter_test/flutter_test.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/match/new_match.dart';
import 'package:referee_phone/officiate/fixture_list.dart';
import 'package:referee_phone/officiate/preparation_assessment.dart';

void main() {
  Match named(Match match, {String? home, String? away, String? date}) {
    return match.copyWith(
      date: date,
      teams: Teams(
        home: match.teams.home.copyWith(
          name: home,
          clearName: home == null || home.trim().isEmpty,
        ),
        away: match.teams.away.copyWith(
          name: away,
          clearName: away == null || away.trim().isEmpty,
        ),
      ),
    );
  }

  test('empty identity is not a fabricated fixture name', () {
    final match = newLocalMatch(DateTime(2026, 10, 24));
    expect(
      fixtureTitle(match,
          homeNotSet: 'Home team not set', awayNotSet: 'Away team not set'),
      'Home team not set — Away team not set',
    );
    expect(
        fixtureTitle(match,
            homeNotSet: 'Home team not set', awayNotSet: 'Away team not set'),
        isNot(contains('HOME')));
  });

  test('a ready match is not current without start evidence', () {
    final today = DateTime(2026, 10, 24);
    final match = named(
      newLocalMatch(today).copyWith(status: MatchStatus.ready),
      home: 'North',
      away: 'South',
    );
    expect(
      classifyFixture(
        match: match,
        evidence: const FixtureEvidence.none(),
        today: today,
      ),
      FixtureGroup.upcoming,
    );
  });

  test('authoritative start is current even when legacy status is ready', () {
    final today = DateTime(2026, 10, 24);
    final match = named(
      newLocalMatch(today).copyWith(status: MatchStatus.ready),
      home: 'North',
      away: 'South',
    );
    expect(
      classifyFixture(
        match: match,
        evidence: const FixtureEvidence(
          authoritativelyStarted: true,
          authoritativelyEnded: false,
        ),
        today: today,
      ),
      FixtureGroup.current,
    );
  });

  test('normal end is completed and full time is not', () {
    final today = DateTime(2026, 10, 24);
    final fullTime = named(
      newLocalMatch(today).copyWith(status: MatchStatus.fullTime),
      home: 'North',
      away: 'South',
    );
    expect(
      classifyFixture(
        match: fullTime,
        evidence: const FixtureEvidence.none(),
        today: today,
      ),
      FixtureGroup.current,
    );
    final ended = named(
      newLocalMatch(today).copyWith(status: MatchStatus.ready),
      home: 'North',
      away: 'South',
    );
    expect(
      classifyFixture(
        match: ended,
        evidence: const FixtureEvidence(
          authoritativelyStarted: true,
          authoritativelyEnded: true,
        ),
        today: today,
      ),
      FixtureGroup.completed,
    );
    expect(
      classifyFixture(
        match: fullTime.copyWith(status: MatchStatus.completed),
        evidence: const FixtureEvidence.none(),
        today: today,
      ),
      FixtureGroup.completed,
    );
  });

  test('incomplete identity is needs attention, not upcoming', () {
    final today = DateTime(2026, 10, 24);
    final match = named(newLocalMatch(today), home: 'North');
    expect(
      classifyFixture(
        match: match,
        evidence: const FixtureEvidence.none(),
        today: today,
      ),
      FixtureGroup.needsAttention,
    );
    expect(fixtureAttention(match), PreparationBlocker.awayTeamRequired);
  });

  test('a past unstarted fixture is not started, not current', () {
    final today = DateTime(2026, 10, 24);
    final match = named(
      newLocalMatch(DateTime(2026, 10, 1)),
      home: 'North',
      away: 'South',
      date: '2026-10-01',
    );
    expect(
      classifyFixture(
        match: match,
        evidence: const FixtureEvidence.none(),
        today: today,
      ),
      FixtureGroup.notStarted,
    );
  });

  test('similar fixtures stay distinct by date', () {
    final today = DateTime(2026, 10, 24);
    final first = named(
      newLocalMatch(today),
      home: 'North',
      away: 'South',
      date: '2026-10-24',
    ).copyWith(competition: 'Cup');
    final second = named(
      newLocalMatch(today),
      home: 'North',
      away: 'South',
      date: '2026-10-25',
    );
    final sections = groupFixtures(
      fixtures: [
        ListedFixture(match: second, evidence: const FixtureEvidence.none()),
        ListedFixture(match: first, evidence: const FixtureEvidence.none()),
      ],
      today: today,
    );
    expect(sections.single.group, FixtureGroup.upcoming);
    expect(sections.single.fixtures.map((item) => item.match.date), [
      '2026-10-25',
      '2026-10-24',
    ]);
    expect(first.competition, 'Cup');
  });

  test('optional gaps do not block and readiness does not overclaim', () {
    final missingCrew = assessPreparation(
      homeName: 'North',
      awayName: 'South',
      halfMinutes: 45,
      localStorageReady: true,
      authorityKnown: true,
      temporalEvidenceReady: true,
    );
    expect(missingCrew.canEnterLiveMatch, isTrue);
    expect(
      missingCrew.claim,
      PreparationClaim.readyToOfficiateOnThisPhone,
    );

    final missingNames = assessPreparation(
      homeName: ' ',
      awayName: '',
      halfMinutes: 45,
      localStorageReady: true,
      authorityKnown: true,
      temporalEvidenceReady: true,
    );
    expect(missingNames.canEnterLiveMatch, isFalse);
    expect(missingNames.claim, PreparationClaim.needsAttention);
    expect(
      missingNames.claim,
      isNot(PreparationClaim.readyToOfficiateOnThisPhone),
    );

    final noTemporal = assessPreparation(
      homeName: 'North',
      awayName: 'South',
      halfMinutes: 45,
      localStorageReady: true,
      authorityKnown: true,
      temporalEvidenceReady: false,
    );
    expect(noTemporal.canEnterLiveMatch, isTrue);
    expect(noTemporal.claim, PreparationClaim.matchSetupReady);

    final noAuthority = assessPreparation(
      homeName: 'North',
      awayName: 'South',
      halfMinutes: 45,
      localStorageReady: true,
      authorityKnown: false,
      temporalEvidenceReady: true,
    );
    expect(noAuthority.canEnterLiveMatch, isFalse);
    expect(noAuthority.claim, PreparationClaim.recordingAuthorityUnconfirmed);

    final noStore = assessPreparation(
      homeName: 'North',
      awayName: 'South',
      halfMinutes: 45,
      localStorageReady: false,
      authorityKnown: true,
      temporalEvidenceReady: true,
    );
    expect(noStore.canEnterLiveMatch, isFalse);
    expect(
      noStore.blockers,
      contains(PreparationBlocker.localRecordingUnavailable),
    );
  });
}
