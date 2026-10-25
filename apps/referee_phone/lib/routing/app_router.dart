import 'package:flutter/material.dart';

import '../features/live_match/live_match_page.dart';
import '../features/match_setup/match_setup_page.dart';
import '../features/match_summary/match_summary_page.dart';
import '../features/matches/matches_page.dart';
import '../features/settings/settings_page.dart';
import '../features/training/training_list_page.dart';
import '../features/training/training_session_page.dart';

abstract final class AppRouter {
  static const matches = '/';
  static const matchSetup = '/setup';
  static const liveMatch = '/live';
  static const matchSummary = '/summary';
  static const settingsPath = '/settings';
  static const training = '/training';
  static const trainingSession = '/training/session';

  static Route<void>? onGenerateRoute(RouteSettings routeSettings) {
    final argument = routeSettings.arguments as String?;
    final Widget page = switch (routeSettings.name) {
      matches => const MatchesPage(),
      matchSetup when argument != null => MatchSetupPage(matchId: argument),
      liveMatch when argument != null => LiveMatchPage(matchId: argument),
      matchSummary when argument != null => MatchSummaryPage(matchId: argument),
      training => const TrainingListPage(),
      trainingSession when argument != null =>
        TrainingSessionPage(sessionId: argument),
      settingsPath => const SettingsPage(),
      _ => const MatchesPage(),
    };
    return _ForrefRoute<void>(
      settings: routeSettings,
      builder: (context) => page,
    );
  }
}

class _ForrefRoute<T> extends MaterialPageRoute<T> {
  _ForrefRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);
}
