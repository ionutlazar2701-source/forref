/// Pure Dart match engine.
///
/// Must not import `package:flutter/...` or `package:firebase_...`.
/// Canonical schema: `docs/data-model.md`.
library;

export 'clock/match_clock.dart';
export 'clock/match_lifecycle.dart';
export 'enums/enums.dart';
export 'events/event_factory.dart';
export 'events/event_reducer.dart';
export 'events/event_validator.dart';
export 'history/history_builder.dart';
export 'models/crew.dart';
export 'models/event.dart';
export 'models/history_entry.dart';
export 'models/match.dart';
export 'models/match_state.dart';
export 'models/period.dart';
export 'models/player.dart';
export 'models/team.dart';
export 'scoring/score_calculator.dart';
export 'serialization/match_json.dart';
