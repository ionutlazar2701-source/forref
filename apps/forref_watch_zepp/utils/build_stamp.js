// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
export const BUILD_NAME = "true-black-004";
export const BUILD_REV = "5b68fa59d7540e1bc1e043fb32233f5a1f79e7d5";

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + "!";
}
