import { createWatchProvisionAdmission, parseWatchProvisionV1 } from "./watch_provision.js";
import { GOAL_CONTEXT_FILE } from "./local_test_score.js";

export const GET_WATCH_PROVISION_V1 = "GET_WATCH_PROVISION_V1";
export const WATCH_PROVISION_VERIFIED_V1 = "WATCH_PROVISION_VERIFIED_V1";
export const ACTIVATE_WATCH_V1 = "ACTIVATE_WATCH_V1";
export const WATCH_ACTIVATED_V1 = "WATCH_ACTIVATED_V1";

function refused(reason) {
  console.log("FORREF_PROVISION outcome=REFUSED reason=" + reason);
  return { type: "REFUSED", reason: reason };
}

export function handleProvisionMessage(message, admission, installationId, contextStore) {
  if (!message || !message.type || !message.matchId || !message.contentHash) {
    return refused("message");
  }
  if (message.type === GET_WATCH_PROVISION_V1) {
    const received = admission.receive(message.canonical || "", installationId, false);
    if (received.state !== "WATCH_CONFIG_VERIFIED" || received.contentHash !== message.contentHash) {
      return refused(received.reason || received.state);
    }
    const document = parseWatchProvisionV1(received.canonical).document;
    if (!document || document.matchId !== message.matchId) return refused("matchId");
    console.log("FORREF_PROVISION outcome=WATCH_PROVISION_VERIFIED_V1 reason=");
    return {
      type: WATCH_PROVISION_VERIFIED_V1,
      matchId: document.matchId,
      contentHash: received.contentHash,
      writerDeviceId: installationId,
      generation: 1,
      readBack: true,
    };
  }
  if (message.type === ACTIVATE_WATCH_V1) {
    const stored = admission.loadDurable(installationId, false);
    if (stored.contentHash && stored.contentHash !== message.contentHash) {
      return refused("conflicting-activation");
    }
    if (message.matchId && stored.canonical) {
      const document = parseWatchProvisionV1(stored.canonical).document;
      if (!document || document.matchId !== message.matchId) return refused("matchId");
    }
    const activated = admission.activate(installationId, message.lockReceipt || null);
    if (activated.state !== "WATCH_ACTIVATED") {
      return refused(activated.reason || activated.state);
    }
    const document = parseWatchProvisionV1(activated.canonical).document;
    if (contextStore && document) {
      const body = JSON.stringify({
        matchId: document.matchId,
        principalId: document.principalId,
        writerDeviceId: document.writerDeviceId,
        homeTeamId: document.homeTeamId,
        awayTeamId: document.awayTeamId,
        authorityActivated: true,
      });
      const wrote = contextStore.write(body);
      const back = contextStore.read();
      if (!wrote || wrote.status !== "ok" || !back || back.text !== body) {
        return refused("context-readback");
      }
    }
    console.log("FORREF_PROVISION outcome=WATCH_ACTIVATED_V1 reason=");
    console.log("FORREF_D1 outcome=UNCERTIFIED reason=capture-storage-uncertified");
    return {
      type: WATCH_ACTIVATED_V1,
      matchId: document.matchId,
      contentHash: activated.contentHash,
      writerDeviceId: installationId,
      generation: 1,
      durable: true,
    };
  }
  return refused("type");
}

export function createFileProvisionStore(fs, rootPath, markerPath) {
  function readPath(path) {
    try {
      const text = fs.readFileSync({ path: path, options: { encoding: "utf8" } });
      if (text == null || text === "") return { status: "absent" };
      return { status: "ok", text: String(text) };
    } catch (err) {
      const name = String(err && err.message ? err.message : err);
      if (name.indexOf("ENOENT") >= 0 || name.indexOf("No such") >= 0 || name.indexOf("not found") >= 0) {
        return { status: "absent" };
      }
      return { status: "unverified" };
    }
  }
  function writePath(path, text) {
    try {
      fs.writeFileSync({ path: path, data: text, options: { encoding: "utf8" } });
    } catch (err) {
      return { status: "unverified" };
    }
    const back = readPath(path);
    if (back.status !== "ok" || back.text !== text) return { status: "unverified" };
    return { status: "ok", text: text };
  }
  return {
    readRoot() {
      return readPath(rootPath);
    },
    readAdmission() {
      return readPath(markerPath);
    },
    writeRoot(text) {
      return writePath(rootPath, text);
    },
    writeAdmission(text) {
      return writePath(markerPath, text);
    },
  };
}

export function createMemoryTextStore() {
  return {
    raw: null,
    failRead: false,
    read() {
      if (this.failRead) return { status: "unreadable" };
      if (this.raw == null || this.raw === "") return { status: "absent" };
      return { status: "ok", text: this.raw };
    },
    write(text) {
      this.raw = text;
      return { status: "ok", text: text };
    },
  };
}

export { createWatchProvisionAdmission, GOAL_CONTEXT_FILE };
