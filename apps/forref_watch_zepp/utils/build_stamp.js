// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
export const BUILD_NAME = "clock-p0-recovery";
export const BUILD_REV = "ae4572d2b2434ffd03eeaa76922eb721edc2f97b";

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + "!";
}
