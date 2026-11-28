import { readFileSync } from "@zos/fs";
import { back } from "@zos/router";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { readDurableText } from "../../../utils/installation_continuity";
import { MATCH_REGISTRY_FILE, readMatchRegistry } from "../../../utils/match_registry";
import { t } from "../../../utils/text";
import { TEXT_WARNING } from "../../../utils/theme";

function registryStore() {
  return {
    read() {
      return readDurableText({ readFileSync: readFileSync }, MATCH_REGISTRY_FILE);
    },
  };
}

function minutesOf(entry) {
  return Math.round((entry.halfDurationMs || 0) / 60000);
}

Page({
  onInit() {
    this._matchId = "";
  },
  build() {
    this._metrics = logDevice("select");
    bindBack(false);
    this.paint();
  },
  paint() {
    clear();
    const loaded = readMatchRegistry(registryStore());
    const matches = loaded.ok ? loaded.matches : [];
    const selected = this._matchId
      ? matches.filter((entry) => entry.matchId === this._matchId)[0]
      : null;
    if (selected) {
      const minutes = minutesOf(selected);
      stack(this._metrics, selected.homeName, [
        { label: selected.awayName },
        { label: minutes + " + " + minutes },
        { label: t("configVerified"), color: TEXT_WARNING },
        { label: t("matchList"), action: () => this.showList() },
      ]);
      return;
    }
    const rows = [{ label: t("configVerified"), color: TEXT_WARNING }];
    if (!loaded.ok) rows.push({ label: t("matchesKept"), color: TEXT_WARNING });
    else if (!matches.length) rows.push({ label: t("noVerifiedMatch") });
    for (let i = 0; i < matches.length; i += 1) {
      const entry = matches[i];
      rows.push({
        label: entry.homeName + "  ·  " + entry.awayName,
        name: "select-match-" + i,
        action: () => this.openMatch(entry.matchId),
      });
    }
    rows.push({ label: t("back"), action: () => back() });
    stack(this._metrics, t("availableMatches"), rows);
  },
  openMatch(matchId) {
    this._matchId = matchId;
    this.paint();
  },
  showList() {
    this._matchId = "";
    this.paint();
  },
});
