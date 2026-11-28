// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
// Device App and Side Service both import this module, so one package has one id.
export const BUILD_NAME = "com-004r-parity";
export const BUILD_REV = "f6efb1680837a4b2a09ac7c002c99ef9dc2300c4";
export const BUILD_VERSION = "1.0.28";
export const BUILD_CODE = 28;

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE + "!";
}

export function deviceBuildLine() {
  return "FORREF_PROVISION tx=device-build build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE;
}

export function sideBuildLine() {
  return "FORREF_PROVISION tx=side-build build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE;
}
