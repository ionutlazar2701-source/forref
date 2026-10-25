import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

/// Presentation shape for the approved Jony layouts.
///
/// This is not a stored match preference and it is not a measured bezel.
enum WatchFaceShape { round, rectangular }

/// Live score placement. Layout only. It does not change match state.
enum WatchLiveLayout { centered, scoreSide }

/// Full-bleed design frame. [flow] follows the research route.
enum WatchDesignFrame { flow, team, participant }

enum WatchLanguage { en, ro }

enum WatchCaptureFamily { yellow, red, goal, substitution }

/// Simulated inset so round content stays off the rim.
///
/// Not a published device safe area and not a physical measurement.
double watchSimulatedInset(WatchFaceShape face) {
  return face == WatchFaceShape.round ? 16 : 8;
}

String watchCopy(WatchLanguage language, String key) {
  const en = <String, String>{
    'cautions': 'CAUTIONS',
    'list': 'LIST',
    'beyond': 'BEYOND 90:00',
    'players': 'Players',
    'officials': 'Team Officials',
    'back': 'Back',
    'liveMatch': 'Live Match',
    'noKit': 'No kit color',
    'kitSame': 'Kit colors match',
    'blocked': 'Blocked',
    'morePlayers': 'More players',
    'noPlayers': 'No players on this team',
    'noOfficials': 'No officials on this team',
    'captureUnavailable': 'Capture unavailable',
    'home': 'Home',
    'away': 'Away',
  };
  const ro = <String, String>{
    'cautions': 'AVERTISMENTE',
    'list': 'LISTĂ',
    'beyond': 'DUPĂ 90:00',
    'players': 'Jucători',
    'officials': 'Oficialii echipei',
    'back': 'Înapoi',
    'liveMatch': 'Meci live',
    'noKit': 'Fără culoare de echipament',
    'kitSame': 'Culorile de echipament coincid',
    'blocked': 'Blocat',
    'morePlayers': 'Mai mulți jucători',
    'noPlayers': 'Niciun jucător în această echipă',
    'noOfficials': 'Niciun oficial în această echipă',
    'captureUnavailable': 'Captura nu este disponibilă',
    'home': 'Gazde',
    'away': 'Oaspeți',
  };
  final table = language == WatchLanguage.ro ? ro : en;
  return table[key] ?? en[key] ?? key;
}

abstract final class WatchPalette {
  static const navy = Color(0xFF0B2D5B);
  static const deepNavy = Color(0xFF071D33);
  static const steel = Color(0xFF6E8EAD);
  static const turquoise = Color(0xFF3FC3BE);
  static const ink = Color(0xFFF4F7FB);
  static const yellow = Color(0xFFE6B325);
  static const red = Color(0xFFD64545);
  static const goal = Color(0xFF3FC3BE);
  static const sub = Color(0xFF8FB3D1);
  static const neutral = Color(0xFF14385F);
}

bool watchScoreVerified(ScorePresentation score) {
  return score.available && score.homeGoals != null && score.awayGoals != null;
}

bool watchScoreConflicted(ScorePresentation score) {
  return score.label.toLowerCase().contains('conflict');
}

/// Live layout A or C. Clock text stays the presentation label.
class WatchLiveSurface extends StatelessWidget {
  const WatchLiveSurface({
    super.key,
    required this.state,
    required this.face,
    required this.layout,
    required this.language,
    required this.showBeyondNominal,
    required this.inputEpoch,
    required this.onCapture,
    required this.onKickOffArm,
    required this.onKickOffCommit,
    required this.onCautions,
    required this.onMatchReport,
    required this.onHistory,
    required this.onResolve,
  });

  final WatchPresentationState state;
  final WatchFaceShape face;
  final WatchLiveLayout layout;
  final WatchLanguage language;
  final bool showBeyondNominal;
  final int inputEpoch;
  final VoidCallback onCapture;
  final VoidCallback onKickOffArm;
  final VoidCallback onKickOffCommit;
  final VoidCallback onCautions;
  final VoidCallback onMatchReport;
  final VoidCallback onHistory;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final clockText = state.clock.label ?? state.clock.phaseLabel;
    final showPhase = state.clock.phaseLabel.isNotEmpty &&
        state.clock.phaseLabel != clockText;
    final beyond = showBeyondNominal && state.clock.available;
    final verified = watchScoreVerified(state.score);
    final kickOff = state.clock.kickOffAvailable;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 260;
        final ring = tight ? 52.0 : 68.0;
        return ColoredBox(
          key: const Key('watch-design-live'),
          color: WatchPalette.deepNavy,
          child: Padding(
            padding: EdgeInsets.all(tight ? 6 : watchSimulatedInset(face)),
            child: Column(
              children: [
                if (showPhase)
                  Text(
                    state.clock.phaseLabel,
                    key: const Key('watch-phase'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: WatchPalette.steel,
                      letterSpacing: 0.6,
                    ),
                  ),
                if (beyond)
                  Text(
                    watchCopy(language, 'beyond'),
                    key: const Key('watch-beyond'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: WatchPalette.turquoise,
                    ),
                  ),
                Expanded(
                  child: layout == WatchLiveLayout.centered
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _centered(clockText, verified),
                        )
                      : _scoreSide(clockText, verified),
                ),
                if (!state.navigation.canOpenCapture && !kickOff)
                  Text(
                    watchCopy(language, 'captureUnavailable'),
                    key: const Key('watch-capture-unavailable'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      color: WatchPalette.steel,
                    ),
                  ),
                if (kickOff)
                  _DesignPress(
                    key: const Key('watch-kick-off'),
                    label: 'Kick-off',
                    inputEpoch: inputEpoch,
                    onArm: onKickOffArm,
                    onCommit: onKickOffCommit,
                    fill: WatchPalette.turquoise,
                    ink: WatchPalette.deepNavy,
                    diameter: ring,
                  )
                else
                  _DesignPress(
                    key: const Key('watch-capture-ring'),
                    label: 'Capture',
                    inputEpoch: inputEpoch,
                    onCommit: onCapture,
                    fill: WatchPalette.navy,
                    ink: WatchPalette.ink,
                    border: WatchPalette.turquoise,
                    diameter: ring,
                  ),
                SizedBox(height: tight ? 2 : 4),
                _cautionsFooter(includeDetail: !tight),
                if (onResolve != null)
                  _DesignPress(
                    label: 'Resolve simulated outcome',
                    inputEpoch: inputEpoch,
                    onCommit: onResolve!,
                    fill: WatchPalette.navy,
                    ink: WatchPalette.ink,
                    height: 32,
                  ),
                Row(
                  children: [
                    Expanded(child: _link('Match Report', onMatchReport)),
                    Expanded(child: _link('History', onHistory)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _centered(String clockText, bool verified) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _clock(clockText, 40),
        const SizedBox(height: 4),
        _scoreCluster(verified, compact: false),
      ],
    );
  }

  Widget _scoreSide(String clockText, bool verified) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _clock(clockText, 34),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _scoreCluster(verified, compact: true),
          ),
        ),
      ],
    );
  }

  Widget _clock(String clockText, double size) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        clockText,
        key: const Key('watch-clock'),
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: state.clock.available ? WatchPalette.ink : WatchPalette.steel,
        ),
      ),
    );
  }

  Widget _scoreCluster(bool verified, {required bool compact}) {
    final conflicted = watchScoreConflicted(state.score);
    final numeralSize = compact ? 18.0 : 32.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: conflicted
            ? Border.all(color: WatchPalette.yellow, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verified)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _numeral(
                    '${state.score.homeGoals}',
                    const Key('watch-score-home'),
                    numeralSize,
                    state.homeTeamLabel,
                  ),
                  Text(
                    '—',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: compact ? 12 : 18,
                      color: WatchPalette.steel,
                    ),
                  ),
                  _numeral(
                    '${state.score.awayGoals}',
                    const Key('watch-score-away'),
                    numeralSize,
                    state.awayTeamLabel,
                  ),
                ],
              ),
            ),
          Text(
            state.score.label,
            key: const Key('watch-score'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: verified ? (compact ? 10 : 12) : (compact ? 14 : 20),
              fontWeight: FontWeight.w700,
              color: conflicted ? WatchPalette.yellow : WatchPalette.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numeral(String text, Key key, double size, String caption) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            key: key,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: WatchPalette.ink,
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 9,
              color: WatchPalette.steel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cautionsFooter({required bool includeDetail}) {
    return _DesignPress(
      key: const Key('watch-cautions'),
      label: watchCopy(language, 'cautions'),
      detail: includeDetail ? state.discipline.awarenessLabel : null,
      trailing: watchCopy(language, 'list'),
      inputEpoch: inputEpoch,
      onCommit: onCautions,
      fill: WatchPalette.deepNavy,
      ink: WatchPalette.steel,
      border: WatchPalette.steel,
      height: includeDetail ? 56 : 36,
    );
  }

  Widget _link(String label, VoidCallback onCommit) {
    return _DesignPress(
      label: label,
      inputEpoch: inputEpoch,
      onCommit: onCommit,
      fill: WatchPalette.deepNavy,
      ink: WatchPalette.steel,
      height: 28,
    );
  }
}

/// Capture chooser. Family selection emits an offer or a route. It does not activate.
class WatchCaptureSurface extends StatelessWidget {
  const WatchCaptureSurface({
    super.key,
    required this.face,
    required this.language,
    required this.inputEpoch,
    required this.blocked,
    required this.onFamily,
    required this.onBack,
    required this.onLiveMatch,
  });

  final WatchFaceShape face;
  final WatchLanguage language;
  final int inputEpoch;
  final Set<WatchCaptureFamily> blocked;
  final void Function(WatchCaptureFamily family) onFamily;
  final VoidCallback onBack;
  final VoidCallback onLiveMatch;

  @override
  Widget build(BuildContext context) {
    final round = face == WatchFaceShape.round;
    return ColoredBox(
      key: const Key('watch-design-capture'),
      color: WatchPalette.deepNavy,
      child: Padding(
        padding: EdgeInsets.all(watchSimulatedInset(face)),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _DesignPress(
                key: const Key('watch-capture-back'),
                label: watchCopy(language, 'back'),
                inputEpoch: inputEpoch,
                onCommit: onBack,
                fill: WatchPalette.deepNavy,
                ink: WatchPalette.ink,
                height: 32,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  round ? _round() : _rect(),
                  const Center(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        key: Key('watch-capture-center'),
                        width: 18,
                        height: 18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: WatchPalette.turquoise,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!round)
              _DesignPress(
                key: const Key('watch-capture-live-match'),
                label: watchCopy(language, 'liveMatch'),
                inputEpoch: inputEpoch,
                onCommit: onLiveMatch,
                fill: WatchPalette.navy,
                ink: WatchPalette.ink,
                height: 32,
              ),
          ],
        ),
      ),
    );
  }

  Widget _round() {
    return Column(
      children: [
        Expanded(child: Center(child: _family(WatchCaptureFamily.yellow))),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Center(child: _family(WatchCaptureFamily.substitution))),
              const SizedBox(width: 28),
              Expanded(child: Center(child: _family(WatchCaptureFamily.red))),
            ],
          ),
        ),
        Expanded(child: Center(child: _family(WatchCaptureFamily.goal))),
      ],
    );
  }

  Widget _rect() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _family(WatchCaptureFamily.yellow)),
              const SizedBox(width: 8),
              Expanded(child: _family(WatchCaptureFamily.substitution)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _family(WatchCaptureFamily.goal)),
              const SizedBox(width: 8),
              Expanded(child: _family(WatchCaptureFamily.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _family(WatchCaptureFamily family) {
    final blockedFamily = blocked.contains(family);
    final (label, semantics, fill) = switch (family) {
      WatchCaptureFamily.yellow => ('Yellow', 'Yellow card', WatchPalette.yellow),
      WatchCaptureFamily.red => ('Red', 'Direct red card', WatchPalette.red),
      WatchCaptureFamily.goal => ('Goal', 'Goal', WatchPalette.goal),
      WatchCaptureFamily.substitution => ('Sub', 'Substitution', WatchPalette.sub),
    };
    final key = switch (family) {
      WatchCaptureFamily.yellow => const Key('watch-capture-yellow'),
      WatchCaptureFamily.red => const Key('watch-capture-red'),
      WatchCaptureFamily.goal => const Key('watch-capture-goal'),
      WatchCaptureFamily.substitution => const Key('watch-capture-sub'),
    };
    return Semantics(
      label: semantics,
      button: true,
      enabled: !blockedFamily,
      child: _DesignPress(
        key: key,
        label: label,
        detail: blockedFamily ? watchCopy(language, 'blocked') : null,
        inputEpoch: inputEpoch,
        onCommit: blockedFamily ? null : () => onFamily(family),
        fill: blockedFamily ? WatchPalette.neutral : fill,
        ink: WatchPalette.deepNavy,
      ),
    );
  }
}

/// Home left, away right. Kit color is used only when both verified colors differ.
class WatchTeamSurface extends StatelessWidget {
  const WatchTeamSurface({
    super.key,
    required this.state,
    required this.face,
    required this.language,
    required this.inputEpoch,
    required this.homeKit,
    required this.awayKit,
    required this.onTeam,
    required this.onBack,
  });

  final WatchPresentationState state;
  final WatchFaceShape face;
  final WatchLanguage language;
  final int inputEpoch;
  final Color? homeKit;
  final Color? awayKit;
  final void Function(PresentationTeam team) onTeam;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final distinct = homeKit != null && awayKit != null && homeKit != awayKit;
    final same = homeKit != null && awayKit != null && homeKit == awayKit;
    final note = same
        ? watchCopy(language, 'kitSame')
        : distinct
            ? null
            : watchCopy(language, 'noKit');
    final homeFill = distinct ? homeKit! : WatchPalette.neutral;
    final awayFill = distinct ? awayKit! : WatchPalette.neutral;
    final body = Row(
      children: [
        Expanded(child: _half(PresentationTeam.home, state.homeTeamLabel, homeFill)),
        const SizedBox(
          key: Key('watch-team-gap'),
          width: 10,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(),
          ),
        ),
        Expanded(child: _half(PresentationTeam.away, state.awayTeamLabel, awayFill)),
      ],
    );
    return ColoredBox(
      key: const Key('watch-design-team'),
      color: WatchPalette.deepNavy,
      child: Padding(
        padding: EdgeInsets.all(watchSimulatedInset(face)),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _DesignPress(
                key: const Key('watch-team-back'),
                label: watchCopy(language, 'back'),
                inputEpoch: inputEpoch,
                onCommit: onBack,
                fill: WatchPalette.deepNavy,
                ink: WatchPalette.ink,
                height: 32,
              ),
            ),
            if (note != null)
              Text(
                note,
                key: const Key('watch-team-kit-note'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: WatchPalette.steel,
                ),
              ),
            Expanded(
              child: face == WatchFaceShape.round ? ClipOval(child: body) : body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _half(PresentationTeam team, String label, Color fill) {
    final key = team == PresentationTeam.home
        ? const Key('watch-team-home')
        : const Key('watch-team-away');
    return _DesignPress(
      key: key,
      label: label,
      inputEpoch: inputEpoch,
      onCommit: () => onTeam(team),
      fill: fill,
      ink: WatchPalette.ink,
      border: WatchPalette.steel,
      expand: true,
    );
  }
}

/// Players and officials on separate swipe pages. A tap selects. It does not activate.
class WatchParticipantSurface extends StatelessWidget {
  const WatchParticipantSurface({
    super.key,
    required this.state,
    required this.face,
    required this.language,
    required this.inputEpoch,
    required this.selectionEnabled,
    required this.eventLabel,
    required this.onPlayer,
    required this.onOfficial,
    required this.onBack,
  });

  final WatchPresentationState state;
  final WatchFaceShape face;
  final WatchLanguage language;
  final int inputEpoch;
  final bool selectionEnabled;
  final String eventLabel;
  final void Function(PresentationParticipant person) onPlayer;
  final void Function(PresentationOfficial official) onOfficial;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final team = switch (state.header.teamContext) {
      PresentationTeamContext.home => PresentationTeam.home,
      PresentationTeamContext.away => PresentationTeam.away,
      PresentationTeamContext.absent ||
      PresentationTeamContext.ambiguous =>
        null,
    };
    final players = [
      for (final person in state.roster)
        if (team == null || person.team == team) person,
    ];
    final officials = [
      for (final official in state.officials)
        if (team == null || official.team == team) official,
    ];
    final playerPages = players.isEmpty ? 1 : (players.length / 7).ceil();
    final pageCount = playerPages + 1;
    final teamLabel = switch (team) {
      PresentationTeam.home => state.homeTeamLabel,
      PresentationTeam.away => state.awayTeamLabel,
      null => '',
    };
    return ColoredBox(
      key: const Key('watch-design-participant'),
      color: WatchPalette.deepNavy,
      child: Padding(
        padding: EdgeInsets.all(watchSimulatedInset(face)),
        child: Column(
          children: [
            Row(
              children: [
                _DesignPress(
                  key: const Key('watch-participant-back'),
                  label: watchCopy(language, 'back'),
                  inputEpoch: inputEpoch,
                  onCommit: onBack,
                  fill: WatchPalette.deepNavy,
                  ink: WatchPalette.ink,
                  height: 32,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    teamLabel.isEmpty ? eventLabel : '$eventLabel · $teamLabel',
                    key: const Key('watch-participant-context'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: WatchPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: PageView.builder(
                key: const Key('watch-participant-pager'),
                itemCount: pageCount,
                itemBuilder: (context, index) {
                  if (index >= playerPages) {
                    return _officialPage(officials);
                  }
                  final start = index * 7;
                  final end = (start + 7).clamp(0, players.length);
                  final slice = players.sublist(start, end);
                  return _playerPage(
                    slice,
                    page: index,
                    pageCount: playerPages,
                    overflow: players.length > 7,
                  );
                },
              ),
            ),
            _dots(pageCount),
          ],
        ),
      ),
    );
  }

  Widget _playerPage(
    List<PresentationParticipant> slice, {
    required int page,
    required int pageCount,
    required bool overflow,
  }) {
    return Column(
      children: [
        Text(
          overflow
              ? '${watchCopy(language, 'players')} ${page + 1}/$pageCount'
              : watchCopy(language, 'players'),
          key: Key('watch-player-page-$page'),
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: WatchPalette.steel,
          ),
        ),
        if (overflow && page > 0)
          Text(
            watchCopy(language, 'morePlayers'),
            key: const Key('watch-player-overflow'),
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 10,
              color: WatchPalette.turquoise,
            ),
          ),
        Expanded(
          child: slice.isEmpty
              ? Center(
                  child: Text(
                    watchCopy(language, 'noPlayers'),
                    key: const Key('watch-no-players'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: WatchPalette.steel,
                    ),
                  ),
                )
              : _chipGrid(slice.length, (index) {
                  final person = slice[index];
                  final caption = person.team == PresentationTeam.home
                      ? state.homeTeamLabel
                      : state.awayTeamLabel;
                  return _chip(
                    key: Key('watch-participant-${person.id}'),
                    label: person.shirtLabel,
                    detail: caption,
                    onCommit: selectionEnabled ? () => onPlayer(person) : null,
                  );
                }),
        ),
      ],
    );
  }

  Widget _officialPage(List<PresentationOfficial> officials) {
    return Column(
      children: [
        Text(
          watchCopy(language, 'officials'),
          key: const Key('watch-officials-page'),
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: WatchPalette.steel,
          ),
        ),
        Expanded(
          child: officials.isEmpty
              ? Center(
                  child: Text(
                    watchCopy(language, 'noOfficials'),
                    key: const Key('watch-no-officials'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: WatchPalette.steel,
                    ),
                  ),
                )
              : _chipGrid(officials.length, (index) {
                  final official = officials[index];
                  return _chip(
                    key: Key('watch-official-${official.id}'),
                    label: official.roleLabel,
                    detail: official.name,
                    onCommit: selectionEnabled ? () => onOfficial(official) : null,
                  );
                }),
        ),
      ],
    );
  }

  Widget _chipGrid(int count, Widget Function(int index) build) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = <Widget>[];
        var index = 0;
        while (index < count) {
          final remaining = count - index;
          final take = remaining >= 3 ? 3 : remaining;
          rows.add(
            Expanded(
              child: Row(
                children: [
                  for (var slot = 0; slot < take; slot++)
                    Expanded(child: build(index + slot)),
                  if (take == 1) const Spacer(),
                  if (take == 1) const Spacer(),
                  if (take == 2) const Spacer(),
                ],
              ),
            ),
          );
          index += take;
        }
        return Column(children: rows);
      },
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required String detail,
    required VoidCallback? onCommit,
  }) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: _DesignPress(
        key: key,
        label: label,
        detail: selectionEnabled ? detail : watchCopy(language, 'blocked'),
        inputEpoch: inputEpoch,
        onCommit: onCommit,
        fill: selectionEnabled ? WatchPalette.navy : WatchPalette.neutral,
        ink: WatchPalette.ink,
        border: WatchPalette.steel,
      ),
    );
  }

  Widget _dots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            key: Key('watch-pager-dot-$i'),
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: const BoxDecoration(
              color: WatchPalette.turquoise,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _DesignPress extends StatefulWidget {
  const _DesignPress({
    super.key,
    required this.label,
    required this.inputEpoch,
    required this.onCommit,
    required this.fill,
    required this.ink,
    this.detail,
    this.trailing,
    this.onArm,
    this.border,
    this.diameter,
    this.height = 48,
    this.expand = false,
  });

  final String label;
  final String? detail;
  final String? trailing;
  final int inputEpoch;
  final VoidCallback? onCommit;
  final VoidCallback? onArm;
  final Color fill;
  final Color ink;
  final Color? border;
  final double? diameter;
  final double height;
  final bool expand;

  @override
  State<_DesignPress> createState() => _DesignPressState();
}

class _DesignPressState extends State<_DesignPress> {
  int? _pointer;
  int? _epoch;

  bool _contains(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    return box.size.contains(box.globalToLocal(global));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final natural = widget.diameter ?? widget.height;
        final maxHeight = constraints.maxHeight;
        final maxWidth = constraints.maxWidth;
        final side = widget.diameter ??
            (widget.expand && maxHeight.isFinite
                ? maxHeight
                : maxHeight.isFinite
                    ? math.min(natural, maxHeight)
                    : natural);
        final width = widget.diameter ??
            (maxWidth.isFinite ? maxWidth : natural);
        return SizedBox(
          width: width,
          height: side,
          child: _face(),
        );
      },
    );
  }

  Widget _face() {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.fill,
        shape: widget.diameter == null ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: widget.diameter == null ? BorderRadius.circular(10) : null,
        border: widget.border == null ? null : Border.all(color: widget.border!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.ink,
                ),
              ),
              if (widget.detail != null)
                Text(
                  widget.detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 9,
                    color: widget.ink.withValues(alpha: 0.85),
                  ),
                ),
              if (widget.trailing != null)
                Text(
                  widget.trailing!,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.ink,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (!mounted || widget.onCommit == null) return;
        _pointer = event.pointer;
        _epoch = widget.inputEpoch;
        widget.onArm?.call();
      },
      onPointerMove: (event) {
        if (!mounted || _pointer != event.pointer) return;
        if (!_contains(event.position)) _pointer = null;
      },
      onPointerUp: (event) {
        if (!mounted) return;
        final commit = widget.onCommit != null &&
            _pointer == event.pointer &&
            _epoch == widget.inputEpoch &&
            _contains(event.position);
        _pointer = null;
        if (commit) widget.onCommit!();
      },
      onPointerCancel: (event) {
        if (!mounted) return;
        if (_pointer == event.pointer) _pointer = null;
      },
      child: child,
    );
  }
}
