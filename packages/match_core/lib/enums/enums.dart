/// Frozen schema enums. JSON strings live in [jsonValue].
library;

enum MatchStatus {
  setup('setup'),
  ready('ready'),
  live('live'),
  paused('paused'),
  halfTime('half_time'),
  fullTime('full_time'),
  completed('completed');

  const MatchStatus(this.jsonValue);
  final String jsonValue;
}

enum PeriodId {
  firstHalf('1h'),
  secondHalf('2h'),
  extraTime1('et1'),
  extraTime2('et2'),

  /// Reserved. Do not activate in MVP.
  penalties('pens');

  const PeriodId(this.jsonValue);
  final String jsonValue;
}

enum PeriodStatus {
  pending('pending'),
  active('active'),
  paused('paused'),
  completed('completed');

  const PeriodStatus(this.jsonValue);
  final String jsonValue;
}

enum EventType {
  goal('goal'),
  yellowCard('yellow_card'),
  redCard('red_card'),
  substitution('substitution'),
  injury('injury');

  const EventType(this.jsonValue);
  final String jsonValue;
}

enum EventStatus {
  complete('complete'),
  incomplete('incomplete');

  const EventStatus(this.jsonValue);
  final String jsonValue;
}

enum SyncState {
  localOnly('local_only'),
  pending('pending'),
  synced('synced'),
  error('error');

  const SyncState(this.jsonValue);
  final String jsonValue;
}

enum PlayerRole {
  starter('starter'),
  substitute('substitute');

  const PlayerRole(this.jsonValue);
  final String jsonValue;
}

enum HistoryAction {
  update('update'),
  undo('undo');

  const HistoryAction(this.jsonValue);
  final String jsonValue;
}
