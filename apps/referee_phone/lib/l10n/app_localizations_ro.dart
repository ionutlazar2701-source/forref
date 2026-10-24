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
  String get devicesTitle => 'Dispozitive';

  @override
  String get noCompanionDevice => 'Niciun dispozitiv companion';

  @override
  String get phoneCanRunMatch =>
      'Telefonul poate rula în continuare fluxurile de meci acceptate';

  @override
  String get phoneOnlyMode => 'Doar telefon';

  @override
  String get commandAvailabilityTitle => 'Comenzi';

  @override
  String get kickOffCommandAvailable => 'Start disponibil';

  @override
  String get kickOffCommandUnavailable => 'Start indisponibil';

  @override
  String get goalCommandAvailable => 'Gol disponibil';

  @override
  String get goalCommandUnavailable => 'Gol indisponibil';

  @override
  String notInProductionBuild(String name) {
    return '$name nu este disponibil în această versiune de producție';
  }

  @override
  String authorityRequiredForCommand(String name) {
    return '$name necesită autoritate de captură';
  }

  @override
  String get companionDoesNotControlMatch =>
      'Companionul nu controlează meciul';

  @override
  String get matchReportDisciplineUnsupported =>
      'Cartonașele și schimbările nu sunt încă în raportul de producție';

  @override
  String get outcomeUnknownLabel => 'Rezultat necunoscut';

  @override
  String get goalNotSaved => 'Golul nu a fost salvat';

  @override
  String get localStorageReady => 'Stocare locală pregătită';

  @override
  String get commandNameYellow => 'Cartonaș galben';

  @override
  String get commandNameDirectSendOff => 'Eliminare directă';

  @override
  String get commandNameSecondCaution => 'Eliminare după al doilea galben';

  @override
  String get commandNameSubstitution => 'Schimbare';

  @override
  String get commandNameFullTime => 'Timp regulamentar';

  @override
  String get commandNameFinishMatch => 'Închidere meci';

  @override
  String get platformWearOs => 'Wear OS';

  @override
  String get platformWatchOs => 'watchOS';

  @override
  String get platformGarmin => 'Garmin';

  @override
  String get platformZepp => 'Zepp OS';

  @override
  String get platformHuawei => 'Huawei';

  @override
  String get platformUnknown => 'Platformă necunoscută';

  @override
  String get connectionConnected => 'Conectat';

  @override
  String get connectionDisconnected => 'Deconectat';

  @override
  String get connectionLostLabel => 'Conexiune pierdută';

  @override
  String get certificationUnknownLabel => 'Certificare necunoscută';

  @override
  String get certificationKnownLabel => 'Dispozitiv cunoscut';

  @override
  String get certificationCompatibleLabel => 'Compatibil';

  @override
  String get certificationCertifiedLabel => 'Certificat';

  @override
  String get pairingNotPaired => 'Neperecheat';

  @override
  String get noDeclaredCapabilities => 'Nicio capacitate declarată';

  @override
  String get capabilityCaptureGoal => 'Captură gol';

  @override
  String get capabilityCaptureYellow => 'Captură galben';

  @override
  String get capabilityCaptureSendOff => 'Captură eliminare';

  @override
  String get capabilityCaptureSubstitution => 'Captură schimbare';

  @override
  String get capabilityLocalMatchMemory => 'Memorie de meci locală';

  @override
  String get capabilityIndependentTiming => 'Cronometraj independent';

  @override
  String get capabilityLocalHaptics => 'Vibrație locală';

  @override
  String get capabilityPeerTransport => 'Transport către companion';

  @override
  String get preparationTitle => 'Pregătire';

  @override
  String get sectionMatch => 'Meci';

  @override
  String get sectionTeams => 'Echipe';

  @override
  String get sectionCrew => 'Brigadă';

  @override
  String get sectionReadiness => 'Verificare';

  @override
  String get fieldRequired => 'Obligatoriu';

  @override
  String get fieldOptional => 'Opțional';

  @override
  String get homeTeamNotSet => 'Echipa gazdă nu este setată';

  @override
  String get awayTeamNotSet => 'Echipa oaspete nu este setată';

  @override
  String get homeTeamRequired => 'Echipa gazdă este obligatorie';

  @override
  String get awayTeamRequired => 'Echipa oaspete este obligatorie';

  @override
  String get halfLengthRequired => 'Durata reprizei este obligatorie';

  @override
  String get localRecordingUnavailable =>
      'Înregistrarea locală nu este disponibilă';

  @override
  String get recordingAuthorityUnconfirmed =>
      'Autoritatea de înregistrare nu este confirmată';

  @override
  String get needsAttention => 'Necesită atenție';

  @override
  String get matchSetupReady => 'Configurarea meciului este gata';

  @override
  String get readyToOfficiateOnThisPhone => 'Gata de arbitraj pe acest telefon';

  @override
  String get optionalDetailsDoNotBlock =>
      'Detaliile opționale nu blochează meciul';

  @override
  String get enterLiveMatch => 'Intră în meciul live';

  @override
  String get fixtureGroupCurrent => 'În desfășurare';

  @override
  String get fixtureGroupUpcoming => 'Urmează';

  @override
  String get fixtureGroupNeedsAttention => 'Necesită atenție';

  @override
  String get fixtureGroupNotStarted => 'Neînceput';

  @override
  String get fixtureGroupCompleted => 'Încheiate';

  @override
  String get checkingMatchState => 'Se verifică starea meciului';
}
