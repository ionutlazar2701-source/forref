// Identity logged at boot so a simulator trace can be matched to a commit.
// BUILD_REV is the functional commit. The evidence commit may follow it.
// Device App and Side Service both import this module, so one package has one id.
export const BUILD_NAME = "com-004r-identity";
export const BUILD_REV = "f7d23e0fc3dde787f0c265b0589ee022f9ec12da";
export const BUILD_VERSION = "1.0.29";
export const BUILD_CODE = 29;

export function bootLine() {
  return "FORREF_LIVE002_BOOT build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE + "!";
}

export function deviceBuildLine() {
  return "FORREF_PROVISION tx=device-build build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE;
}

export function sideBuildLine() {
  return "FORREF_PROVISION tx=side-build build=" + BUILD_NAME + " rev=" + BUILD_REV + " version=" + BUILD_VERSION + " code=" + BUILD_CODE;
}
