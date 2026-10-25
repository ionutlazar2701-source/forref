import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_competition_format_choice.dart';
import 'package:referee_phone/design/forref_components.dart';
import 'package:referee_phone/design/forref_spacing.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/preparation_labels.dart';
import 'package:referee_phone/match/client_ids.dart';
import 'package:referee_phone/match/match_session.dart';
import 'package:referee_phone/officiate/fixture_list.dart';
import 'package:referee_phone/officiate/preparation_assessment.dart';
import 'package:referee_phone/routing/app_router.dart';
import 'package:referee_phone/training/training_match_gate.dart';
import 'package:referee_phone/training/training_session.dart';
import 'package:referee_phone/training/training_store.dart';

/// One Preparation workspace for a single match.
///
/// Setup fields stay on the existing match aggregate. They are not Match
/// Memory. Entering Live Match still uses [MatchSession.goReady] and does
/// not write a sporting record.
class MatchSetupPage extends StatefulWidget {
  const MatchSetupPage({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchSetupPage> createState() => _MatchSetupPageState();
}

class _MatchSetupPageState extends State<MatchSetupPage> {
  MatchSession? _session;
  late final TextEditingController _home;
  late final TextEditingController _away;
  late final TextEditingController _competition;
  late final TextEditingController _venue;
  late final TextEditingController _half;
  late final TextEditingController _referee;
  late final TextEditingController _ar1;
  late final TextEditingController _ar2;
  late final TextEditingController _fourth;
  PhoneCompetitionFormatChoice _formatChoice =
      PhoneCompetitionFormatChoice.additionalPlayingPhaseMayApply;
  bool _penaltyShootOutAfterMatchEnd = false;
  bool _hydrating = false;
  bool _closed = false;
  Future<void> _persistChain = Future<void>.value();
  String? _trainingDenial;

  @override
  void initState() {
    super.initState();
    _home = TextEditingController()..addListener(_onDraftChanged);
    _away = TextEditingController()..addListener(_onDraftChanged);
    _competition = TextEditingController()..addListener(_onDraftChanged);
    _venue = TextEditingController()..addListener(_onDraftChanged);
    _half = TextEditingController(text: '45')..addListener(_onDraftChanged);
    _referee = TextEditingController()..addListener(_onDraftChanged);
    _ar1 = TextEditingController()..addListener(_onDraftChanged);
    _ar2 = TextEditingController()..addListener(_onDraftChanged);
    _fourth = TextEditingController()..addListener(_onDraftChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onDraftChanged() {
    if (_hydrating || _closed || !mounted || _session == null) return;
    setState(() {});
    _persistChain = _persistChain.then((_) => _persistSetup());
  }

  Future<void> _load() async {
    final match = await AppScope.of(context).database.getMatch(widget.matchId);
    if (!mounted || match == null) return;
    _session?.dispose();
    _hydrating = true;
    _home.text = match.teams.home.name ?? '';
    _away.text = match.teams.away.name ?? '';
    _competition.text = match.competition ?? '';
    _venue.text = match.venue ?? '';
    _half.text = '${match.settings.halfDurationSeconds ~/ 60}';
    _referee.text = match.crew.referee?.name ?? '';
    _ar1.text = match.crew.assistant1?.name ?? '';
    _ar2.text = match.crew.assistant2?.name ?? '';
    _fourth.text = match.crew.fourthOfficial?.name ?? '';
    _hydrating = false;
    setState(() {
      _session = MatchSession(
        database: AppScope.of(context).database,
        match: match,
      );
    });
    final rulesStore = AppScope.of(context).matchCaptureContext?.rulesStore;
    if (rulesStore != null) {
      await rulesStore.ensureForMatch(widget.matchId);
      final rules = await rulesStore.loadForMatch(widget.matchId);
      if (!mounted) return;
      setState(() {
        _formatChoice = PhoneCompetitionFormatChoiceMapping.fromRules(rules);
        _penaltyShootOutAfterMatchEnd = rules.penaltyShootOutAfterMatchEnd;
      });
    }
  }

  @override
  void dispose() {
    _closed = true;
    _home.dispose();
    _away.dispose();
    _competition.dispose();
    _venue.dispose();
    _half.dispose();
    _referee.dispose();
    _ar1.dispose();
    _ar2.dispose();
    _fourth.dispose();
    _session?.dispose();
    super.dispose();
  }

  PreparationAssessment _assessment() {
    final commands = AppScope.of(context).mobileCommands;
    return assessPreparation(
      homeName: _home.text,
      awayName: _away.text,
      halfMinutes: int.tryParse(_half.text.trim()),
      localStorageReady: commands.localStorageReady,
      authorityKnown: commands.authorityKnown,
      temporalEvidenceReady: commands.temporalEvidenceReady,
    );
  }

  Future<void> _persistSetup() async {
    final session = _session;
    if (_closed || session == null || !mounted) return;
    final minutes = int.tryParse(_half.text.trim());
    final halfSeconds = minutes != null && minutes > 0 ? minutes * 60 : 0;
    await session.replace(
      session.match.copyWith(
        updatedAt: DateTime.now().toUtc(),
        teams: Teams(
          home: session.match.teams.home.copyWith(
            name: _home.text.trim(),
            clearName: _home.text.trim().isEmpty,
          ),
          away: session.match.teams.away.copyWith(
            name: _away.text.trim(),
            clearName: _away.text.trim().isEmpty,
          ),
        ),
        competition: _competition.text.trim(),
        clearCompetition: _competition.text.trim().isEmpty,
        venue: _venue.text.trim(),
        clearVenue: _venue.text.trim().isEmpty,
        settings: session.match.settings.copyWith(
          halfDurationSeconds: halfSeconds,
        ),
        crew: Crew(
          referee: _member(_referee.text),
          assistant1: _member(_ar1.text),
          assistant2: _member(_ar2.text),
          fourthOfficial: _member(_fourth.text),
        ),
      ),
    );
  }

  Future<void> _persistCompetitionRules() async {
    final rulesStore = AppScope.of(context).matchCaptureContext?.rulesStore;
    if (rulesStore == null) return;
    await rulesStore.saveForMatch(
      widget.matchId,
      _formatChoice.toRulesContext(
        penaltyShootOutAfterMatchEnd: _penaltyShootOutAfterMatchEnd,
      ),
    );
  }

  String _warmUpDenial(AppLocalizations l10n, TrainingStartDenial denial) {
    return switch (denial) {
      TrainingStartDenial.anotherSessionOpen => l10n.trainingBlockedAnother,
      TrainingStartDenial.matchInProgress => l10n.trainingBlockedMatchOpen,
      TrainingStartDenial.matchStateUnverified =>
        l10n.trainingBlockedMatchUnverified,
      TrainingStartDenial.ledgerUnreadable => l10n.trainingUnavailable,
    };
  }

  CrewMember? _member(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return CrewMember(name: trimmed);
  }

  Future<void> _startWarmUp() async {
    final scope = AppScope.of(context);
    final store = scope.training;
    final l10n = AppLocalizations.of(context);
    if (store == null) {
      setState(() => _trainingDenial = l10n.trainingUnavailable);
      return;
    }
    final ledger = await store.load();
    final match = _session?.match;
    final inProgress = match != null &&
        (match.status == MatchStatus.live ||
            match.status == MatchStatus.paused ||
            match.status == MatchStatus.halfTime);
    final denial = ledger.unreadable
        ? TrainingStartDenial.ledgerUnreadable
        : await trainingMatchDenial(
            database: scope.database,
            boundary: scope.matchApplication,
            today: DateTime.now(),
            anotherSessionOpen: ledger.openSession != null &&
                ledger.warmUpFor(widget.matchId) == null,
          );
    final blocked =
        denial ?? (inProgress ? TrainingStartDenial.matchInProgress : null);
    if (!mounted) return;
    if (blocked != null && ledger.warmUpFor(widget.matchId) == null) {
      setState(() => _trainingDenial = _warmUpDenial(l10n, blocked));
      return;
    }
    final result = await store.startWarmUp(matchId: widget.matchId);
    if (!mounted) return;
    switch (result) {
      case TrainingStarted(:final session):
      case TrainingAlreadyPresent(:final session):
        setState(() => _trainingDenial = null);
        await Navigator.of(context).pushNamed(
          AppRouter.trainingSession,
          arguments: session.id,
        );
      case TrainingStartBlocked(:final denial):
        setState(() => _trainingDenial = _warmUpDenial(l10n, denial));
    }
  }

  Future<void> _goLive() async {
    final assessment = _assessment();
    if (!assessment.canEnterLiveMatch) return;
    await _persistSetup();
    final session = _session;
    if (session == null) return;
    if (session.match.status == MatchStatus.setup) {
      await session.goReady();
    }
    if (!mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.liveMatch,
      (route) => route.settings.name == AppRouter.matches || route.isFirst,
      arguments: widget.matchId,
    );
  }

  Future<void> _addPlayer({required bool home}) async {
    final l10n = AppLocalizations.of(context);
    final number = TextEditingController();
    final name = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addPlayer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: number,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.playerNumber),
              ),
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.playerName),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.back),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.addPlayer),
            ),
          ],
        );
      },
    );
    if (added != true || _session == null) return;
    final shirt = int.tryParse(number.text.trim());
    final player = Player(
      playerId: clientId(),
      shirtNumber: shirt,
      name: name.text.trim().isEmpty ? null : name.text.trim(),
    );
    final match = _session!.match;
    final squads = home
        ? Squads(
            home: TeamSquad(players: [...match.squads.home.players, player]),
            away: match.squads.away,
          )
        : Squads(
            home: match.squads.home,
            away: TeamSquad(players: [...match.squads.away.players, player]),
          );
    await _session!.replace(match.copyWith(squads: squads));
    number.dispose();
    name.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    if (session == null) {
      return const Scaffold(
        key: Key('preparation-page'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final match = session.match;
    final assessment = _assessment();
    final identity = fixtureTitle(
      match.copyWith(
        teams: Teams(
          home: match.teams.home.copyWith(
            name: _home.text.trim(),
            clearName: _home.text.trim().isEmpty,
          ),
          away: match.teams.away.copyWith(
            name: _away.text.trim(),
            clearName: _away.text.trim().isEmpty,
          ),
        ),
      ),
      homeNotSet: l10n.homeTeamNotSet,
      awayNotSet: l10n.awayTeamNotSet,
    );
    final competition = _competition.text.trim();
    final readinessTone = switch (assessment.claim) {
      PreparationClaim.needsAttention => ForrefNoticeTone.attention,
      PreparationClaim.recordingAuthorityUnconfirmed =>
        ForrefNoticeTone.unavailable,
      PreparationClaim.matchSetupReady ||
      PreparationClaim.readyToOfficiateOnThisPhone =>
        ForrefNoticeTone.neutral,
    };
    return Scaffold(
      key: const Key('preparation-page'),
      appBar: AppBar(title: Text(l10n.preparationTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          ForrefSpace.s20,
          ForrefSpace.s16,
          ForrefSpace.s20,
          ForrefSpace.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ForrefFixtureIdentity(
              title: identity,
              detail: [
                match.date,
                if (competition.isNotEmpty) competition,
              ].join(' · '),
              large: true,
            ),
            _section(
              context,
              key: const Key('section-match'),
              title: l10n.sectionMatch,
              children: [
                TextField(
                  controller: _competition,
                  decoration: InputDecoration(
                    labelText: l10n.competition,
                    helperText: l10n.fieldOptional,
                  ),
                ),
                TextField(
                  controller: _venue,
                  decoration: InputDecoration(
                    labelText: l10n.venue,
                    helperText: l10n.fieldOptional,
                  ),
                ),
                TextField(
                  key: const Key('half-length'),
                  controller: _half,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.halfLength,
                    helperText: l10n.fieldRequired,
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.competitionFormatTitle),
                ListTile(
                  title: Text(l10n.competitionFormatNoExtraTime),
                  trailing: _formatChoice ==
                          PhoneCompetitionFormatChoice
                              .noAdditionalPlayingPeriods
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    setState(
                      () => _formatChoice = PhoneCompetitionFormatChoice
                          .noAdditionalPlayingPeriods,
                    );
                    await _persistCompetitionRules();
                  },
                ),
                ListTile(
                  title: Text(l10n.competitionFormatExtraTimeMayApply),
                  trailing: _formatChoice ==
                          PhoneCompetitionFormatChoice
                              .additionalPlayingPhaseMayApply
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    setState(
                      () => _formatChoice = PhoneCompetitionFormatChoice
                          .additionalPlayingPhaseMayApply,
                    );
                    await _persistCompetitionRules();
                  },
                ),
                CheckboxListTile(
                  title: Text(l10n.penaltyShootOutAfterMatchEnd),
                  value: _penaltyShootOutAfterMatchEnd,
                  onChanged: (value) async {
                    setState(
                      () => _penaltyShootOutAfterMatchEnd = value ?? false,
                    );
                    await _persistCompetitionRules();
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
            _section(
              context,
              key: const Key('section-teams'),
              title: l10n.sectionTeams,
              children: [
                TextField(
                  key: const Key('home-team'),
                  controller: _home,
                  decoration: InputDecoration(
                    labelText: l10n.homeTeam,
                    helperText: l10n.fieldRequired,
                  ),
                ),
                TextField(
                  key: const Key('away-team'),
                  controller: _away,
                  decoration: InputDecoration(
                    labelText: l10n.awayTeam,
                    helperText: l10n.fieldRequired,
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.squadHome),
                Text(l10n.fieldOptional),
                for (final player in match.squads.home.players)
                  Text('#${player.shirtNumber ?? '—'} ${player.name ?? ''}'),
                TextButton(
                  onPressed: () => _addPlayer(home: true),
                  child: Text(l10n.addPlayer),
                ),
                Text(l10n.squadAway),
                for (final player in match.squads.away.players)
                  Text('#${player.shirtNumber ?? '—'} ${player.name ?? ''}'),
                TextButton(
                  onPressed: () => _addPlayer(home: false),
                  child: Text(l10n.addPlayer),
                ),
              ],
            ),
            _section(
              context,
              key: const Key('section-crew'),
              title: l10n.sectionCrew,
              children: [
                TextField(
                  controller: _referee,
                  decoration: InputDecoration(
                    labelText: l10n.crewReferee,
                    helperText: l10n.fieldOptional,
                  ),
                ),
                TextField(
                  controller: _ar1,
                  decoration: InputDecoration(
                    labelText: l10n.crewAr1,
                    helperText: l10n.fieldOptional,
                  ),
                ),
                TextField(
                  controller: _ar2,
                  decoration: InputDecoration(
                    labelText: l10n.crewAr2,
                    helperText: l10n.fieldOptional,
                  ),
                ),
                TextField(
                  controller: _fourth,
                  decoration: InputDecoration(
                    labelText: l10n.crewFourth,
                    helperText: l10n.fieldOptional,
                  ),
                ),
              ],
            ),
            _section(
              context,
              key: const Key('section-readiness'),
              title: l10n.sectionReadiness,
              children: [
                ForrefNotice(
                  title: preparationClaimLabel(l10n, assessment.claim),
                  titleKey: const Key('readiness-claim'),
                  tone: readinessTone,
                  lines: [
                    for (final blocker in assessment.blockers)
                      preparationBlockerLabel(l10n, blocker),
                    l10n.optionalDetailsDoNotBlock,
                  ],
                ),
                TextButton(
                  key: const Key('training-warm-up'),
                  onPressed: _startWarmUp,
                  child: Text(l10n.trainingWarmUpAction),
                ),
                if (_trainingDenial != null)
                  ForrefNotice(
                    title: _trainingDenial!,
                    titleKey: const Key('training-warm-up-denial'),
                    tone: ForrefNoticeTone.attention,
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: ForrefBottomAction(
        buttonKey: const Key('enter-live-match'),
        label: l10n.enterLiveMatch,
        onPressed: assessment.canEnterLiveMatch ? _goLive : null,
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required Key key,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ForrefSpace.s24),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: ForrefSpace.s8),
        const Divider(height: 1),
        const SizedBox(height: ForrefSpace.s16),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: ForrefSpace.s12),
          children[i],
        ],
      ],
    );
  }
}
