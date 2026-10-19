import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  test('empty team-official id is rejected', () {
    expect(() => MatchTeamOfficialId(''), throwsArgumentError);
  });

  test('team-official value equality ignores display attributes', () {
    final first = MatchTeamOfficialId('official-7');
    final second = MatchTeamOfficialId.parseWire(first.wireValue);
    final labels = {first: 'Coach', second: 'Assistant'};
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(labels[first], 'Assistant');
    expect(first.value.contains('Coach'), isFalse);
  });

  test('match scope distinguishes the same team-official token', () {
    final official = MatchTeamOfficialId('official-7');
    final home = MatchScopedTeamOfficialId(
      matchId: 'match-1',
      teamOfficialId: official,
    );
    final away = MatchScopedTeamOfficialId(
      matchId: 'match-2',
      teamOfficialId: official,
    );
    expect(home.teamOfficialId, away.teamOfficialId);
    expect(home, isNot(away));
    expect(MatchScopedTeamOfficialId.fromJson(home.toJson()), home);
  });

  test('participant and team official with the same raw token are distinct', () {
    const token = '123';
    final participant = ParticipantDisciplinarySubject(MatchParticipantId(token));
    final official = TeamOfficialDisciplinarySubject(MatchTeamOfficialId(token));
    expect(participant.rawId, official.rawId);
    expect(participant, isNot(official));
    expect(participant.hashCode, isNot(official.hashCode));
    expect(
      DisciplinarySubjectRef.parseJson(participant.toJson()),
      participant,
    );
    expect(DisciplinarySubjectRef.parseJson(official.toJson()), official);
    expect(participant.toJson()['subjectKind'], 'PARTICIPANT');
    expect(official.toJson()['subjectKind'], 'TEAM_OFFICIAL');
  });

  test('team association round-trips and does not store a display name', () {
    final binding = TeamOfficialTeamBinding(
      matchId: 'match-1',
      teamOfficialId: MatchTeamOfficialId('official-7'),
      teamId: MatchTeamId('team-alpha'),
    );
    expect(TeamOfficialTeamBinding.fromJson(binding.toJson()), binding);
    expect(binding.toJson().keys, ['matchId', 'teamOfficialId', 'teamId']);
  });

  test('two teams for one official are ambiguous', () {
    final official = MatchTeamOfficialId('official-7');
    final assessment = assessTeamOfficialTeamBinding(
      matchId: 'match-1',
      teamOfficialId: official,
      bindings: [
        TeamOfficialTeamBinding(
          matchId: 'match-1',
          teamOfficialId: official,
          teamId: MatchTeamId('team-alpha'),
        ),
        TeamOfficialTeamBinding(
          matchId: 'match-1',
          teamOfficialId: official,
          teamId: MatchTeamId('team-beta'),
        ),
      ],
    );
    expect(assessment, isA<AmbiguousTeamOfficialBinding>());
  });

  test('a binding in another match is not applicable', () {
    final official = MatchTeamOfficialId('official-7');
    final assessment = assessTeamOfficialTeamBinding(
      matchId: 'match-1',
      teamOfficialId: official,
      bindings: [
        TeamOfficialTeamBinding(
          matchId: 'match-2',
          teamOfficialId: official,
          teamId: MatchTeamId('team-alpha'),
        ),
      ],
    );
    expect(assessment, isA<MissingTeamOfficialBinding>());
  });

  test('participant identity behavior is unchanged', () {
    final id = MatchParticipantId('123');
    expect(id, MatchParticipantId.parseWire('123'));
    expect(
      ParticipantDisciplinarySubject(id),
      isNot(MatchParticipantId('123')),
    );
  });
}
