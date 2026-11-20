// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
export const BUILD_NAME = "clock-sleep-004";
export const BUILD_REV = "5e31b2402f1fda1e7a171b8628ebff2248089b29";

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + "!";
}
