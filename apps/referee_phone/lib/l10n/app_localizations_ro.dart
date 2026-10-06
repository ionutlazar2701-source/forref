// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Ref App';

  @override
  String get matchesTitle => 'Meciuri';

  @override
  String get newMatch => 'Meci nou';

  @override
  String get emptyMatches => 'Niciun meci';

  @override
  String get settings => 'Setări';

  @override
  String get today => 'Azi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get older => 'Mai vechi';

  @override
  String get statusSetup => 'Pregătire';

  @override
  String get statusReady => 'Gata';

  @override
  String get statusLive => 'Live';

  @override
  String get statusPaused => 'Pauză';

  @override
  String get statusHalfTime => 'Pauză de jumătate';

  @override
  String get statusExtraTime => 'Prelungiri';

  @override
  String get statusFullTime => 'Final';

  @override
  String get statusCompleted => 'Încheiat';

  @override
  String get homeFallback => 'ACASĂ';

  @override
  String get awayFallback => 'DEPLASARE';

  @override
  String get setupTitle => 'Pregătire meci';

  @override
  String get homeTeam => 'Echipa gazdă';

  @override
  String get awayTeam => 'Echipa oaspete';

  @override
  String get date => 'Dată';

  @override
  String get competition => 'Competiție';

  @override
  String get venue => 'Stadion';

  @override
  String get halfLength => 'Durata reprizei (minute)';

  @override
  String get competitionFormatTitle => 'Format competiție';

  @override
  String get competitionFormatNoExtraTime =>
      'Standard — fără perioade suplimentare de joc';

  @override
  String get competitionFormatExtraTimeMayApply =>
      'Prelungiri sau format cupe — posibil';

  @override
  String get penaltyShootOutAfterMatchEnd =>
      'Lovituri de departajare după final (dacă e cazul)';

  @override
  String get crewReferee => 'Arbitru';

  @override
  String get crewAr1 => 'Asistent 1';

  @override
  String get crewAr2 => 'Asistent 2';

  @override
  String get crewFourth => 'Al 4-lea oficial';

  @override
  String get squadHome => 'Lot gazde';

  @override
  String get squadAway => 'Lot oaspeți';

  @override
  String get addPlayer => 'Adaugă jucător';

  @override
  String get playerNumber => 'Număr';

  @override
  String get playerName => 'Nume';

  @override
  String get liveMatch => 'Meci live';

  @override
  String get kickOff => 'Start';

  @override
  String get matchStarted => 'Meci început';

  @override
  String get kickOffNotSaved => 'Startul nu a fost salvat';

  @override
  String get periodStartIncomplete => 'Startul reprizei este incomplet';

  @override
  String get completePeriodStart => 'Finalizează startul reprizei';

  @override
  String get periodStartNotSaved => 'Startul reprizei nu a fost salvat';

  @override
  String get continuityExact => 'Continuitate exactă';

  @override
  String get continuityBounded => 'Continuitate mărginită';

  @override
  String get elapsedUnavailable => 'Timpul nu este disponibil';

  @override
  String get suspendMatch => 'Suspendă meciul';

  @override
  String get matchSuspended => 'Meci suspendat';

  @override
  String get suspensionOngoing => 'Suspendare în curs';

  @override
  String get suspensionNotSaved => 'Suspendarea nu a fost salvată';

  @override
  String get resumeMatch => 'Reia meciul';

  @override
  String get resumeNotSaved => 'Reluarea nu a fost salvată';

  @override
  String get endPeriod => 'Încheie repriza';

  @override
  String get endMatch => 'Încheie meciul';

  @override
  String get matchEndedTerminal => 'Meci încheiat';

  @override
  String get matchEndNotSaved => 'Încheierea meciului nu a fost salvată';

  @override
  String get terminalBlockedAdditionalPlayingPhase =>
      'Este necesară o perioadă suplimentară de joc înainte de încheiere';

  @override
  String get terminalBlockedPhaseDispositionUnresolved =>
      'Formatul competiției este nerezolvat — încheierea normală nu este disponibilă';

  @override
  String get terminalBlockedActivePeriod =>
      'O perioadă de joc este încă activă';

  @override
  String get terminalBlockedOpenSuspension =>
      'Suspendarea formală este încă deschisă';

  @override
  String get terminalBlockedAbandoned => 'Meciul a fost abandonat';

  @override
  String get terminalBlockedAlreadyEnded => 'Meciul s-a încheiat deja';

  @override
  String get terminalBlockedAmbiguousLineage =>
      'Linia temporală a reprizelor este ambiguă';

  @override
  String get terminalBlockedNoCompletedPlayingPhase =>
      'Nicio perioadă de joc nu a fost încheiată';

  @override
  String periodEnded(int index) {
    return 'Repriza $index — încheiată';
  }

  @override
  String get periodEndNotSaved => 'Încheierea reprizei nu a fost salvată';

  @override
  String get interval => 'Pauză';

  @override
  String periodEndedInterval(int index) {
    return 'Repriza $index — încheiată';
  }

  @override
  String get noActivePlayingPeriod => 'Nicio perioadă activă de joc';

  @override
  String get startPeriod2 => 'Începe repriza 2';

  @override
  String activePeriodIndex(int index) {
    return 'Repriza $index';
  }

  @override
  String get pause => 'Pauză';

  @override
  String get resume => 'Reluare';

  @override
  String get halfTime => 'Pauză de jumătate';

  @override
  String get startSecondHalf => 'Start repriza 2';

  @override
  String get extraTime => 'Prelungiri';

  @override
  String get fullTime => 'Final';

  @override
  String get summary => 'Sumar';

  @override
  String get undo => 'Anulează';

  @override
  String get goal => 'Gol';

  @override
  String get goalSaved => 'Gol salvat';

  @override
  String get goalNotSaved => 'Golul nu a fost salvat';

  @override
  String get legacyGoalsNotIncluded =>
      'Golurile salvate anterior în formatul vechi nu apar aici. Scorul reflectă doar Match Memory.';

  @override
  String get yellow => 'Galben';

  @override
  String get red => 'Roșu';

  @override
  String get sub => 'Schimbare';

  @override
  String get injury => 'Accidentare';

  @override
  String get unknown => 'Necunoscut';

  @override
  String get freeNumber => 'Număr tricou';

  @override
  String get playerOut => 'Iese';

  @override
  String get playerIn => 'Intră';

  @override
  String get back => 'Înapoi';

  @override
  String get addedTime => 'Timp adițional';

  @override
  String get finishMatch => 'Închide meciul';

  @override
  String get finishAnyway => 'Închide oricum';

  @override
  String get reviewEvents => 'Vezi evenimentele';

  @override
  String get addEvent => 'Adaugă eveniment';

  @override
  String get backToMatch => 'Înapoi la meci';

  @override
  String get incomplete => 'Incomplet';

  @override
  String get language => 'Limbă';

  @override
  String get english => 'Engleză';

  @override
  String get romanian => 'Română';

  @override
  String get period1h => '1R';

  @override
  String get period2h => '2R';

  @override
  String get periodEt1 => 'PR1';

  @override
  String get periodEt2 => 'PR2';

  @override
  String get editEvent => 'Editează';

  @override
  String get nudgeMinus => '−30 s';

  @override
  String get nudgePlus => '+30 s';

  @override
  String get ownGoal => 'Autogol';

  @override
  String get finishIncompleteBody =>
      'Există evenimente incomplete. Închizi oricum?';

  @override
  String scoreLine(String home, int homeScore, int awayScore, String away) {
    return '$home $homeScore — $awayScore $away';
  }

  @override
  String clockWithAdded(String clock, int minutes) {
    return '$clock +$minutes';
  }
}
