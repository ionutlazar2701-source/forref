// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
export const BUILD_NAME = "com-001-ui-hotfix";
export const BUILD_REV = "7d8a8fc623307ef7f0d26f141ca9ffa34ec14fe3";

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + "!";
}
