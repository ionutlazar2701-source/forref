import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simulator_presentation/simulator_presentation.dart';

import 'watch_aperture.dart';
import 'watch_glyphs.dart';

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

/// Content margin inside an aperture the shell has already clipped.
///
/// Not a published device safe area, not a bezel width, and not a millimetre.
double watchSimulatedInset(WatchFaceShape face) {
  return watchContentMargin(round: face == WatchFaceShape.round);
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
    'captureEvent': 'Capture event',
    'home': 'Home',
    'away': 'Away',
    'notSubject': 'Not this event',
    'layoutHold': 'LAYOUT HOLD',
    'yellow': 'Yellow',
    'red': 'Red',
    'goal': 'Goal',
    'sub': 'Sub',
    'yellowCard': 'Yellow card',
    'redCard': 'Direct red card',
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
    'captureEvent': 'Capturează evenimentul',
    'home': 'Gazde',
    'away': 'Oaspeți',
    'notSubject': 'Nu pentru acest eveniment',
    'layoutHold': 'LAYOUT HOLD',
    'yellow': 'Galben',
    'red': 'Roșu',
    'goal': 'Gol',
    'sub': 'Schimbare',
    'yellowCard': 'Cartonaș galben',
    'redCard': 'Cartonaș roșu direct',
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
        final assessment = WatchApertureAssessment.live(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          round: face == WatchFaceShape.round,
          showPhase: showPhase,
          showBeyond: beyond,
          showResolve: onResolve != null,
        );
        if (assessment.holds) {
          return WatchApertureHold(reason: assessment.reason!);
        }
        final ring = math.min(
          face == WatchFaceShape.round && layout == WatchLiveLayout.centered
              ? 86.0
              : 72.0,
          math.max(
            WatchApertureLimits.capture,
            constraints.maxWidth *
                (face == WatchFaceShape.round &&
                        layout == WatchLiveLayout.centered
                    ? 0.36
                    : 0.28),
          ),
        );
        if (face == WatchFaceShape.round &&
            layout == WatchLiveLayout.centered) {
          return _a1Round(clockText, showPhase, beyond, verified, ring);
        }
        return ColoredBox(
          key: const Key('watch-design-live'),
          color: WatchPalette.deepNavy,
          child: Padding(
            padding: EdgeInsets.all(watchSimulatedInset(face)),
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
                  _CaptureRing(
                    diameter: ring,
                    inputEpoch: inputEpoch,
                    onCommit: onCapture,
                    semanticsLabel: watchCopy(language, 'captureEvent'),
                  ),
                const SizedBox(height: 4),
                _cautionsFooter(),
                if (onResolve != null)
                  _DesignPress(
                    label: 'Resolve simulated outcome',
                    inputEpoch: inputEpoch,
                    onCommit: onResolve!,
                    fill: WatchPalette.navy,
                    ink: WatchPalette.ink,
                    height: 32,
                    minExtent: 32,
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

  /// Approved Live A1 round composition.
  ///
  /// Research Idle, Match Report, and History stay off this face.
  /// A verified score is one line. The clock stays the largest text.
  Widget _a1Round(
    String clockText,
    bool showPhase,
    bool beyond,
    bool verified,
    double ring,
  ) {
    final conflicted = watchScoreConflicted(state.score);
    return ColoredBox(
      key: const Key('watch-design-live'),
      color: WatchPalette.deepNavy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          watchSimulatedInset(face),
          2,
          watchSimulatedInset(face),
          2,
        ),
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
                  fontWeight: FontWeight.w600,
                  color: WatchPalette.steel,
                  letterSpacing: 1.6,
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
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: WatchPalette.steel,
                  letterSpacing: 0.8,
                ),
              ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  clockText,
                  key: const Key('watch-clock'),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: state.clock.available
                        ? WatchPalette.ink
                        : WatchPalette.steel,
                  ),
                ),
              ),
            ),
            _a1Score(verified, conflicted),
            const SizedBox(height: 6),
            if (state.clock.kickOffAvailable)
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
              _CaptureRing(
                diameter: ring,
                inputEpoch: inputEpoch,
                onCommit: onCapture,
                semanticsLabel: watchCopy(language, 'captureEvent'),
                showWord: false,
                mark: const WatchRefereeMark(),
              ),
            const SizedBox(height: 2),
            _quietCautions(),
            if (onResolve != null)
              _DesignPress(
                label: 'Resolve simulated outcome',
                inputEpoch: inputEpoch,
                onCommit: onResolve!,
                fill: WatchPalette.navy,
                ink: WatchPalette.ink,
                height: 32,
                minExtent: 32,
              ),
          ],
        ),
      ),
    );
  }

  Widget _a1Score(bool verified, bool conflicted) {
    if (!verified || conflicted) {
      return Text(
        state.score.label,
        key: const Key('watch-score'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: conflicted ? 14 : 13,
          fontWeight: FontWeight.w600,
          color: conflicted ? WatchPalette.yellow : WatchPalette.steel,
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            state.homeTeamLabel.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WatchPalette.steel,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${state.score.homeGoals}',
            key: const Key('watch-score-home'),
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: WatchPalette.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '–',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: WatchPalette.ink,
              ),
            ),
          ),
          Text(
            '${state.score.awayGoals}',
            key: const Key('watch-score-away'),
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: WatchPalette.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state.awayTeamLabel.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WatchPalette.steel,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quietCautions() {
    final unresolved =
        state.discipline.awareness == PriorAwareness.unavailable ||
            state.discipline.awareness == PriorAwareness.conflicted;
    return _DesignPress(
      key: const Key('watch-cautions'),
      label:
          '${watchCopy(language, 'cautions')} ${watchCopy(language, 'list')}',
      semanticsLabel: watchCopy(language, 'cautions'),
      detail: unresolved ? state.discipline.awarenessLabel : null,
      glyph: const _QuietCautionMark(),
      inputEpoch: inputEpoch,
      onCommit: onCautions,
      fill: WatchPalette.deepNavy,
      ink: WatchPalette.steel,
      height: WatchApertureLimits.footer,
      minExtent: WatchApertureLimits.footer,
      showBorder: false,
      inline: true,
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

  Widget _cautionsFooter() {
    return _DesignPress(
      key: const Key('watch-cautions'),
      label: watchCopy(language, 'cautions'),
      detail: state.discipline.awarenessLabel,
      trailing: watchCopy(language, 'list'),
      glyph: const WatchListGlyph(),
      inputEpoch: inputEpoch,
      onCommit: onCautions,
      fill: WatchPalette.deepNavy,
      ink: WatchPalette.steel,
      border: WatchPalette.steel,
      height: WatchApertureLimits.footer,
      minExtent: WatchApertureLimits.footer,
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

class _CaptureRing extends StatelessWidget {
  const _CaptureRing({
    required this.diameter,
    required this.inputEpoch,
    required this.onCommit,
    required this.semanticsLabel,
    this.showWord = true,
    this.mark = const WatchCaptureGlyph(),
  });

  final double diameter;
  final int inputEpoch;
  final VoidCallback onCommit;
  final String semanticsLabel;
  final bool showWord;
  final Widget mark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _CaptureOrnament(side: 'left'),
        const SizedBox(width: 14),
        _DesignPress(
          key: const Key('watch-capture-ring'),
          label: 'Capture',
          semanticsLabel: semanticsLabel,
          showLabel: showWord,
          glyph: SizedBox(
            width: showWord ? 28 : diameter * 0.46,
            height: showWord ? 22 : diameter * 0.46,
            child: mark,
          ),
          inputEpoch: inputEpoch,
          onCommit: onCommit,
          fill: WatchPalette.navy,
          ink: WatchPalette.ink,
          border: WatchPalette.turquoise,
          diameter: diameter,
          minExtent: WatchApertureLimits.capture,
          strokeWidth: showWord ? 1 : 2.4,
        ),
        const SizedBox(width: 14),
        const _CaptureOrnament(side: 'right'),
      ],
    );
  }
}

/// List mark plus a non-count yellow dot from the approved live board.
///
/// The dot is decoration. It is not a caution count and not a badge.
class _QuietCautionMark extends StatelessWidget {
  const _QuietCautionMark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WatchListGlyph(),
        SizedBox(width: 6),
        ExcludeSemantics(
          child: SizedBox(
            key: Key('watch-cautions-mark'),
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: WatchPalette.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Decorative bars from the live board. They are not controls.
class _CaptureOrnament extends StatelessWidget {
  const _CaptureOrnament({required this.side});

  final String side;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        key: Key('watch-capture-ornament-$side'),
        width: 18,
        height: 8,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 2; i++)
              const SizedBox(
                width: 18,
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: WatchPalette.steel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackChevronPainter extends CustomPainter {
  const _BackChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WatchPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.68, size.height * 0.18)
      ..lineTo(size.width * 0.32, size.height * 0.50)
      ..lineTo(size.width * 0.68, size.height * 0.82);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BackChevronPainter oldDelegate) => false;
}

class WatchApertureHold extends StatelessWidget {
  const WatchApertureHold({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('watch-aperture-hold'),
      color: WatchPalette.deepNavy,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: math.max(48, constraints.maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LAYOUT HOLD',
                      key: Key('watch-aperture-hold-title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WatchPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: WatchPalette.steel,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Capture chooser. Family selection starts the presentation journey.
/// It does not activate a record.
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
    this.captureOpen = true,
  });

  final WatchFaceShape face;
  final WatchLanguage language;
  final int inputEpoch;
  final Set<WatchCaptureFamily> blocked;
  final void Function(WatchCaptureFamily family) onFamily;
  final VoidCallback onBack;
  final VoidCallback onLiveMatch;
  final bool captureOpen;

  @override
  Widget build(BuildContext context) {
    final round = face == WatchFaceShape.round;
    return LayoutBuilder(
      builder: (context, constraints) {
        final assessment = WatchApertureAssessment.capture(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          round: round,
        );
        if (assessment.holds) {
          return WatchApertureHold(reason: assessment.reason!);
        }
        final rows = round ? 3 : 2;
        final margin = watchSimulatedInset(face) * 2;
        final chrome = WatchApertureLimits.back +
            (round ? 0 : WatchApertureLimits.back) +
            16;
        var extent = math.min(
          84.0,
          math.min(
            (constraints.maxHeight - margin - chrome) / rows - 4,
            (constraints.maxWidth - margin - 12) / 2,
          ),
        );
        if (round) {
          final span = math.min(constraints.maxWidth, constraints.maxHeight) -
              margin -
              WatchApertureLimits.back -
              8;
          extent = math.min(extent, span / 3);
        }
        if (extent < WatchApertureLimits.family) {
          return const WatchApertureHold(
              reason: WatchApertureAssessment.holdReason);
        }
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
                    label: round ? '' : watchCopy(language, 'back'),
                    semanticsLabel: watchCopy(language, 'back'),
                    showLabel: !round,
                    glyph: round
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CustomPaint(painter: _BackChevronPainter()),
                          )
                        : null,
                    inputEpoch: inputEpoch,
                    onCommit: onBack,
                    fill: WatchPalette.deepNavy,
                    ink: WatchPalette.ink,
                    height: WatchApertureLimits.back,
                    boxWidth: round ? WatchApertureLimits.back : 96,
                    minExtent: WatchApertureLimits.back,
                    showBorder: !round,
                  ),
                ),
                Expanded(
                  child: round
                      ? _round(extent)
                      : Stack(
                          children: [
                            _rect(extent),
                            const Center(child: _CaptureCenterDot()),
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
                    height: WatchApertureLimits.back,
                    minExtent: WatchApertureLimits.back,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _round(double extent) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const IgnorePointer(
          child: CustomPaint(
            painter: _CaptureGuidePainter(),
            child: SizedBox.expand(),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: _hexFamily(WatchCaptureFamily.yellow, extent),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _hexFamily(WatchCaptureFamily.red, extent),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _hexFamily(WatchCaptureFamily.goal, extent),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _hexFamily(WatchCaptureFamily.substitution, extent),
        ),
        const _CaptureCenterDot(),
      ],
    );
  }

  Widget _hexFamily(WatchCaptureFamily family, double extent) {
    final blockedFamily = blocked.contains(family) || !captureOpen;
    final label = switch (family) {
      WatchCaptureFamily.yellow => watchCopy(language, 'yellow'),
      WatchCaptureFamily.red => watchCopy(language, 'red'),
      WatchCaptureFamily.goal => watchCopy(language, 'goal'),
      WatchCaptureFamily.substitution => watchCopy(language, 'sub'),
    };
    final semantics = switch (family) {
      WatchCaptureFamily.yellow => watchCopy(language, 'yellowCard'),
      WatchCaptureFamily.red => watchCopy(language, 'redCard'),
      WatchCaptureFamily.goal => watchCopy(language, 'goal'),
      WatchCaptureFamily.substitution => watchCopy(language, 'sub'),
    };
    final key = switch (family) {
      WatchCaptureFamily.yellow => const Key('watch-capture-yellow'),
      WatchCaptureFamily.red => const Key('watch-capture-red'),
      WatchCaptureFamily.goal => const Key('watch-capture-goal'),
      WatchCaptureFamily.substitution => const Key('watch-capture-sub'),
    };
    return _DesignPress(
      key: key,
      label: label,
      semanticsLabel: semantics,
      glyph: SizedBox(
        width: extent * 0.58,
        height: extent * 0.46,
        child: WatchRoundFamilyMark(family: family, blocked: blockedFamily),
      ),
      detail: blockedFamily ? watchCopy(language, 'blocked') : null,
      inputEpoch: inputEpoch,
      onCommit: blockedFamily ? null : () => onFamily(family),
      fill: const Color(0xFF0A2748),
      ink: blockedFamily ? WatchPalette.steel : WatchPalette.ink,
      border: WatchPalette.steel,
      boxWidth: extent,
      boxHeight: extent,
      minExtent: WatchApertureLimits.family,
      hexagon: true,
    );
  }

  Widget _rect(double extent) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                  child: Center(
                      child: _family(WatchCaptureFamily.yellow, extent))),
              const SizedBox(width: 12),
              Expanded(
                child: Center(
                    child: _family(WatchCaptureFamily.substitution, extent)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                  child:
                      Center(child: _family(WatchCaptureFamily.goal, extent))),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      Center(child: _family(WatchCaptureFamily.red, extent))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _family(WatchCaptureFamily family, double extent) {
    final blockedFamily = blocked.contains(family) || !captureOpen;
    final label = switch (family) {
      WatchCaptureFamily.yellow => watchCopy(language, 'yellow'),
      WatchCaptureFamily.red => watchCopy(language, 'red'),
      WatchCaptureFamily.goal => watchCopy(language, 'goal'),
      WatchCaptureFamily.substitution => watchCopy(language, 'sub'),
    };
    final semantics = switch (family) {
      WatchCaptureFamily.yellow => watchCopy(language, 'yellowCard'),
      WatchCaptureFamily.red => watchCopy(language, 'redCard'),
      WatchCaptureFamily.goal => watchCopy(language, 'goal'),
      WatchCaptureFamily.substitution => watchCopy(language, 'sub'),
    };
    final key = switch (family) {
      WatchCaptureFamily.yellow => const Key('watch-capture-yellow'),
      WatchCaptureFamily.red => const Key('watch-capture-red'),
      WatchCaptureFamily.goal => const Key('watch-capture-goal'),
      WatchCaptureFamily.substitution => const Key('watch-capture-sub'),
    };
    return Semantics(
      label: semantics,
      button: !blockedFamily,
      enabled: !blockedFamily,
      child: _DesignPress(
        key: key,
        label: label,
        glyph: SizedBox(
          width: 36,
          height: 28,
          child: WatchFamilyMark(family: family, blocked: blockedFamily),
        ),
        detail: blockedFamily ? watchCopy(language, 'blocked') : null,
        inputEpoch: inputEpoch,
        onCommit: blockedFamily ? null : () => onFamily(family),
        fill: WatchPalette.navy,
        ink: blockedFamily ? WatchPalette.steel : WatchPalette.ink,
        border: WatchPalette.steel,
        boxWidth: extent,
        boxHeight: extent,
        minExtent: WatchApertureLimits.family,
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
    this.eventLabel,
  });

  final WatchPresentationState state;
  final WatchFaceShape face;
  final WatchLanguage language;
  final int inputEpoch;
  final Color? homeKit;
  final Color? awayKit;
  final void Function(PresentationTeam team) onTeam;
  final VoidCallback onBack;
  final String? eventLabel;

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
        Expanded(
            child: _half(PresentationTeam.home, state.homeTeamLabel, homeFill)),
        const SizedBox(
          key: Key('watch-team-gap'),
          width: 10,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(),
          ),
        ),
        Expanded(
            child: _half(PresentationTeam.away, state.awayTeamLabel, awayFill)),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final assessment = WatchApertureAssessment.team(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          round: face == WatchFaceShape.round,
        );
        if (assessment.holds) {
          return WatchApertureHold(reason: assessment.reason!);
        }
        return _teamBody(note, body);
      },
    );
  }

  Widget _teamBody(String? note, Widget body) {
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
                height: WatchApertureLimits.back,
                boxWidth: 96,
                minExtent: WatchApertureLimits.back,
              ),
            ),
            if (eventLabel != null)
              Text(
                eventLabel!,
                key: const Key('watch-team-context'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: WatchPalette.ink,
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
              child:
                  face == WatchFaceShape.round ? ClipOval(child: body) : body,
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
    this.teamFilter,
    this.officialsEnabled = true,
  });

  final WatchPresentationState state;
  final WatchFaceShape face;
  final WatchLanguage language;
  final int inputEpoch;
  final bool selectionEnabled;
  final String eventLabel;
  final PresentationTeam? teamFilter;
  final bool officialsEnabled;
  final void Function(PresentationParticipant person) onPlayer;
  final void Function(PresentationOfficial official) onOfficial;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final team = teamFilter ??
        switch (state.header.teamContext) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final assessment = WatchApertureAssessment.participant(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          round: face == WatchFaceShape.round,
        );
        if (assessment.holds) {
          return WatchApertureHold(reason: assessment.reason!);
        }
        return _participantBody(
          players: players,
          officials: officials,
          playerPages: playerPages,
          pageCount: pageCount,
          teamLabel: teamLabel,
        );
      },
    );
  }

  Widget _participantBody({
    required List<PresentationParticipant> players,
    required List<PresentationOfficial> officials,
    required int playerPages,
    required int pageCount,
    required String teamLabel,
  }) {
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
                  height: WatchApertureLimits.back,
                  boxWidth: 96,
                  minExtent: WatchApertureLimits.back,
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
              : _chipGrid(slice.length, columns: 3, (index) {
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
              : _chipGrid(officials.length, columns: 2, (index) {
                  final official = officials[index];
                  return _chip(
                    key: Key('watch-official-${official.id}'),
                    label: official.roleLabel,
                    detail: official.name,
                    onCommit: selectionEnabled && officialsEnabled
                        ? () => onOfficial(official)
                        : null,
                  );
                }),
        ),
      ],
    );
  }

  Widget _chipGrid(
    int count,
    Widget Function(int index) build, {
    required int columns,
  }) {
    final rows = <Widget>[];
    var index = 0;
    while (index < count) {
      final remaining = count - index;
      final take = remaining >= columns ? columns : remaining;
      final centerLast = take == 1;
      rows.add(
        Expanded(
          child: Row(
            children: [
              if (centerLast) const Spacer(),
              for (var slot = 0; slot < take; slot++)
                Expanded(child: build(index + slot)),
              if (centerLast || take < columns) const Spacer(),
            ],
          ),
        ),
      );
      index += take;
    }
    return Column(children: rows);
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
        detail: onCommit == null
            ? (selectionEnabled
                ? watchCopy(language, 'notSubject')
                : watchCopy(language, 'blocked'))
            : detail,
        inputEpoch: inputEpoch,
        onCommit: onCommit,
        fill: onCommit == null ? WatchPalette.neutral : WatchPalette.navy,
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
    this.glyph,
    this.semanticsLabel,
    this.boxWidth,
    this.boxHeight,
    this.minExtent,
    this.showLabel = true,
    this.showBorder = true,
    this.strokeWidth = 1,
    this.hexagon = false,
    this.inline = false,
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
  final Widget? glyph;
  final String? semanticsLabel;
  final double? boxWidth;
  final double? boxHeight;
  final double? minExtent;
  final bool showLabel;
  final bool showBorder;
  final double strokeWidth;
  final bool hexagon;
  final bool inline;

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

  Widget _labelText(
      {required double size, FontWeight weight = FontWeight.w700}) {
    return Text(
      widget.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: weight,
        color: widget.ink,
        letterSpacing: widget.inline ? 0.8 : 0,
      ),
    );
  }

  Widget _detailText() {
    return Text(
      widget.detail!,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 9,
        color: widget.ink.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _stackedBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.glyph != null) widget.glyph!,
        if (widget.showLabel) _labelText(size: widget.hexagon ? 11 : 13),
        if (widget.detail != null) _detailText(),
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
    );
  }

  Widget _inlineBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.glyph != null) widget.glyph!,
            if (widget.glyph != null && widget.showLabel)
              const SizedBox(width: 8),
            if (widget.showLabel) _labelText(size: 11, weight: FontWeight.w600),
          ],
        ),
        if (widget.detail != null) _detailText(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final maxWidth = constraints.maxWidth;
        final floor = widget.minExtent ?? 0;
        late final double width;
        late final double height;
        if (widget.diameter != null) {
          final side = math.max(widget.diameter!, floor);
          width = side;
          height = side;
        } else if (widget.boxWidth != null || widget.boxHeight != null) {
          width = math.max(widget.boxWidth ?? widget.height, floor);
          height = math.max(widget.boxHeight ?? widget.height, floor);
        } else if (widget.expand && maxHeight.isFinite) {
          width = maxWidth.isFinite ? maxWidth : widget.height;
          height = math.max(maxHeight, floor);
        } else {
          width = maxWidth.isFinite ? maxWidth : widget.height;
          final natural = widget.height;
          height = maxHeight.isFinite
              ? math.max(floor, math.min(natural, maxHeight))
              : math.max(natural, floor);
        }
        return SizedBox(
          width: width,
          height: height,
          child: _face(),
        );
      },
    );
  }

  Widget _face() {
    final borderColor = widget.showBorder ? widget.border : null;
    final child = DecoratedBox(
      decoration: widget.hexagon
          ? const BoxDecoration()
          : BoxDecoration(
              color: widget.fill,
              shape: widget.diameter == null
                  ? BoxShape.rectangle
                  : BoxShape.circle,
              borderRadius:
                  widget.diameter == null ? BorderRadius.circular(10) : null,
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor, width: widget.strokeWidth),
              boxShadow: widget.diameter != null && !widget.showLabel
                  ? [
                      BoxShadow(
                        color: WatchPalette.turquoise.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
      child: CustomPaint(
        painter: widget.hexagon
            ? _HexagonPainter(
                fill: widget.fill,
                stroke: borderColor ?? WatchPalette.steel,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: widget.inline ? _inlineBody() : _stackedBody(),
          ),
        ),
      ),
    );
    final control = Listener(
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
    final semantics = widget.semanticsLabel;
    if (semantics == null) return control;
    return Semantics(
      label: semantics,
      button: widget.onCommit != null,
      enabled: widget.onCommit != null,
      child: control,
    );
  }
}

class _CaptureCenterDot extends StatelessWidget {
  const _CaptureCenterDot();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(
        key: Key('watch-capture-center'),
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: WatchPalette.turquoise,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _CaptureGuidePainter extends CustomPainter {
  const _CaptureGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WatchPalette.steel.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    const dashes = 28;
    const sweep = math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * (math.pi * 2 / dashes),
        sweep,
        false,
        paint,
      );
    }
    final gap = 7.0;
    final arm = 16.0;
    canvas.drawLine(
      Offset(center.dx - gap - arm, center.dy),
      Offset(center.dx - gap, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + gap + arm, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - gap - arm),
      Offset(center.dx, center.dy - gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + gap + arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CaptureGuidePainter oldDelegate) => false;
}

class _HexagonPainter extends CustomPainter {
  const _HexagonPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final path = watchHexagon(size);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.save();
    const scale = 0.84;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawPath(
      watchHexagon(size),
      Paint()
        ..color = WatchPalette.turquoise.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 / scale,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.stroke != stroke;
  }
}
