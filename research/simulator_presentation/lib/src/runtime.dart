import 'intent.dart';
import 'state.dart';

/// Presentation runtime boundary.
///
/// Implementations may talk to a research instrument or, later, to an
/// integration sandbox. They do not expose Match Memory writes here.
abstract interface class SimulatorPresentationRuntime {
  WatchPresentationState get watchState;

  Stream<WatchPresentationState> get watchStates;

  List<IntentTraceEntry> get intentTrace;

  Future<void> dispatch(WatchIntent intent);
}
