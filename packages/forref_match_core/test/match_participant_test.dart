import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  test('same MatchParticipantId value compares equal', () {
    expect(MatchParticipantId('p-1'), MatchParticipantId('p-1'));
    expect(MatchParticipantId('p-1').hashCode, MatchParticipantId('p-1').hashCode);
  });

  test('different ids stay distinct', () {
    expect(MatchParticipantId('p-1'), isNot(MatchParticipantId('p-2')));
  });

  test('shirt number collision does not merge identity', () {
    const shirt = '7';
    final first = MatchParticipantId('person-a');
    final second = MatchParticipantId('person-b');
    expect(first, isNot(second));
    expect(first.value, isNot(shirt));
    expect(second.value, isNot(shirt));
    expect(
      MatchParticipantId(shirt),
      isNot(first),
    );
  });

  test('status change does not create a new id', () {
    final id = MatchParticipantId('person-a');
    const before = ParticipantSituation.onField;
    const after = ParticipantSituation.substituted;
    expect(before, isNot(after));
    expect(id, MatchParticipantId('person-a'));
  });

  test('participant ids from different matches do not alias', () {
    final token = MatchParticipantId('person-a');
    final home = MatchScopedParticipantId(matchId: 'match-1', participantId: token);
    final away = MatchScopedParticipantId(matchId: 'match-2', participantId: token);
    expect(home.participantId, away.participantId);
    expect(home, isNot(away));
  });

  test('malformed empty id is rejected', () {
    expect(() => MatchParticipantId(''), throwsArgumentError);
    expect(
      () => MatchScopedParticipantId(
        matchId: '',
        participantId: MatchParticipantId('person-a'),
      ),
      throwsArgumentError,
    );
  });

  test('serialization roundtrip preserves identity', () {
    final scoped = MatchScopedParticipantId(
      matchId: 'match-1',
      participantId: MatchParticipantId('person-a'),
    );
    expect(MatchParticipantId.parseWire(scoped.participantId.wireValue), scoped.participantId);
    expect(MatchScopedParticipantId.fromJson(scoped.toJson()), scoped);
  });

  test('team binding does not replace the participant id', () {
    final id = MatchParticipantId('person-a');
    final binding = MatchParticipantTeamBinding(
      matchId: 'match-1',
      participantId: id,
      teamId: MatchTeamId('team-alpha'),
    );
    expect(binding.participantId, id);
    expect(binding.teamId.value, isNot(id.value));
  });
}