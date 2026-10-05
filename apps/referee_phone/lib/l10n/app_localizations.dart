import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ro')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Ref App'**
  String get appTitle;

  /// No description provided for @matchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matchesTitle;

  /// No description provided for @newMatch.
  ///
  /// In en, this message translates to:
  /// **'New Match'**
  String get newMatch;

  /// No description provided for @emptyMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get emptyMatches;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @older.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get older;

  /// No description provided for @statusSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get statusSetup;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get statusLive;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusHalfTime.
  ///
  /// In en, this message translates to:
  /// **'Half-time'**
  String get statusHalfTime;

  /// No description provided for @statusExtraTime.
  ///
  /// In en, this message translates to:
  /// **'Extra time'**
  String get statusExtraTime;

  /// No description provided for @statusFullTime.
  ///
  /// In en, this message translates to:
  /// **'Full time'**
  String get statusFullTime;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @homeFallback.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get homeFallback;

  /// No description provided for @awayFallback.
  ///
  /// In en, this message translates to:
  /// **'AWAY'**
  String get awayFallback;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Match setup'**
  String get setupTitle;

  /// No description provided for @homeTeam.
  ///
  /// In en, this message translates to:
  /// **'Home team'**
  String get homeTeam;

  /// No description provided for @awayTeam.
  ///
  /// In en, this message translates to:
  /// **'Away team'**
  String get awayTeam;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @competition.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get competition;

  /// No description provided for @venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get venue;

  /// No description provided for @halfLength.
  ///
  /// In en, this message translates to:
  /// **'Half length (minutes)'**
  String get halfLength;

  /// No description provided for @competitionFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Competition format'**
  String get competitionFormatTitle;

  /// No description provided for @competitionFormatNoExtraTime.
  ///
  /// In en, this message translates to:
  /// **'Standard — no additional playing periods'**
  String get competitionFormatNoExtraTime;

  /// No description provided for @competitionFormatExtraTimeMayApply.
  ///
  /// In en, this message translates to:
  /// **'Extra time or cup format may apply'**
  String get competitionFormatExtraTimeMayApply;

  /// No description provided for @penaltyShootOutAfterMatchEnd.
  ///
  /// In en, this message translates to:
  /// **'Penalty shoot-out after match end (if required)'**
  String get penaltyShootOutAfterMatchEnd;

  /// No description provided for @crewReferee.
  ///
  /// In en, this message translates to:
  /// **'Referee'**
  String get crewReferee;

  /// No description provided for @crewAr1.
  ///
  /// In en, this message translates to:
  /// **'Assistant 1'**
  String get crewAr1;

  /// No description provided for @crewAr2.
  ///
  /// In en, this message translates to:
  /// **'Assistant 2'**
  String get crewAr2;

  /// No description provided for @crewFourth.
  ///
  /// In en, this message translates to:
  /// **'Fourth official'**
  String get crewFourth;

  /// No description provided for @squadHome.
  ///
  /// In en, this message translates to:
  /// **'Home squad'**
  String get squadHome;

  /// No description provided for @squadAway.
  ///
  /// In en, this message translates to:
  /// **'Away squad'**
  String get squadAway;

  /// No description provided for @addPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add player'**
  String get addPlayer;

  /// No description provided for @playerNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get playerNumber;

  /// No description provided for @playerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playerName;

  /// No description provided for @liveMatch.
  ///
  /// In en, this message translates to:
  /// **'Live Match'**
  String get liveMatch;

  /// No description provided for @kickOff.
  ///
  /// In en, this message translates to:
  /// **'Kick-off'**
  String get kickOff;

  /// No description provided for @matchStarted.
  ///
  /// In en, this message translates to:
  /// **'Match started'**
  String get matchStarted;

  /// No description provided for @kickOffNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Kick-off was not saved'**
  String get kickOffNotSaved;

  /// No description provided for @periodStartIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Period start incomplete'**
  String get periodStartIncomplete;

  /// No description provided for @completePeriodStart.
  ///
  /// In en, this message translates to:
  /// **'Complete period start'**
  String get completePeriodStart;

  /// No description provided for @periodStartNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Period start was not saved'**
  String get periodStartNotSaved;

  /// No description provided for @continuityExact.
  ///
  /// In en, this message translates to:
  /// **'Continuity exact'**
  String get continuityExact;

  /// No description provided for @continuityBounded.
  ///
  /// In en, this message translates to:
  /// **'Continuity bounded'**
  String get continuityBounded;

  /// No description provided for @elapsedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Elapsed unavailable'**
  String get elapsedUnavailable;

  /// No description provided for @suspendMatch.
  ///
  /// In en, this message translates to:
  /// **'Suspend match'**
  String get suspendMatch;

  /// No description provided for @matchSuspended.
  ///
  /// In en, this message translates to:
  /// **'Match suspended'**
  String get matchSuspended;

  /// No description provided for @suspensionOngoing.
  ///
  /// In en, this message translates to:
  /// **'Suspension ongoing'**
  String get suspensionOngoing;

  /// No description provided for @suspensionNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Suspension was not saved'**
  String get suspensionNotSaved;

  /// No description provided for @resumeMatch.
  ///
  /// In en, this message translates to:
  /// **'Resume match'**
  String get resumeMatch;

  /// No description provided for @resumeNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Resume was not saved'**
  String get resumeNotSaved;

  /// No description provided for @endPeriod.
  ///
  /// In en, this message translates to:
  /// **'End period'**
  String get endPeriod;

  /// No description provided for @endMatch.
  ///
  /// In en, this message translates to:
  /// **'End match'**
  String get endMatch;

  /// No description provided for @matchEndedTerminal.
  ///
  /// In en, this message translates to:
  /// **'Match ended'**
  String get matchEndedTerminal;

  /// No description provided for @matchEndNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Match end was not saved'**
  String get matchEndNotSaved;

  /// No description provided for @terminalBlockedAdditionalPlayingPhase.
  ///
  /// In en, this message translates to:
  /// **'An additional playing period is required before the match can end'**
  String get terminalBlockedAdditionalPlayingPhase;

  /// No description provided for @terminalBlockedPhaseDispositionUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Competition format is unresolved — normal match end is not available'**
  String get terminalBlockedPhaseDispositionUnresolved;

  /// No description provided for @terminalBlockedActivePeriod.
  ///
  /// In en, this message translates to:
  /// **'A playing period is still active'**
  String get terminalBlockedActivePeriod;

  /// No description provided for @terminalBlockedOpenSuspension.
  ///
  /// In en, this message translates to:
  /// **'Formal suspension is still open'**
  String get terminalBlockedOpenSuspension;

  /// No description provided for @terminalBlockedAbandoned.
  ///
  /// In en, this message translates to:
  /// **'The match was abandoned'**
  String get terminalBlockedAbandoned;

  /// No description provided for @terminalBlockedAlreadyEnded.
  ///
  /// In en, this message translates to:
  /// **'The match has already ended'**
  String get terminalBlockedAlreadyEnded;

  /// No description provided for @terminalBlockedAmbiguousLineage.
  ///
  /// In en, this message translates to:
  /// **'Period lineage is ambiguous'**
  String get terminalBlockedAmbiguousLineage;

  /// No description provided for @terminalBlockedNoCompletedPlayingPhase.
  ///
  /// In en, this message translates to:
  /// **'No playing period has been completed'**
  String get terminalBlockedNoCompletedPlayingPhase;

  /// No description provided for @periodEnded.
  ///
  /// In en, this message translates to:
  /// **'Period {index} ended'**
  String periodEnded(int index);

  /// No description provided for @periodEndNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Period end was not saved'**
  String get periodEndNotSaved;

  /// No description provided for @interval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get interval;

  /// No description provided for @periodEndedInterval.
  ///
  /// In en, this message translates to:
  /// **'Period {index} — ended'**
  String periodEndedInterval(int index);

  /// No description provided for @noActivePlayingPeriod.
  ///
  /// In en, this message translates to:
  /// **'No active playing period'**
  String get noActivePlayingPeriod;

  /// No description provided for @startPeriod2.
  ///
  /// In en, this message translates to:
  /// **'Start Period 2'**
  String get startPeriod2;

  /// No description provided for @activePeriodIndex.
  ///
  /// In en, this message translates to:
  /// **'Period {index}'**
  String activePeriodIndex(int index);

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @halfTime.
  ///
  /// In en, this message translates to:
  /// **'Half-time'**
  String get halfTime;

  /// No description provided for @startSecondHalf.
  ///
  /// In en, this message translates to:
  /// **'Start 2nd half'**
  String get startSecondHalf;

  /// No description provided for @extraTime.
  ///
  /// In en, this message translates to:
  /// **'Extra time'**
  String get extraTime;

  /// No description provided for @fullTime.
  ///
  /// In en, this message translates to:
  /// **'Full time'**
  String get fullTime;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @yellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get yellow;

  /// No description provided for @red.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get red;

  /// No description provided for @sub.
  ///
  /// In en, this message translates to:
  /// **'Sub'**
  String get sub;

  /// No description provided for @injury.
  ///
  /// In en, this message translates to:
  /// **'Injury'**
  String get injury;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @freeNumber.
  ///
  /// In en, this message translates to:
  /// **'Shirt number'**
  String get freeNumber;

  /// No description provided for @playerOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get playerOut;

  /// No description provided for @playerIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get playerIn;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @addedTime.
  ///
  /// In en, this message translates to:
  /// **'Added time'**
  String get addedTime;

  /// No description provided for @finishMatch.
  ///
  /// In en, this message translates to:
  /// **'Finish match'**
  String get finishMatch;

  /// No description provided for @finishAnyway.
  ///
  /// In en, this message translates to:
  /// **'Finish anyway'**
  String get finishAnyway;

  /// No description provided for @reviewEvents.
  ///
  /// In en, this message translates to:
  /// **'Review events'**
  String get reviewEvents;

  /// No description provided for @addEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get addEvent;

  /// No description provided for @backToMatch.
  ///
  /// In en, this message translates to:
  /// **'Back to match'**
  String get backToMatch;

  /// No description provided for @incomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get incomplete;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @romanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get romanian;

  /// No description provided for @period1h.
  ///
  /// In en, this message translates to:
  /// **'1H'**
  String get period1h;

  /// No description provided for @period2h.
  ///
  /// In en, this message translates to:
  /// **'2H'**
  String get period2h;

  /// No description provided for @periodEt1.
  ///
  /// In en, this message translates to:
  /// **'ET1'**
  String get periodEt1;

  /// No description provided for @periodEt2.
  ///
  /// In en, this message translates to:
  /// **'ET2'**
  String get periodEt2;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editEvent;

  /// No description provided for @nudgeMinus.
  ///
  /// In en, this message translates to:
  /// **'−30 s'**
  String get nudgeMinus;

  /// No description provided for @nudgePlus.
  ///
  /// In en, this message translates to:
  /// **'+30 s'**
  String get nudgePlus;

  /// No description provided for @ownGoal.
  ///
  /// In en, this message translates to:
  /// **'Own goal'**
  String get ownGoal;

  /// No description provided for @finishIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'There are incomplete events. Finish anyway?'**
  String get finishIncompleteBody;

  /// No description provided for @scoreLine.
  ///
  /// In en, this message translates to:
  /// **'{home} {homeScore} — {awayScore} {away}'**
  String scoreLine(String home, int homeScore, int awayScore, String away);

  /// No description provided for @clockWithAdded.
  ///
  /// In en, this message translates to:
  /// **'{clock} +{minutes}'**
  String clockWithAdded(String clock, int minutes);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
