function bag() {
  const app = getApp();
  if (app.globalData) {
    return app.globalData;
  }
  if (app._options && app._options.globalData) {
    return app._options.globalData;
  }
  app.globalData = {};
  return app.globalData;
}

export function state() {
  const data = bag();
  if (!data.display) {
    data.display = "A";
    data.team = "";
    data.event = "";
    data.player = "";
    data.tossWinner = "";
    data.tossChoice = "";
    data.localeTest = "";
  }
  if (data.localeTest == null) {
    data.localeTest = "";
  }
  if (data.captureFixture == null) {
    data.captureFixture = false;
  }
  if (data.captureIntentId == null) {
    data.captureIntentId = "";
  }
  if (data.captureIntentKey == null) {
    data.captureIntentKey = "";
  }
  if (data.captureView == null) {
    data.captureView = false;
  }
  if (data.captureNote == null) {
    data.captureNote = "";
  }
  if (data.captureRecoveryLogged == null) {
    data.captureRecoveryLogged = false;
  }
  if (data.captureQuarantineLogged == null) {
    data.captureQuarantineLogged = false;
  }
  return data;
}
