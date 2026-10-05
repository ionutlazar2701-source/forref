import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/features/live_match/live_match_terminal_ui.dart';
import 'package:test/test.dart';

void main() {
  test('End match action is shown only when eligibility is eligible', () {
    expect(
      showEndMatchAction(
        eligibility: NormalMatchEndEligibility.eligible,
        matchNormallyEnded: false,
        matchEndPending: false,
      ),
      isTrue,
    );
    expect(
      showEndMatchAction(
        eligibility: NormalMatchEndEligibility.blockedPhaseDispositionUnresolved,
        matchNormallyEnded: false,
        matchEndPending: false,
      ),
      isFalse,
    );
    expect(
      showEndMatchAction(
        eligibility: NormalMatchEndEligibility.eligible,
        matchNormallyEnded: true,
        matchEndPending: false,
      ),
      isFalse,
    );
    expect(
      showEndMatchAction(
        eligibility: NormalMatchEndEligibility.eligible,
        matchNormallyEnded: false,
        matchEndPending: true,
      ),
      isTrue,
    );
  });

  test('blocked reasons are shown for non-eligible terminal states', () {
    expect(
      showTerminalBlockedReason(
        eligibility: NormalMatchEndEligibility.blockedActivePeriod,
        matchNormallyEnded: false,
        matchStarted: true,
      ),
      isTrue,
    );
    expect(
      showTerminalBlockedReason(
        eligibility: NormalMatchEndEligibility.eligible,
        matchNormallyEnded: false,
        matchStarted: true,
      ),
      isFalse,
    );
    expect(
      showTerminalBlockedReason(
        eligibility: NormalMatchEndEligibility.blockedAlreadyEnded,
        matchNormallyEnded: true,
        matchStarted: true,
      ),
      isFalse,
    );
  });
}
