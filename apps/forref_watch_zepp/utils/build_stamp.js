// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
export const BUILD_NAME = "native-familiarity-v5";
export const BUILD_REV = "75f6757b361962290156ff2f415994c223a52617";

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + "!";
}
