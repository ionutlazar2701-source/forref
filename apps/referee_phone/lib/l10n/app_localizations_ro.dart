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

  @override
  String get matchReport => 'Raportul meciului';

  @override
  String get matchReportRefresh => 'Reîncarcă raportul meciului';

  @override
  String get matchReportTimeUnavailable => 'Timp indisponibil';

  @override
  String get matchReportScoreUnavailable => 'Scorul meciului este indisponibil';

  @override
  String get matchReportScoreConflict =>
      'Scorul meciului este în conflict și nu poate fi afișat';

  @override
  String get matchReportClassificationKnown => 'Cunoscut';

  @override
  String get matchReportClassificationConflict => 'Conflict';

  @override
  String get matchReportClassificationUnavailable => 'Indisponibil';

  @override
  String get matchReportClassificationUnverified => 'Neverificat';

  @override
  String get matchReportClassificationIncomplete => 'Incomplet';

  @override
  String get matchReportYellowCard => 'Cartonaș galben';

  @override
  String get matchReportSendOff => 'Eliminare';

  @override
  String get matchReportSubstitution => 'Schimbare de jucători';

  @override
  String get matchReportTemporal => 'Înregistrare de timp a meciului';

  @override
  String get matchReportSubject => 'Participant fără nume confirmat';

  @override
  String get matchReportTeam => 'Echipă fără nume confirmat';

  @override
  String matchReportRecord(String id) {
    return 'Identificator de înregistrare $id';
  }

  @override
  String get matchReportDirect => 'Eliminare directă';

  @override
  String get matchReportSecondCaution => 'Al doilea avertisment';

  @override
  String get matchReportDependencyReady =>
      'Dependențele eliminării sunt pregătite';

  @override
  String get matchReportDependencyUnavailable =>
      'Dependențele eliminării sunt indisponibile';

  @override
  String get matchReportDependencyConflict =>
      'Dependențele eliminării sunt în conflict';

  @override
  String get matchReportTwoYellowsAreNotSendOff =>
      'Două cartonașe galbene nu reprezintă o eliminare';

  @override
  String matchReportUnsupported(String id) {
    return 'Înregistrare neacceptată $id';
  }

  @override
  String get matchReportNoLines =>
      'Nu există linii de raport pentru acest meci';

  @override
  String get matchReportUnreadable =>
      'Raportul meciului nu poate fi citit din înregistrările comise';

  @override
  String get matchReportLegacyOnly =>
      'Acest meci rămâne doar în sumarul vechi și nu are un raport de Match Memory';

  @override
  String get matchReportUnknown =>
      'Autoritatea meciului este necunoscută și raportul nu este disponibil';

  @override
  String get matchReportAmbiguous =>
      'Autoritatea meciului este ambiguă și raportul este oprit';

  @override
  String get matchReportRetry => 'Încearcă din nou';

  @override
  String get matchReportOpenSummary => 'Deschide sumarul vechi';

  @override
  String get matchReportLegallyEffective =>
      'Efectiv din punct de vedere regulamentar';

  @override
  String get matchReportNotLegallyEffective => 'Fără efect regulamentar';

  @override
  String get matchReportReadFailed =>
      'Raportul meciului nu a putut fi încărcat';

  @override
  String get matchReportFacetScore => 'Scor';

  @override
  String get matchReportFacetTemporal => 'Timpul meciului';

  @override
  String get matchReportFacetGoal => 'Gol';

  @override
  String get matchReportFacetYellow => 'Cartonaș galben';

  @override
  String get matchReportFacetSendOff => 'Eliminare';

  @override
  String get matchReportFacetSubstitution => 'Schimbare de jucători';

  @override
  String matchReportFacetLine(String facet, String classification) {
    return '$facet: $classification';
  }

  @override
  String get matchReportMatchStarted => 'Meci început';

  @override
  String matchReportPeriodStarted(int index) {
    return 'Repriza $index a început';
  }

  @override
  String matchReportPeriodEnded(int index) {
    return 'Repriza $index s-a încheiat';
  }

  @override
  String get matchReportSuspensionStarted => 'Suspendarea meciului a început';

  @override
  String get matchReportSuspensionEnded => 'Suspendarea meciului s-a încheiat';

  @override
  String get matchReportMatchAbandoned => 'Meci abandonat';

  @override
  String get matchReportMatchEnded => 'Meci încheiat';

  @override
  String get matchReportTemporalCorrection => 'Corecție de timp';

  @override
  String get matchReportRefereeEntered => 'Arbitrul a intrat pe teren';

  @override
  String get matchReportLabelsAreNotProof =>
      'Numele echipelor sunt doar etichete de prezentare, nu o dovadă de completitudine';

  @override
  String matchReportMatchId(String id) {
    return 'Meci $id';
  }
}
