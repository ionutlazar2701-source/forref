// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
// Device App and Side Service both import this module, so one package has one id.
export const BUILD_NAME = "identity-detect-031";
export const BUILD_REV = "b4cde9ed17a6ef0ee304265164a146474b7802e9";
export const BUILD_VERSION = "1.0.31";
export const BUILD_CODE = 31;

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE + "!";
}

export function deviceBuildLine() {
  return "FORREF_PROVISION tx=device-build build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE;
}

export function sideBuildLine() {
  return "FORREF_PROVISION tx=side-build build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE;
}
