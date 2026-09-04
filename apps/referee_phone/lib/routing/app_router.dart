import 'package:flutter/material.dart';

import '../features/live_match/live_match_page.dart';
import '../features/match_setup/match_setup_page.dart';
import '../features/match_summary/match_summary_page.dart';
import '../features/matches/matches_page.dart';
import '../features/settings/settings_page.dart';

abstract final class AppRouter {
  static const matches = '/';
  static const matchSetup = '/setup';
  static const liveMatch = '/live';
  static const matchSummary = '/summary';
  static const settingsPath = '/settings';

  static Route<void>? onGenerateRoute(RouteSettings routeSettings) {
    final matchId = routeSettings.arguments as String?;
    final Widget page = switch (routeSettings.name) {
      matches => const MatchesPage(),
      matchSetup when matchId != null => MatchSetupPage(matchId: matchId),
      liveMatch when matchId != null => LiveMatchPage(matchId: matchId),
      matchSummary when matchId != null => MatchSummaryPage(matchId: matchId),
      settingsPath => const SettingsPage(),
      _ => const MatchesPage(),
    };
    return MaterialPageRoute<void>(
      settings: routeSettings,
      builder: (context) => page,
    );
  }
}
