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
  return data;
}
