// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
export const BUILD_NAME = "live-match-flow-002";
export const BUILD_REV = "UNSTAMPED";

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + "!";
}
