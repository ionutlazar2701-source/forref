import 'package:flutter/material.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/match/client_ids.dart';
import 'package:referee_phone/match/match_session.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_competition_format_choice.dart';
import 'package:referee_phone/routing/app_router.dart';

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

  @override
  void initState() {
    super.initState();
    _home = TextEditingController();
    _away = TextEditingController();
    _competition = TextEditingController();
    _venue = TextEditingController();
    _half = TextEditingController(text: '45');
    _referee = TextEditingController();
    _ar1 = TextEditingController();
    _ar2 = TextEditingController();
    _fourth = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final match =
        await AppScope.of(context).database.getMatch(widget.matchId);
    if (!mounted || match == null) return;
    _session?.dispose();
    _home.text = match.teams.home.name ?? '';
    _away.text = match.teams.away.name ?? '';
    _competition.text = match.competition ?? '';
    _venue.text = match.venue ?? '';
    _half.text = '${match.settings.halfDurationSeconds ~/ 60}';
    _referee.text = match.crew.referee?.name ?? '';
    _ar1.text = match.crew.assistant1?.name ?? '';
    _ar2.text = match.crew.assistant2?.name ?? '';
    _fourth.text = match.crew.fourthOfficial?.name ?? '';
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

  Future<void> _persistSetup() async {
    final session = _session;
    if (session == null) return;
    final minutes = int.tryParse(_half.text.trim()) ?? 45;
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
          halfDurationSeconds: minutes * 60,
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

  CrewMember? _member(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return CrewMember(name: trimmed);
  }

  Future<void> _goLive() async {
    await _persistSetup();
    final session = _session;
    if (session == null || !mounted) return;
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final foundation = scope.matchFoundation;
    final matchCapture = scope.matchCaptureContext;
    if (foundation != null && matchCapture != null) {
      final captureContext =
          await matchCapture.captureContextFor(widget.matchId);
      await foundation.registerRosterFromMatch(
        context: captureContext,
        match: session.match,
      );
    }
    if (session.match.status == MatchStatus.setup) {
      await session.goReady();
    }
    if (!mounted) return;
    await navigator.pushNamedAndRemoveUntil(
      AppRouter.liveMatch,
      (route) =>
          route.settings.name == AppRouter.matches || route.isFirst,
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final match = session.match;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _home,
            decoration: InputDecoration(labelText: l10n.homeTeam),
          ),
          TextField(
            controller: _away,
            decoration: InputDecoration(labelText: l10n.awayTeam),
          ),
          TextField(
            controller: _competition,
            decoration: InputDecoration(labelText: l10n.competition),
          ),
          TextField(
            controller: _venue,
            decoration: InputDecoration(labelText: l10n.venue),
          ),
          TextField(
            controller: _half,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.halfLength),
          ),
          const SizedBox(height: 16),
          Text(l10n.competitionFormatTitle),
          ListTile(
            title: Text(l10n.competitionFormatNoExtraTime),
            trailing:
                _formatChoice ==
                    PhoneCompetitionFormatChoice.noAdditionalPlayingPeriods
                ? const Icon(Icons.check)
                : null,
            onTap: () async {
              setState(
                () => _formatChoice =
                    PhoneCompetitionFormatChoice.noAdditionalPlayingPeriods,
              );
              await _persistCompetitionRules();
            },
          ),
          ListTile(
            title: Text(l10n.competitionFormatExtraTimeMayApply),
            trailing:
                _formatChoice ==
                    PhoneCompetitionFormatChoice.additionalPlayingPhaseMayApply
                ? const Icon(Icons.check)
                : null,
            onTap: () async {
              setState(
                () => _formatChoice =
                    PhoneCompetitionFormatChoice.additionalPlayingPhaseMayApply,
              );
              await _persistCompetitionRules();
            },
          ),
          CheckboxListTile(
            title: Text(l10n.penaltyShootOutAfterMatchEnd),
            value: _penaltyShootOutAfterMatchEnd,
            onChanged: (value) async {
              setState(() => _penaltyShootOutAfterMatchEnd = value ?? false);
              await _persistCompetitionRules();
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          TextField(
            controller: _referee,
            decoration: InputDecoration(labelText: l10n.crewReferee),
          ),
          TextField(
            controller: _ar1,
            decoration: InputDecoration(labelText: l10n.crewAr1),
          ),
          TextField(
            controller: _ar2,
            decoration: InputDecoration(labelText: l10n.crewAr2),
          ),
          TextField(
            controller: _fourth,
            decoration: InputDecoration(labelText: l10n.crewFourth),
          ),
          const SizedBox(height: 16),
          Text(l10n.squadHome),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _goLive,
            child: Text(l10n.liveMatch),
          ),
        ),
      ),
    );
  }
}
