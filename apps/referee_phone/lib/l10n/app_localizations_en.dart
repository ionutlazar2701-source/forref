// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ref App';

  @override
  String get matchesTitle => 'Matches';

  @override
  String get newMatch => 'New Match';

  @override
  String get emptyMatches => 'No matches yet';

  @override
  String get settings => 'Settings';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get older => 'Older';

  @override
  String get statusSetup => 'Setup';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusLive => 'Live';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusHalfTime => 'Half-time';

  @override
  String get statusExtraTime => 'Extra time';

  @override
  String get statusFullTime => 'Full time';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get homeFallback => 'HOME';

  @override
  String get awayFallback => 'AWAY';

  @override
  String get setupTitle => 'Match setup';

  @override
  String get homeTeam => 'Home team';

  @override
  String get awayTeam => 'Away team';

  @override
  String get date => 'Date';

  @override
  String get competition => 'Competition';

  @override
  String get venue => 'Venue';

  @override
  String get halfLength => 'Half length (minutes)';

  @override
  String get competitionFormatTitle => 'Competition format';

  @override
  String get competitionFormatNoExtraTime =>
      'Standard — no additional playing periods';

  @override
  String get competitionFormatExtraTimeMayApply =>
      'Extra time or cup format may apply';

  @override
  String get penaltyShootOutAfterMatchEnd =>
      'Penalty shoot-out after match end (if required)';

  @override
  String get crewReferee => 'Referee';

  @override
  String get crewAr1 => 'Assistant 1';

  @override
  String get crewAr2 => 'Assistant 2';

  @override
  String get crewFourth => 'Fourth official';

  @override
  String get squadHome => 'Home squad';

  @override
  String get squadAway => 'Away squad';

  @override
  String get addPlayer => 'Add player';

  @override
  String get playerNumber => 'Number';

  @override
  String get playerName => 'Name';

  @override
  String get liveMatch => 'Live Match';

  @override
  String get enterField => 'Enter field';

  @override
  String get enterFieldSaved => 'Entered field';

  @override
  String get enterFieldNotSaved => 'Field entry was not saved';

  @override
  String get fieldEntryLifecycleIncomplete =>
      'Field entry was not recorded before the match started';

  @override
  String get kickOff => 'Kick-off';

  @override
  String get matchStarted => 'Match started';

  @override
  String get kickOffNotSaved => 'Kick-off was not saved';

  @override
  String get periodStartIncomplete => 'Period start incomplete';

  @override
  String get completePeriodStart => 'Complete period start';

  @override
  String get periodStartNotSaved => 'Period start was not saved';

  @override
  String get continuityExact => 'Continuity exact';

  @override
  String get continuityBounded => 'Continuity bounded';

  @override
  String get elapsedUnavailable => 'Elapsed unavailable';

  @override
  String get suspendMatch => 'Suspend match';

  @override
  String get matchSuspended => 'Match suspended';

  @override
  String get suspensionOngoing => 'Suspension ongoing';

  @override
  String get suspensionNotSaved => 'Suspension was not saved';

  @override
  String get resumeMatch => 'Resume match';

  @override
  String get resumeNotSaved => 'Resume was not saved';

  @override
  String get endPeriod => 'End period';

  @override
  String get endMatch => 'End match';

  @override
  String get matchEndedTerminal => 'Match ended';

  @override
  String get matchEndNotSaved => 'Match end was not saved';

  @override
  String get terminalBlockedAdditionalPlayingPhase =>
      'An additional playing period is required before the match can end';

  @override
  String get terminalBlockedPhaseDispositionUnresolved =>
      'Competition format is unresolved — normal match end is not available';

  @override
  String get terminalBlockedActivePeriod => 'A playing period is still active';

  @override
  String get terminalBlockedOpenSuspension => 'Formal suspension is still open';

  @override
  String get terminalBlockedAbandoned => 'The match was abandoned';

  @override
  String get terminalBlockedAlreadyEnded => 'The match has already ended';

  @override
  String get terminalBlockedAmbiguousLineage => 'Period lineage is ambiguous';

  @override
  String get terminalBlockedNoCompletedPlayingPhase =>
      'No playing period has been completed';

  @override
  String periodEnded(int index) {
    return 'Period $index ended';
  }

  @override
  String get periodEndNotSaved => 'Period end was not saved';

  @override
  String get interval => 'Interval';

  @override
  String periodEndedInterval(int index) {
    return 'Period $index — ended';
  }

  @override
  String get noActivePlayingPeriod => 'No active playing period';

  @override
  String get startPeriod2 => 'Start Period 2';

  @override
  String activePeriodIndex(int index) {
    return 'Period $index';
  }

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get halfTime => 'Half-time';

  @override
  String get startSecondHalf => 'Start 2nd half';

  @override
  String get extraTime => 'Extra time';

  @override
  String get fullTime => 'Full time';

  @override
  String get summary => 'Summary';

  @override
  String get undo => 'Undo';

  @override
  String get goal => 'Goal';

  @override
  String get goalSaved => 'Goal saved';

  @override
  String get goalNotSaved => 'Goal was not saved';

  @override
  String get yellow => 'Yellow';

  @override
  String get red => 'Red';

  @override
  String get sub => 'Sub';

  @override
  String get injury => 'Injury';

  @override
  String get unknown => 'Unknown';

  @override
  String get freeNumber => 'Shirt number';

  @override
  String get playerOut => 'Out';

  @override
  String get playerIn => 'In';

  @override
  String get back => 'Back';

  @override
  String get addedTime => 'Added time';

  @override
  String get finishMatch => 'Finish match';

  @override
  String get finishAnyway => 'Finish anyway';

  @override
  String get reviewEvents => 'Review events';

  @override
  String get addEvent => 'Add event';

  @override
  String get backToMatch => 'Back to match';

  @override
  String get incomplete => 'Incomplete';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get romanian => 'Romanian';

  @override
  String get period1h => '1H';

  @override
  String get period2h => '2H';

  @override
  String get periodEt1 => 'ET1';

  @override
  String get periodEt2 => 'ET2';

  @override
  String get editEvent => 'Edit';

  @override
  String get nudgeMinus => '−30 s';

  @override
  String get nudgePlus => '+30 s';

  @override
  String get ownGoal => 'Own goal';

  @override
  String get finishIncompleteBody =>
      'There are incomplete events. Finish anyway?';

  @override
  String scoreLine(String home, int homeScore, int awayScore, String away) {
    return '$home $homeScore — $awayScore $away';
  }

  @override
  String clockWithAdded(String clock, int minutes) {
    return '$clock +$minutes';
  }

  @override
  String get recordYellow => 'Record Yellow';

  @override
  String get recordSecondCaution => 'Record second caution';

  @override
  String get saving => 'Saving…';

  @override
  String yellowSavedParticipant(String participant) {
    return 'Yellow saved · $participant';
  }

  @override
  String get priorCautionRecorded => 'PRIOR CAUTION RECORDED';

  @override
  String get identityProvisional => 'Identity provisional';

  @override
  String get cautionHistoryCannotBeConfirmed =>
      'Caution history cannot be confirmed';

  @override
  String get cannotIdentifyParticipantReliably =>
      'Cannot identify participant reliably';

  @override
  String get participantDetailsConflict => 'Participant details conflict';

  @override
  String get notSaved => 'Not saved';

  @override
  String get retry => 'Retry';

  @override
  String get checkingSaveStatus => 'Checking save status…';

  @override
  String get checkingCautionHistory => 'Checking caution history…';

  @override
  String get secondCautionRecorded => 'SECOND CAUTION RECORDED';

  @override
  String get noRedCardRecorded => 'No red card has been recorded';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get bench => 'Bench';

  @override
  String get officials => 'Officials';

  @override
  String get noOnFieldParticipants => 'No on-field participants';

  @override
  String get noBenchParticipants => 'No bench participants';

  @override
  String get noOfficials => 'No officials';

  @override
  String get onField => 'On field';

  @override
  String get substitute => 'Substitute';

  @override
  String get substitutedPlayer => 'Substituted player';

  @override
  String get teamOfficial => 'Team official';

  @override
  String get seniorCoachPresent => 'Senior coach present';

  @override
  String get yellowCardShootoutScope => 'Shoot-out';

  @override
  String get yellowCardSuperseded => 'Superseded';

  @override
  String get yellowCardStandingUnresolved => 'Standing unresolved';

  @override
  String yellowCardStandingOrdinal(int ordinal) {
    return 'Standing caution $ordinal';
  }

  @override
  String get yellowCardLegacyDataLimitation =>
      'Yellow cards on this match use pre-cutover data only; Match Memory cautions are not available.';

  @override
  String get yellowCardMixedLegacyWithheld =>
      'Older yellow card events are hidden; standing history comes from Match Memory.';
}
