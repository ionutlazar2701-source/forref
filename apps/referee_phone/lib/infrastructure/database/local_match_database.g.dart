// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_match_database.dart';

// ignore_for_file: type=lint
class $MatchesTable extends Matches with TableInfo<$MatchesTable, StoredMatch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _matchIdMeta =
      const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
      'match_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _scoreHomeMeta =
      const VerificationMeta('scoreHome');
  @override
  late final GeneratedColumn<int> scoreHome = GeneratedColumn<int>(
      'score_home', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _scoreAwayMeta =
      const VerificationMeta('scoreAway');
  @override
  late final GeneratedColumn<int> scoreAway = GeneratedColumn<int>(
      'score_away', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _homeNameMeta =
      const VerificationMeta('homeName');
  @override
  late final GeneratedColumn<String> homeName = GeneratedColumn<String>(
      'home_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _awayNameMeta =
      const VerificationMeta('awayName');
  @override
  late final GeneratedColumn<String> awayName = GeneratedColumn<String>(
      'away_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStateMeta =
      const VerificationMeta('syncState');
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
      'sync_state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _documentJsonMeta =
      const VerificationMeta('documentJson');
  @override
  late final GeneratedColumn<String> documentJson = GeneratedColumn<String>(
      'document_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        matchId,
        status,
        date,
        createdAt,
        updatedAt,
        scoreHome,
        scoreAway,
        homeName,
        awayName,
        syncState,
        documentJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches';
  @override
  VerificationContext validateIntegrity(Insertable<StoredMatch> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta,
          matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('score_home')) {
      context.handle(_scoreHomeMeta,
          scoreHome.isAcceptableOrUnknown(data['score_home']!, _scoreHomeMeta));
    } else if (isInserting) {
      context.missing(_scoreHomeMeta);
    }
    if (data.containsKey('score_away')) {
      context.handle(_scoreAwayMeta,
          scoreAway.isAcceptableOrUnknown(data['score_away']!, _scoreAwayMeta));
    } else if (isInserting) {
      context.missing(_scoreAwayMeta);
    }
    if (data.containsKey('home_name')) {
      context.handle(_homeNameMeta,
          homeName.isAcceptableOrUnknown(data['home_name']!, _homeNameMeta));
    }
    if (data.containsKey('away_name')) {
      context.handle(_awayNameMeta,
          awayName.isAcceptableOrUnknown(data['away_name']!, _awayNameMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(_syncStateMeta,
          syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta));
    } else if (isInserting) {
      context.missing(_syncStateMeta);
    }
    if (data.containsKey('document_json')) {
      context.handle(
          _documentJsonMeta,
          documentJson.isAcceptableOrUnknown(
              data['document_json']!, _documentJsonMeta));
    } else if (isInserting) {
      context.missing(_documentJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {matchId};
  @override
  StoredMatch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredMatch(
      matchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      scoreHome: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}score_home'])!,
      scoreAway: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}score_away'])!,
      homeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}home_name']),
      awayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}away_name']),
      syncState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_state'])!,
      documentJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_json'])!,
    );
  }

  @override
  $MatchesTable createAlias(String alias) {
    return $MatchesTable(attachedDatabase, alias);
  }
}

class StoredMatch extends DataClass implements Insertable<StoredMatch> {
  final String matchId;
  final String status;
  final String date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int scoreHome;
  final int scoreAway;
  final String? homeName;
  final String? awayName;
  final String syncState;
  final String documentJson;
  const StoredMatch(
      {required this.matchId,
      required this.status,
      required this.date,
      required this.createdAt,
      required this.updatedAt,
      required this.scoreHome,
      required this.scoreAway,
      this.homeName,
      this.awayName,
      required this.syncState,
      required this.documentJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['match_id'] = Variable<String>(matchId);
    map['status'] = Variable<String>(status);
    map['date'] = Variable<String>(date);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['score_home'] = Variable<int>(scoreHome);
    map['score_away'] = Variable<int>(scoreAway);
    if (!nullToAbsent || homeName != null) {
      map['home_name'] = Variable<String>(homeName);
    }
    if (!nullToAbsent || awayName != null) {
      map['away_name'] = Variable<String>(awayName);
    }
    map['sync_state'] = Variable<String>(syncState);
    map['document_json'] = Variable<String>(documentJson);
    return map;
  }

  MatchesCompanion toCompanion(bool nullToAbsent) {
    return MatchesCompanion(
      matchId: Value(matchId),
      status: Value(status),
      date: Value(date),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      scoreHome: Value(scoreHome),
      scoreAway: Value(scoreAway),
      homeName: homeName == null && nullToAbsent
          ? const Value.absent()
          : Value(homeName),
      awayName: awayName == null && nullToAbsent
          ? const Value.absent()
          : Value(awayName),
      syncState: Value(syncState),
      documentJson: Value(documentJson),
    );
  }

  factory StoredMatch.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredMatch(
      matchId: serializer.fromJson<String>(json['matchId']),
      status: serializer.fromJson<String>(json['status']),
      date: serializer.fromJson<String>(json['date']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      scoreHome: serializer.fromJson<int>(json['scoreHome']),
      scoreAway: serializer.fromJson<int>(json['scoreAway']),
      homeName: serializer.fromJson<String?>(json['homeName']),
      awayName: serializer.fromJson<String?>(json['awayName']),
      syncState: serializer.fromJson<String>(json['syncState']),
      documentJson: serializer.fromJson<String>(json['documentJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'matchId': serializer.toJson<String>(matchId),
      'status': serializer.toJson<String>(status),
      'date': serializer.toJson<String>(date),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'scoreHome': serializer.toJson<int>(scoreHome),
      'scoreAway': serializer.toJson<int>(scoreAway),
      'homeName': serializer.toJson<String?>(homeName),
      'awayName': serializer.toJson<String?>(awayName),
      'syncState': serializer.toJson<String>(syncState),
      'documentJson': serializer.toJson<String>(documentJson),
    };
  }

  StoredMatch copyWith(
          {String? matchId,
          String? status,
          String? date,
          DateTime? createdAt,
          DateTime? updatedAt,
          int? scoreHome,
          int? scoreAway,
          Value<String?> homeName = const Value.absent(),
          Value<String?> awayName = const Value.absent(),
          String? syncState,
          String? documentJson}) =>
      StoredMatch(
        matchId: matchId ?? this.matchId,
        status: status ?? this.status,
        date: date ?? this.date,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        scoreHome: scoreHome ?? this.scoreHome,
        scoreAway: scoreAway ?? this.scoreAway,
        homeName: homeName.present ? homeName.value : this.homeName,
        awayName: awayName.present ? awayName.value : this.awayName,
        syncState: syncState ?? this.syncState,
        documentJson: documentJson ?? this.documentJson,
      );
  StoredMatch copyWithCompanion(MatchesCompanion data) {
    return StoredMatch(
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      status: data.status.present ? data.status.value : this.status,
      date: data.date.present ? data.date.value : this.date,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      scoreHome: data.scoreHome.present ? data.scoreHome.value : this.scoreHome,
      scoreAway: data.scoreAway.present ? data.scoreAway.value : this.scoreAway,
      homeName: data.homeName.present ? data.homeName.value : this.homeName,
      awayName: data.awayName.present ? data.awayName.value : this.awayName,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      documentJson: data.documentJson.present
          ? data.documentJson.value
          : this.documentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredMatch(')
          ..write('matchId: $matchId, ')
          ..write('status: $status, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scoreHome: $scoreHome, ')
          ..write('scoreAway: $scoreAway, ')
          ..write('homeName: $homeName, ')
          ..write('awayName: $awayName, ')
          ..write('syncState: $syncState, ')
          ..write('documentJson: $documentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(matchId, status, date, createdAt, updatedAt,
      scoreHome, scoreAway, homeName, awayName, syncState, documentJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredMatch &&
          other.matchId == this.matchId &&
          other.status == this.status &&
          other.date == this.date &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.scoreHome == this.scoreHome &&
          other.scoreAway == this.scoreAway &&
          other.homeName == this.homeName &&
          other.awayName == this.awayName &&
          other.syncState == this.syncState &&
          other.documentJson == this.documentJson);
}

class MatchesCompanion extends UpdateCompanion<StoredMatch> {
  final Value<String> matchId;
  final Value<String> status;
  final Value<String> date;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> scoreHome;
  final Value<int> scoreAway;
  final Value<String?> homeName;
  final Value<String?> awayName;
  final Value<String> syncState;
  final Value<String> documentJson;
  final Value<int> rowid;
  const MatchesCompanion({
    this.matchId = const Value.absent(),
    this.status = const Value.absent(),
    this.date = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.scoreHome = const Value.absent(),
    this.scoreAway = const Value.absent(),
    this.homeName = const Value.absent(),
    this.awayName = const Value.absent(),
    this.syncState = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchesCompanion.insert({
    required String matchId,
    required String status,
    required String date,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int scoreHome,
    required int scoreAway,
    this.homeName = const Value.absent(),
    this.awayName = const Value.absent(),
    required String syncState,
    required String documentJson,
    this.rowid = const Value.absent(),
  })  : matchId = Value(matchId),
        status = Value(status),
        date = Value(date),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        scoreHome = Value(scoreHome),
        scoreAway = Value(scoreAway),
        syncState = Value(syncState),
        documentJson = Value(documentJson);
  static Insertable<StoredMatch> custom({
    Expression<String>? matchId,
    Expression<String>? status,
    Expression<String>? date,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? scoreHome,
    Expression<int>? scoreAway,
    Expression<String>? homeName,
    Expression<String>? awayName,
    Expression<String>? syncState,
    Expression<String>? documentJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (matchId != null) 'match_id': matchId,
      if (status != null) 'status': status,
      if (date != null) 'date': date,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (scoreHome != null) 'score_home': scoreHome,
      if (scoreAway != null) 'score_away': scoreAway,
      if (homeName != null) 'home_name': homeName,
      if (awayName != null) 'away_name': awayName,
      if (syncState != null) 'sync_state': syncState,
      if (documentJson != null) 'document_json': documentJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchesCompanion copyWith(
      {Value<String>? matchId,
      Value<String>? status,
      Value<String>? date,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? scoreHome,
      Value<int>? scoreAway,
      Value<String?>? homeName,
      Value<String?>? awayName,
      Value<String>? syncState,
      Value<String>? documentJson,
      Value<int>? rowid}) {
    return MatchesCompanion(
      matchId: matchId ?? this.matchId,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scoreHome: scoreHome ?? this.scoreHome,
      scoreAway: scoreAway ?? this.scoreAway,
      homeName: homeName ?? this.homeName,
      awayName: awayName ?? this.awayName,
      syncState: syncState ?? this.syncState,
      documentJson: documentJson ?? this.documentJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (scoreHome.present) {
      map['score_home'] = Variable<int>(scoreHome.value);
    }
    if (scoreAway.present) {
      map['score_away'] = Variable<int>(scoreAway.value);
    }
    if (homeName.present) {
      map['home_name'] = Variable<String>(homeName.value);
    }
    if (awayName.present) {
      map['away_name'] = Variable<String>(awayName.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (documentJson.present) {
      map['document_json'] = Variable<String>(documentJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesCompanion(')
          ..write('matchId: $matchId, ')
          ..write('status: $status, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('scoreHome: $scoreHome, ')
          ..write('scoreAway: $scoreAway, ')
          ..write('homeName: $homeName, ')
          ..write('awayName: $awayName, ')
          ..write('syncState: $syncState, ')
          ..write('documentJson: $documentJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchEventsTable extends MatchEvents
    with TableInfo<$MatchEventsTable, StoredEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchIdMeta =
      const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
      'match_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES matches (match_id) ON DELETE CASCADE'));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _eventJsonMeta =
      const VerificationMeta('eventJson');
  @override
  late final GeneratedColumn<String> eventJson = GeneratedColumn<String>(
      'event_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [eventId, matchId, sortOrder, eventJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_events';
  @override
  VerificationContext validateIntegrity(Insertable<StoredEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta,
          matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('event_json')) {
      context.handle(_eventJsonMeta,
          eventJson.isAcceptableOrUnknown(data['event_json']!, _eventJsonMeta));
    } else if (isInserting) {
      context.missing(_eventJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  StoredEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEvent(
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id'])!,
      matchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_id'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      eventJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_json'])!,
    );
  }

  @override
  $MatchEventsTable createAlias(String alias) {
    return $MatchEventsTable(attachedDatabase, alias);
  }
}

class StoredEvent extends DataClass implements Insertable<StoredEvent> {
  final String eventId;
  final String matchId;
  final int sortOrder;
  final String eventJson;
  const StoredEvent(
      {required this.eventId,
      required this.matchId,
      required this.sortOrder,
      required this.eventJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['match_id'] = Variable<String>(matchId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['event_json'] = Variable<String>(eventJson);
    return map;
  }

  MatchEventsCompanion toCompanion(bool nullToAbsent) {
    return MatchEventsCompanion(
      eventId: Value(eventId),
      matchId: Value(matchId),
      sortOrder: Value(sortOrder),
      eventJson: Value(eventJson),
    );
  }

  factory StoredEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEvent(
      eventId: serializer.fromJson<String>(json['eventId']),
      matchId: serializer.fromJson<String>(json['matchId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      eventJson: serializer.fromJson<String>(json['eventJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'matchId': serializer.toJson<String>(matchId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'eventJson': serializer.toJson<String>(eventJson),
    };
  }

  StoredEvent copyWith(
          {String? eventId,
          String? matchId,
          int? sortOrder,
          String? eventJson}) =>
      StoredEvent(
        eventId: eventId ?? this.eventId,
        matchId: matchId ?? this.matchId,
        sortOrder: sortOrder ?? this.sortOrder,
        eventJson: eventJson ?? this.eventJson,
      );
  StoredEvent copyWithCompanion(MatchEventsCompanion data) {
    return StoredEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      eventJson: data.eventJson.present ? data.eventJson.value : this.eventJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEvent(')
          ..write('eventId: $eventId, ')
          ..write('matchId: $matchId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('eventJson: $eventJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, matchId, sortOrder, eventJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEvent &&
          other.eventId == this.eventId &&
          other.matchId == this.matchId &&
          other.sortOrder == this.sortOrder &&
          other.eventJson == this.eventJson);
}

class MatchEventsCompanion extends UpdateCompanion<StoredEvent> {
  final Value<String> eventId;
  final Value<String> matchId;
  final Value<int> sortOrder;
  final Value<String> eventJson;
  final Value<int> rowid;
  const MatchEventsCompanion({
    this.eventId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.eventJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchEventsCompanion.insert({
    required String eventId,
    required String matchId,
    required int sortOrder,
    required String eventJson,
    this.rowid = const Value.absent(),
  })  : eventId = Value(eventId),
        matchId = Value(matchId),
        sortOrder = Value(sortOrder),
        eventJson = Value(eventJson);
  static Insertable<StoredEvent> custom({
    Expression<String>? eventId,
    Expression<String>? matchId,
    Expression<int>? sortOrder,
    Expression<String>? eventJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (matchId != null) 'match_id': matchId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (eventJson != null) 'event_json': eventJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchEventsCompanion copyWith(
      {Value<String>? eventId,
      Value<String>? matchId,
      Value<int>? sortOrder,
      Value<String>? eventJson,
      Value<int>? rowid}) {
    return MatchEventsCompanion(
      eventId: eventId ?? this.eventId,
      matchId: matchId ?? this.matchId,
      sortOrder: sortOrder ?? this.sortOrder,
      eventJson: eventJson ?? this.eventJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (eventJson.present) {
      map['event_json'] = Variable<String>(eventJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('matchId: $matchId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('eventJson: $eventJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchHistoryTable extends MatchHistory
    with TableInfo<$MatchHistoryTable, StoredHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _historyIdMeta =
      const VerificationMeta('historyId');
  @override
  late final GeneratedColumn<String> historyId = GeneratedColumn<String>(
      'history_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchIdMeta =
      const VerificationMeta('matchId');
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
      'match_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES matches (match_id) ON DELETE CASCADE'));
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _historyJsonMeta =
      const VerificationMeta('historyJson');
  @override
  late final GeneratedColumn<String> historyJson = GeneratedColumn<String>(
      'history_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [historyId, matchId, eventId, sortOrder, historyJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_history';
  @override
  VerificationContext validateIntegrity(Insertable<StoredHistory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('history_id')) {
      context.handle(_historyIdMeta,
          historyId.isAcceptableOrUnknown(data['history_id']!, _historyIdMeta));
    } else if (isInserting) {
      context.missing(_historyIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(_matchIdMeta,
          matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta));
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('history_json')) {
      context.handle(
          _historyJsonMeta,
          historyJson.isAcceptableOrUnknown(
              data['history_json']!, _historyJsonMeta));
    } else if (isInserting) {
      context.missing(_historyJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {historyId};
  @override
  StoredHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredHistory(
      historyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}history_id'])!,
      matchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      historyJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}history_json'])!,
    );
  }

  @override
  $MatchHistoryTable createAlias(String alias) {
    return $MatchHistoryTable(attachedDatabase, alias);
  }
}

class StoredHistory extends DataClass implements Insertable<StoredHistory> {
  final String historyId;
  final String matchId;
  final String? eventId;
  final int sortOrder;
  final String historyJson;
  const StoredHistory(
      {required this.historyId,
      required this.matchId,
      this.eventId,
      required this.sortOrder,
      required this.historyJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['history_id'] = Variable<String>(historyId);
    map['match_id'] = Variable<String>(matchId);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['history_json'] = Variable<String>(historyJson);
    return map;
  }

  MatchHistoryCompanion toCompanion(bool nullToAbsent) {
    return MatchHistoryCompanion(
      historyId: Value(historyId),
      matchId: Value(matchId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      sortOrder: Value(sortOrder),
      historyJson: Value(historyJson),
    );
  }

  factory StoredHistory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredHistory(
      historyId: serializer.fromJson<String>(json['historyId']),
      matchId: serializer.fromJson<String>(json['matchId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      historyJson: serializer.fromJson<String>(json['historyJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'historyId': serializer.toJson<String>(historyId),
      'matchId': serializer.toJson<String>(matchId),
      'eventId': serializer.toJson<String?>(eventId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'historyJson': serializer.toJson<String>(historyJson),
    };
  }

  StoredHistory copyWith(
          {String? historyId,
          String? matchId,
          Value<String?> eventId = const Value.absent(),
          int? sortOrder,
          String? historyJson}) =>
      StoredHistory(
        historyId: historyId ?? this.historyId,
        matchId: matchId ?? this.matchId,
        eventId: eventId.present ? eventId.value : this.eventId,
        sortOrder: sortOrder ?? this.sortOrder,
        historyJson: historyJson ?? this.historyJson,
      );
  StoredHistory copyWithCompanion(MatchHistoryCompanion data) {
    return StoredHistory(
      historyId: data.historyId.present ? data.historyId.value : this.historyId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      historyJson:
          data.historyJson.present ? data.historyJson.value : this.historyJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredHistory(')
          ..write('historyId: $historyId, ')
          ..write('matchId: $matchId, ')
          ..write('eventId: $eventId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('historyJson: $historyJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(historyId, matchId, eventId, sortOrder, historyJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredHistory &&
          other.historyId == this.historyId &&
          other.matchId == this.matchId &&
          other.eventId == this.eventId &&
          other.sortOrder == this.sortOrder &&
          other.historyJson == this.historyJson);
}

class MatchHistoryCompanion extends UpdateCompanion<StoredHistory> {
  final Value<String> historyId;
  final Value<String> matchId;
  final Value<String?> eventId;
  final Value<int> sortOrder;
  final Value<String> historyJson;
  final Value<int> rowid;
  const MatchHistoryCompanion({
    this.historyId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.historyJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchHistoryCompanion.insert({
    required String historyId,
    required String matchId,
    this.eventId = const Value.absent(),
    required int sortOrder,
    required String historyJson,
    this.rowid = const Value.absent(),
  })  : historyId = Value(historyId),
        matchId = Value(matchId),
        sortOrder = Value(sortOrder),
        historyJson = Value(historyJson);
  static Insertable<StoredHistory> custom({
    Expression<String>? historyId,
    Expression<String>? matchId,
    Expression<String>? eventId,
    Expression<int>? sortOrder,
    Expression<String>? historyJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (historyId != null) 'history_id': historyId,
      if (matchId != null) 'match_id': matchId,
      if (eventId != null) 'event_id': eventId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (historyJson != null) 'history_json': historyJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchHistoryCompanion copyWith(
      {Value<String>? historyId,
      Value<String>? matchId,
      Value<String?>? eventId,
      Value<int>? sortOrder,
      Value<String>? historyJson,
      Value<int>? rowid}) {
    return MatchHistoryCompanion(
      historyId: historyId ?? this.historyId,
      matchId: matchId ?? this.matchId,
      eventId: eventId ?? this.eventId,
      sortOrder: sortOrder ?? this.sortOrder,
      historyJson: historyJson ?? this.historyJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (historyId.present) {
      map['history_id'] = Variable<String>(historyId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (historyJson.present) {
      map['history_json'] = Variable<String>(historyJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchHistoryCompanion(')
          ..write('historyId: $historyId, ')
          ..write('matchId: $matchId, ')
          ..write('eventId: $eventId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('historyJson: $historyJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalMatchDatabase extends GeneratedDatabase {
  _$LocalMatchDatabase(QueryExecutor e) : super(e);
  $LocalMatchDatabaseManager get managers => $LocalMatchDatabaseManager(this);
  late final $MatchesTable matches = $MatchesTable(this);
  late final $MatchEventsTable matchEvents = $MatchEventsTable(this);
  late final $MatchHistoryTable matchHistory = $MatchHistoryTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [matches, matchEvents, matchHistory];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('matches',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('match_events', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('matches',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('match_history', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$MatchesTableCreateCompanionBuilder = MatchesCompanion Function({
  required String matchId,
  required String status,
  required String date,
  required DateTime createdAt,
  required DateTime updatedAt,
  required int scoreHome,
  required int scoreAway,
  Value<String?> homeName,
  Value<String?> awayName,
  required String syncState,
  required String documentJson,
  Value<int> rowid,
});
typedef $$MatchesTableUpdateCompanionBuilder = MatchesCompanion Function({
  Value<String> matchId,
  Value<String> status,
  Value<String> date,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> scoreHome,
  Value<int> scoreAway,
  Value<String?> homeName,
  Value<String?> awayName,
  Value<String> syncState,
  Value<String> documentJson,
  Value<int> rowid,
});

final class $$MatchesTableReferences
    extends BaseReferences<_$LocalMatchDatabase, $MatchesTable, StoredMatch> {
  $$MatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MatchEventsTable, List<StoredEvent>>
      _matchEventsRefsTable(_$LocalMatchDatabase db) =>
          MultiTypedResultKey.fromTable(db.matchEvents,
              aliasName: 'matches__match_id__match_events__match_id');

  $$MatchEventsTableProcessedTableManager get matchEventsRefs {
    final manager = $$MatchEventsTableTableManager($_db, $_db.matchEvents)
        .filter((f) =>
            f.matchId.matchId.sqlEquals($_itemColumn<String>('match_id')!));

    final cache = $_typedResult.readTableOrNull(_matchEventsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MatchHistoryTable, List<StoredHistory>>
      _matchHistoryRefsTable(_$LocalMatchDatabase db) =>
          MultiTypedResultKey.fromTable(db.matchHistory,
              aliasName: 'matches__match_id__match_history__match_id');

  $$MatchHistoryTableProcessedTableManager get matchHistoryRefs {
    final manager = $$MatchHistoryTableTableManager($_db, $_db.matchHistory)
        .filter((f) =>
            f.matchId.matchId.sqlEquals($_itemColumn<String>('match_id')!));

    final cache = $_typedResult.readTableOrNull(_matchHistoryRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MatchesTableFilterComposer
    extends Composer<_$LocalMatchDatabase, $MatchesTable> {
  $$MatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scoreHome => $composableBuilder(
      column: $table.scoreHome, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scoreAway => $composableBuilder(
      column: $table.scoreAway, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get homeName => $composableBuilder(
      column: $table.homeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get awayName => $composableBuilder(
      column: $table.awayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get documentJson => $composableBuilder(
      column: $table.documentJson, builder: (column) => ColumnFilters(column));

  Expression<bool> matchEventsRefs(
      Expression<bool> Function($$MatchEventsTableFilterComposer f) f) {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matchEvents,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchEventsTableFilterComposer(
              $db: $db,
              $table: $db.matchEvents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> matchHistoryRefs(
      Expression<bool> Function($$MatchHistoryTableFilterComposer f) f) {
    final $$MatchHistoryTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matchHistory,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchHistoryTableFilterComposer(
              $db: $db,
              $table: $db.matchHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MatchesTableOrderingComposer
    extends Composer<_$LocalMatchDatabase, $MatchesTable> {
  $$MatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get matchId => $composableBuilder(
      column: $table.matchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scoreHome => $composableBuilder(
      column: $table.scoreHome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scoreAway => $composableBuilder(
      column: $table.scoreAway, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get homeName => $composableBuilder(
      column: $table.homeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get awayName => $composableBuilder(
      column: $table.awayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get documentJson => $composableBuilder(
      column: $table.documentJson,
      builder: (column) => ColumnOrderings(column));
}

class $$MatchesTableAnnotationComposer
    extends Composer<_$LocalMatchDatabase, $MatchesTable> {
  $$MatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get scoreHome =>
      $composableBuilder(column: $table.scoreHome, builder: (column) => column);

  GeneratedColumn<int> get scoreAway =>
      $composableBuilder(column: $table.scoreAway, builder: (column) => column);

  GeneratedColumn<String> get homeName =>
      $composableBuilder(column: $table.homeName, builder: (column) => column);

  GeneratedColumn<String> get awayName =>
      $composableBuilder(column: $table.awayName, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get documentJson => $composableBuilder(
      column: $table.documentJson, builder: (column) => column);

  Expression<T> matchEventsRefs<T extends Object>(
      Expression<T> Function($$MatchEventsTableAnnotationComposer a) f) {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matchEvents,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchEventsTableAnnotationComposer(
              $db: $db,
              $table: $db.matchEvents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> matchHistoryRefs<T extends Object>(
      Expression<T> Function($$MatchHistoryTableAnnotationComposer a) f) {
    final $$MatchHistoryTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matchHistory,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchHistoryTableAnnotationComposer(
              $db: $db,
              $table: $db.matchHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MatchesTableTableManager extends RootTableManager<
    _$LocalMatchDatabase,
    $MatchesTable,
    StoredMatch,
    $$MatchesTableFilterComposer,
    $$MatchesTableOrderingComposer,
    $$MatchesTableAnnotationComposer,
    $$MatchesTableCreateCompanionBuilder,
    $$MatchesTableUpdateCompanionBuilder,
    (StoredMatch, $$MatchesTableReferences),
    StoredMatch,
    PrefetchHooks Function({bool matchEventsRefs, bool matchHistoryRefs})> {
  $$MatchesTableTableManager(_$LocalMatchDatabase db, $MatchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> matchId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> scoreHome = const Value.absent(),
            Value<int> scoreAway = const Value.absent(),
            Value<String?> homeName = const Value.absent(),
            Value<String?> awayName = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<String> documentJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MatchesCompanion(
            matchId: matchId,
            status: status,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            scoreHome: scoreHome,
            scoreAway: scoreAway,
            homeName: homeName,
            awayName: awayName,
            syncState: syncState,
            documentJson: documentJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String matchId,
            required String status,
            required String date,
            required DateTime createdAt,
            required DateTime updatedAt,
            required int scoreHome,
            required int scoreAway,
            Value<String?> homeName = const Value.absent(),
            Value<String?> awayName = const Value.absent(),
            required String syncState,
            required String documentJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              MatchesCompanion.insert(
            matchId: matchId,
            status: status,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            scoreHome: scoreHome,
            scoreAway: scoreAway,
            homeName: homeName,
            awayName: awayName,
            syncState: syncState,
            documentJson: documentJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MatchesTable, StoredMatch>(table),
                    $$MatchesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {matchEventsRefs = false, matchHistoryRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (matchEventsRefs) db.matchEvents,
                if (matchHistoryRefs) db.matchHistory
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (matchEventsRefs)
                    await $_getPrefetchedData<StoredMatch, $MatchesTable,
                            StoredEvent>(
                        currentTable: table,
                        referencedTable:
                            $$MatchesTableReferences._matchEventsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MatchesTableReferences(db, table, p0)
                                .matchEventsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.matchId == item.matchId),
                        typedResults: items),
                  if (matchHistoryRefs)
                    await $_getPrefetchedData<StoredMatch, $MatchesTable,
                            StoredHistory>(
                        currentTable: table,
                        referencedTable:
                            $$MatchesTableReferences._matchHistoryRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MatchesTableReferences(db, table, p0)
                                .matchHistoryRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.matchId == item.matchId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MatchesTableProcessedTableManager = ProcessedTableManager<
    _$LocalMatchDatabase,
    $MatchesTable,
    StoredMatch,
    $$MatchesTableFilterComposer,
    $$MatchesTableOrderingComposer,
    $$MatchesTableAnnotationComposer,
    $$MatchesTableCreateCompanionBuilder,
    $$MatchesTableUpdateCompanionBuilder,
    (StoredMatch, $$MatchesTableReferences),
    StoredMatch,
    PrefetchHooks Function({bool matchEventsRefs, bool matchHistoryRefs})>;
typedef $$MatchEventsTableCreateCompanionBuilder = MatchEventsCompanion
    Function({
  required String eventId,
  required String matchId,
  required int sortOrder,
  required String eventJson,
  Value<int> rowid,
});
typedef $$MatchEventsTableUpdateCompanionBuilder = MatchEventsCompanion
    Function({
  Value<String> eventId,
  Value<String> matchId,
  Value<int> sortOrder,
  Value<String> eventJson,
  Value<int> rowid,
});

final class $$MatchEventsTableReferences extends BaseReferences<
    _$LocalMatchDatabase, $MatchEventsTable, StoredEvent> {
  $$MatchEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchesTable _matchIdTable(_$LocalMatchDatabase db) =>
      db.matches.createAlias('match_events__match_id__matches__match_id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager($_db, $_db.matches)
        .filter((f) => f.matchId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MatchEventsTableFilterComposer
    extends Composer<_$LocalMatchDatabase, $MatchEventsTable> {
  $$MatchEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventJson => $composableBuilder(
      column: $table.eventJson, builder: (column) => ColumnFilters(column));

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matches,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchesTableFilterComposer(
              $db: $db,
              $table: $db.matches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MatchEventsTableOrderingComposer
    extends Composer<_$LocalMatchDatabase, $MatchEventsTable> {
  $$MatchEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventJson => $composableBuilder(
      column: $table.eventJson, builder: (column) => ColumnOrderings(column));

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matches,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchesTableOrderingComposer(
              $db: $db,
              $table: $db.matches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MatchEventsTableAnnotationComposer
    extends Composer<_$LocalMatchDatabase, $MatchEventsTable> {
  $$MatchEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get eventJson =>
      $composableBuilder(column: $table.eventJson, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matches,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchesTableAnnotationComposer(
              $db: $db,
              $table: $db.matches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MatchEventsTableTableManager extends RootTableManager<
    _$LocalMatchDatabase,
    $MatchEventsTable,
    StoredEvent,
    $$MatchEventsTableFilterComposer,
    $$MatchEventsTableOrderingComposer,
    $$MatchEventsTableAnnotationComposer,
    $$MatchEventsTableCreateCompanionBuilder,
    $$MatchEventsTableUpdateCompanionBuilder,
    (StoredEvent, $$MatchEventsTableReferences),
    StoredEvent,
    PrefetchHooks Function({bool matchId})> {
  $$MatchEventsTableTableManager(
      _$LocalMatchDatabase db, $MatchEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> eventId = const Value.absent(),
            Value<String> matchId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String> eventJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MatchEventsCompanion(
            eventId: eventId,
            matchId: matchId,
            sortOrder: sortOrder,
            eventJson: eventJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String eventId,
            required String matchId,
            required int sortOrder,
            required String eventJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              MatchEventsCompanion.insert(
            eventId: eventId,
            matchId: matchId,
            sortOrder: sortOrder,
            eventJson: eventJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MatchEventsTable, StoredEvent>(table),
                    $$MatchEventsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({matchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (matchId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.matchId,
                    referencedTable:
                        $$MatchEventsTableReferences._matchIdTable(db),
                    referencedColumn:
                        $$MatchEventsTableReferences._matchIdTable(db).matchId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MatchEventsTableProcessedTableManager = ProcessedTableManager<
    _$LocalMatchDatabase,
    $MatchEventsTable,
    StoredEvent,
    $$MatchEventsTableFilterComposer,
    $$MatchEventsTableOrderingComposer,
    $$MatchEventsTableAnnotationComposer,
    $$MatchEventsTableCreateCompanionBuilder,
    $$MatchEventsTableUpdateCompanionBuilder,
    (StoredEvent, $$MatchEventsTableReferences),
    StoredEvent,
    PrefetchHooks Function({bool matchId})>;
typedef $$MatchHistoryTableCreateCompanionBuilder = MatchHistoryCompanion
    Function({
  required String historyId,
  required String matchId,
  Value<String?> eventId,
  required int sortOrder,
  required String historyJson,
  Value<int> rowid,
});
typedef $$MatchHistoryTableUpdateCompanionBuilder = MatchHistoryCompanion
    Function({
  Value<String> historyId,
  Value<String> matchId,
  Value<String?> eventId,
  Value<int> sortOrder,
  Value<String> historyJson,
  Value<int> rowid,
});

final class $$MatchHistoryTableReferences extends BaseReferences<
    _$LocalMatchDatabase, $MatchHistoryTable, StoredHistory> {
  $$MatchHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchesTable _matchIdTable(_$LocalMatchDatabase db) =>
      db.matches.createAlias('match_history__match_id__matches__match_id');

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager($_db, $_db.matches)
        .filter((f) => f.matchId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MatchHistoryTableFilterComposer
    extends Composer<_$LocalMatchDatabase, $MatchHistoryTable> {
  $$MatchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get historyId => $composableBuilder(
      column: $table.historyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get historyJson => $composableBuilder(
      column: $table.historyJson, builder: (column) => ColumnFilters(column));

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matches,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchesTableFilterComposer(
              $db: $db,
              $table: $db.matches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MatchHistoryTableOrderingComposer
    extends Composer<_$LocalMatchDatabase, $MatchHistoryTable> {
  $$MatchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get historyId => $composableBuilder(
      column: $table.historyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get historyJson => $composableBuilder(
      column: $table.historyJson, builder: (column) => ColumnOrderings(column));

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matches,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchesTableOrderingComposer(
              $db: $db,
              $table: $db.matches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MatchHistoryTableAnnotationComposer
    extends Composer<_$LocalMatchDatabase, $MatchHistoryTable> {
  $$MatchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get historyId =>
      $composableBuilder(column: $table.historyId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get historyJson => $composableBuilder(
      column: $table.historyJson, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.matchId,
        referencedTable: $db.matches,
        getReferencedColumn: (t) => t.matchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MatchesTableAnnotationComposer(
              $db: $db,
              $table: $db.matches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MatchHistoryTableTableManager extends RootTableManager<
    _$LocalMatchDatabase,
    $MatchHistoryTable,
    StoredHistory,
    $$MatchHistoryTableFilterComposer,
    $$MatchHistoryTableOrderingComposer,
    $$MatchHistoryTableAnnotationComposer,
    $$MatchHistoryTableCreateCompanionBuilder,
    $$MatchHistoryTableUpdateCompanionBuilder,
    (StoredHistory, $$MatchHistoryTableReferences),
    StoredHistory,
    PrefetchHooks Function({bool matchId})> {
  $$MatchHistoryTableTableManager(
      _$LocalMatchDatabase db, $MatchHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> historyId = const Value.absent(),
            Value<String> matchId = const Value.absent(),
            Value<String?> eventId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String> historyJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MatchHistoryCompanion(
            historyId: historyId,
            matchId: matchId,
            eventId: eventId,
            sortOrder: sortOrder,
            historyJson: historyJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String historyId,
            required String matchId,
            Value<String?> eventId = const Value.absent(),
            required int sortOrder,
            required String historyJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              MatchHistoryCompanion.insert(
            historyId: historyId,
            matchId: matchId,
            eventId: eventId,
            sortOrder: sortOrder,
            historyJson: historyJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MatchHistoryTable, StoredHistory>(table),
                    $$MatchHistoryTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({matchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (matchId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.matchId,
                    referencedTable:
                        $$MatchHistoryTableReferences._matchIdTable(db),
                    referencedColumn:
                        $$MatchHistoryTableReferences._matchIdTable(db).matchId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MatchHistoryTableProcessedTableManager = ProcessedTableManager<
    _$LocalMatchDatabase,
    $MatchHistoryTable,
    StoredHistory,
    $$MatchHistoryTableFilterComposer,
    $$MatchHistoryTableOrderingComposer,
    $$MatchHistoryTableAnnotationComposer,
    $$MatchHistoryTableCreateCompanionBuilder,
    $$MatchHistoryTableUpdateCompanionBuilder,
    (StoredHistory, $$MatchHistoryTableReferences),
    StoredHistory,
    PrefetchHooks Function({bool matchId})>;

class $LocalMatchDatabaseManager {
  final _$LocalMatchDatabase _db;
  $LocalMatchDatabaseManager(this._db);
  $$MatchesTableTableManager get matches =>
      $$MatchesTableTableManager(_db, _db.matches);
  $$MatchEventsTableTableManager get matchEvents =>
      $$MatchEventsTableTableManager(_db, _db.matchEvents);
  $$MatchHistoryTableTableManager get matchHistory =>
      $$MatchHistoryTableTableManager(_db, _db.matchHistory);
}
