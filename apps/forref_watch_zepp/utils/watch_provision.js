import { sha256Hex } from "./sha256_hex.js";

export const WATCH_PROVISION_SCHEMA = "forref.watch-provision.v1";
export const WATCH_PROVISION_DISPLAY_PREPARED = "CONFIG PREPARED — AUTHORITY NOT LOCKED";
export const WATCH_PROVISION_DISPLAY_VERIFIED = "CONFIG VERIFIED — NOT ACTIVATED";
export const WATCH_PROVISION_DISPLAY_LOCKED = "PHONE AUTHORITY LOCKED — D1 UNCERTIFIED";
export const WATCH_PROVISION_DISPLAY_ACTIVATED = "WATCH ACTIVATED — D1 UNCERTIFIED";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function canonicalWatchProvisionV1(document) {
  return '{"schema":"' + WATCH_PROVISION_SCHEMA + '",' +
    '"matchId":' + JSON.stringify(document.matchId) + "," +
    '"authority":{"scope":"MAIN_REFEREE",' +
    '"principalId":' + JSON.stringify(document.principalId) + "," +
    '"generation":1,' +
    '"writerDeviceId":' + JSON.stringify(document.writerDeviceId) + "}," +
    '"teams":{"home":{"teamId":' + JSON.stringify(document.homeTeamId) + "," +
    '"name":' + JSON.stringify(document.homeName) + "}," +
    '"away":{"teamId":' + JSON.stringify(document.awayTeamId) + "," +
    '"name":' + JSON.stringify(document.awayName) + "}}," +
    '"clock":{"halfDurationMs":' + document.halfDurationMs + "}," +
    '"provisionVersion":' + document.provisionVersion + "}";
}

export function stageMarker(contentHash, state) {
  return "v=1\nhash=" + contentHash + "\nstate=" + state + "\n";
}

function idOk(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 128 && value === value.trim() && !/[\u0000-\u001f]/.test(value);
}

function teamOk(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  if (Object.keys(value).length !== 2 || !Object.prototype.hasOwnProperty.call(value, "teamId") || !Object.prototype.hasOwnProperty.call(value, "name")) {
    return null;
  }
  if (!idOk(value.teamId)) return null;
  const upper = value.teamId.toUpperCase();
  if (upper === "HOME" || upper === "AWAY") return null;
  if (typeof value.name !== "string" || value.name.length === 0 || value.name.length > 80 || value.name !== value.name.trim()) {
    return null;
  }
  return value;
}

export function parseWatchProvisionV1(raw) {
  let map;
  try {
    map = JSON.parse(raw);
  } catch (err) {
    return { document: null, reason: "schema" };
  }
  if (!map || typeof map !== "object" || Array.isArray(map)) {
    return { document: null, reason: "schema" };
  }
  const keys = Object.keys(map);
  const allowed = ["schema", "matchId", "authority", "teams", "clock", "provisionVersion"];
  if (keys.length !== allowed.length || allowed.some((key) => !Object.prototype.hasOwnProperty.call(map, key))) {
    return { document: null, reason: "schema" };
  }
  if (map.schema !== WATCH_PROVISION_SCHEMA) return { document: null, reason: "schema" };
  if (!idOk(map.matchId)) return { document: null, reason: "matchId" };
  const authority = map.authority;
  if (!authority || typeof authority !== "object" || Array.isArray(authority)) {
    return { document: null, reason: "authority" };
  }
  const authorityKeys = ["scope", "principalId", "generation", "writerDeviceId"];
  if (Object.keys(authority).length !== authorityKeys.length || authorityKeys.some((key) => !Object.prototype.hasOwnProperty.call(authority, key))) {
    return { document: null, reason: "authority" };
  }
  if (authority.scope !== "MAIN_REFEREE") return { document: null, reason: "scope" };
  if (authority.generation !== 1) return { document: null, reason: "generation" };
  if (!idOk(authority.principalId)) return { document: null, reason: "principalId" };
  if (typeof authority.writerDeviceId !== "string" || !UUID.test(authority.writerDeviceId)) {
    return { document: null, reason: "writerDeviceId" };
  }
  const teams = map.teams;
  if (!teams || typeof teams !== "object" || Array.isArray(teams) || Object.keys(teams).length !== 2 || !teams.home || !teams.away) {
    return { document: null, reason: "teams" };
  }
  const home = teamOk(teams.home);
  const away = teamOk(teams.away);
  if (!home || !away || home.teamId === away.teamId) return { document: null, reason: "teamId" };
  const clock = map.clock;
  if (!clock || typeof clock !== "object" || Array.isArray(clock) || Object.keys(clock).length !== 1 || !Object.prototype.hasOwnProperty.call(clock, "halfDurationMs")) {
    return { document: null, reason: "clock" };
  }
  const half = clock.halfDurationMs;
  if (typeof half !== "number" || !Number.isInteger(half) || half <= 0 || half > 0x1fffffffffffff) {
    return { document: null, reason: "halfDurationMs" };
  }
  if (map.provisionVersion !== 1) return { document: null, reason: "provisionVersion" };
  const document = {
    matchId: map.matchId,
    principalId: authority.principalId,
    writerDeviceId: authority.writerDeviceId,
    homeTeamId: home.teamId,
    homeName: home.name,
    awayTeamId: away.teamId,
    awayName: away.name,
    halfDurationMs: half,
    provisionVersion: 1,
  };
  if (canonicalWatchProvisionV1(document) !== String(raw).trim()) {
    return { document: null, reason: "canonical" };
  }
  document.canonical = canonicalWatchProvisionV1(document);
  document.contentHash = sha256Hex(document.canonical);
  return { document: document, reason: "" };
}

function displayFor(state) {
  if (state === "CONFIG_PREPARED") return WATCH_PROVISION_DISPLAY_PREPARED;
  if (state === "WATCH_CONFIG_VERIFIED") return WATCH_PROVISION_DISPLAY_VERIFIED;
  if (state === "PHONE_AUTHORITY_LOCKED") return WATCH_PROVISION_DISPLAY_LOCKED;
  if (state === "WATCH_ACTIVATED") return WATCH_PROVISION_DISPLAY_ACTIVATED;
  return state;
}

function decision(state, trace, extra) {
  const body = extra || {};
  return {
    state: state,
    trace: trace,
    reason: body.reason || "",
    canonical: body.canonical || "",
    contentHash: body.contentHash || "",
    rootToCommit: body.rootToCommit || null,
    saved: false,
    d1Certified: false,
    authorityActivated: state === "WATCH_ACTIVATED",
    captureStorageCertified: false,
    authoritativeCaptureAdmitted: false,
    mayAppendSportingRecords: false,
    display: displayFor(state),
  };
}

export function createMemoryProvisionStore() {
  return {
    root: null,
    admission: null,
    failRootWrite: false,
    failAdmissionWrite: false,
    unverifiedRootRead: false,
    readRoot() {
      if (this.unverifiedRootRead) return { status: "unverified" };
      if (this.root == null) return { status: "absent" };
      return { status: "ok", text: this.root };
    },
    readAdmission() {
      if (this.admission == null) return { status: "absent" };
      return { status: "ok", text: this.admission };
    },
    writeRoot(canonical) {
      if (this.failRootWrite) return { status: "unverified" };
      this.root = canonical;
      return { status: "ok", text: canonical };
    },
    writeAdmission(text) {
      if (this.failAdmissionWrite) return { status: "unverified" };
      this.admission = text;
      return { status: "ok", text: text };
    },
  };
}

function fromStore(store, localInstallationId, sportingRecordsExist) {
  const root = store.readRoot();
  if (root.status === "unverified") {
    return decision("STORAGE_UNVERIFIED", ["STORAGE_UNVERIFIED"], { reason: "root-unverified" });
  }
  if (root.status === "absent") {
    const admission = store.readAdmission();
    if (admission.status === "ok" || sportingRecordsExist) {
      return decision("RECOVERY_REQUIRED", ["RECOVERY_REQUIRED"], { reason: "missing-root" });
    }
    return decision("UNPROVISIONED", ["UNPROVISIONED"]);
  }
  const parsed = parseWatchProvisionV1(root.text);
  if (!parsed.document) {
    return decision("RECOVERY_REQUIRED", ["RECOVERY_REQUIRED"], { reason: "corrupt-root" });
  }
  if (parsed.document.writerDeviceId !== localInstallationId) {
    return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], {
      reason: "installation-identity",
      canonical: parsed.document.canonical,
      contentHash: parsed.document.contentHash,
    });
  }
  const admission = store.readAdmission();
  if (admission.status === "unverified") {
    return decision("STORAGE_UNVERIFIED", ["STORAGE_UNVERIFIED"], { reason: "admission-unverified" });
  }
  if (admission.status === "absent") {
    return decision("STORAGE_UNVERIFIED", ["STORAGE_UNVERIFIED"], {
      reason: "incomplete-verification",
      canonical: parsed.document.canonical,
      contentHash: parsed.document.contentHash,
    });
  }
  const verified = stageMarker(parsed.document.contentHash, "WATCH_CONFIG_VERIFIED");
  const activated = stageMarker(parsed.document.contentHash, "WATCH_ACTIVATED");
  if (admission.text === activated) {
    return decision("WATCH_ACTIVATED", ["WATCH_ACTIVATED"], {
      canonical: parsed.document.canonical,
      contentHash: parsed.document.contentHash,
    });
  }
  if (admission.text === verified) {
    return decision("WATCH_CONFIG_VERIFIED", ["WATCH_CONFIG_VERIFIED"], {
      canonical: parsed.document.canonical,
      contentHash: parsed.document.contentHash,
    });
  }
  return decision("RECOVERY_REQUIRED", ["RECOVERY_REQUIRED"], { reason: "admission-mismatch" });
}

export function createWatchProvisionAdmission(store) {
  return {
    loadDurable(localInstallationId, sportingRecordsExist) {
      return fromStore(store, localInstallationId, sportingRecordsExist);
    },
    receive(message, localInstallationId, sportingRecordsExist) {
      const stored = fromStore(store, localInstallationId, sportingRecordsExist);
      const interrupted = stored.state === "STORAGE_UNVERIFIED" && stored.reason === "incomplete-verification";
      if (!interrupted && (stored.state === "STORAGE_UNVERIFIED" || stored.state === "RECOVERY_REQUIRED" || stored.state === "AUTHORITY_CONFLICT")) {
        return stored;
      }
      const parsed = parseWatchProvisionV1(message);
      if (!parsed.document) {
        return decision("CONFIG_INVALID", ["CONFIG_INVALID"], { reason: parsed.reason });
      }
      const document = parsed.document;
      if (document.writerDeviceId !== localInstallationId) {
        return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], { reason: "writerDeviceId" });
      }
      if (stored.canonical && stored.canonical !== document.canonical) {
        return decision(interrupted ? "STORAGE_UNVERIFIED" : "AUTHORITY_CONFLICT", [interrupted ? "STORAGE_UNVERIFIED" : "AUTHORITY_CONFLICT"], {
          reason: interrupted ? "incomplete-verification" : "reprovision",
          canonical: stored.canonical,
          contentHash: stored.contentHash,
        });
      }
      if ((stored.state === "WATCH_ACTIVATED" || stored.state === "WATCH_CONFIG_VERIFIED") && stored.canonical === document.canonical) {
        return stored;
      }
      if (!stored.canonical && !interrupted) {
        const wrote = store.writeRoot(document.canonical);
        if (wrote.status !== "ok" || wrote.text !== document.canonical) {
          return decision("STORAGE_UNVERIFIED", ["STORAGE_UNVERIFIED"], {
            reason: "root-write",
            canonical: document.canonical,
            contentHash: document.contentHash,
          });
        }
        const readBack = store.readRoot();
        if (readBack.status !== "ok" || readBack.text !== document.canonical) {
          return decision("STORAGE_UNVERIFIED", ["STORAGE_UNVERIFIED"], {
            reason: "root-readback",
            canonical: document.canonical,
            contentHash: document.contentHash,
          });
        }
      }
      const marker = stageMarker(document.contentHash, "WATCH_CONFIG_VERIFIED");
      const admissionWrite = store.writeAdmission(marker);
      if (admissionWrite.status !== "ok" || admissionWrite.text !== marker) {
        return decision("STORAGE_UNVERIFIED", ["STORAGE_UNVERIFIED"], {
          reason: "verification-write",
          canonical: document.canonical,
          contentHash: document.contentHash,
        });
      }
      const admissionRead = store.readAdmission();
      if (admissionRead.status !== "ok" || admissionRead.text !== marker) {
        return decision("STORAGE_UNVERIFIED", ["STORAGE_UNVERIFIED"], {
          reason: "verification-readback",
          canonical: document.canonical,
          contentHash: document.contentHash,
        });
      }
      return decision("WATCH_CONFIG_VERIFIED", ["WATCH_CONFIG_VERIFIED"], {
        canonical: document.canonical,
        contentHash: document.contentHash,
      });
    },
    activate(localInstallationId, lockReceipt) {
      const stored = fromStore(store, localInstallationId, false);
      if (stored.state === "WATCH_ACTIVATED" && lockReceipt && lockReceipt.durable && lockReceipt.generation === 1 && lockReceipt.contentHash === stored.contentHash && lockReceipt.writerDeviceId === localInstallationId) {
        return stored;
      }
      if (stored.state !== "WATCH_CONFIG_VERIFIED") {
        if (stored.state === "WATCH_ACTIVATED") {
          return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], { reason: "conflicting-activation" });
        }
        return stored;
      }
      if (!lockReceipt || !lockReceipt.durable || lockReceipt.generation !== 1) {
        return decision("WATCH_CONFIG_VERIFIED", ["WATCH_CONFIG_VERIFIED"], {
          reason: "activation-ack",
          canonical: stored.canonical,
          contentHash: stored.contentHash,
        });
      }
      if (lockReceipt.contentHash !== stored.contentHash || lockReceipt.writerDeviceId !== localInstallationId) {
        return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], {
          reason: "conflicting-activation",
          canonical: stored.canonical,
          contentHash: stored.contentHash,
        });
      }
      const marker = stageMarker(stored.contentHash, "WATCH_ACTIVATED");
      const wrote = store.writeAdmission(marker);
      if (wrote.status !== "ok" || wrote.text !== marker) {
        return decision("WATCH_CONFIG_VERIFIED", ["WATCH_CONFIG_VERIFIED"], {
          reason: "activation-write",
          canonical: stored.canonical,
          contentHash: stored.contentHash,
        });
      }
      const readBack = store.readAdmission();
      if (readBack.status !== "ok" || readBack.text !== marker) {
        return decision("WATCH_CONFIG_VERIFIED", ["WATCH_CONFIG_VERIFIED"], {
          reason: "activation-readback",
          canonical: stored.canonical,
          contentHash: stored.contentHash,
        });
      }
      return decision("WATCH_ACTIVATED", ["WATCH_CONFIG_VERIFIED", "WATCH_ACTIVATED"], {
        canonical: stored.canonical,
        contentHash: stored.contentHash,
      });
    },
  };
}

export function decidePhoneWatchProvision(message, facts) {
  if (facts.rootUnreadable) {
    return decision("RECOVERY_REQUIRED", ["RECOVERY_REQUIRED"], { reason: "phone-root-unreadable" });
  }
  const parsed = parseWatchProvisionV1(message);
  if (!parsed.document) {
    return decision("CONFIG_INVALID", ["CONFIG_INVALID"], { reason: parsed.reason });
  }
  const document = parsed.document;
  if (document.writerDeviceId === facts.phoneOriginDeviceId) {
    return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], { reason: "phone-writer" });
  }
  if (facts.committedSportingRecords > 0) {
    return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], {
      reason: "existing phone-authoritative history",
    });
  }
  if (facts.rootDeviceId) {
    if (facts.rootDeviceId !== document.writerDeviceId || facts.rootPrincipalId !== document.principalId) {
      return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], { reason: "phone-root" });
    }
    return decision("PHONE_AUTHORITY_LOCKED", ["PHONE_AUTHORITY_LOCKED"], {
      reason: "idempotent-phone-root",
      canonical: document.canonical,
      contentHash: document.contentHash,
    });
  }
  return decision("CONFIG_PREPARED", ["CONFIG_PREPARED"], {
    reason: "phone-prepared",
    canonical: document.canonical,
    contentHash: document.contentHash,
  });
}

export function decidePhoneAuthorityLock(message, facts, receipt, transportAvailable) {
  const prepared = decidePhoneWatchProvision(message, facts);
  if (prepared.state === "AUTHORITY_CONFLICT" || prepared.state === "RECOVERY_REQUIRED" || prepared.state === "CONFIG_INVALID" || prepared.state === "PHONE_AUTHORITY_LOCKED") {
    return prepared;
  }
  if (!transportAvailable || !receipt || !receipt.readBack || receipt.generation !== 1) {
    return decision("CONFIG_PREPARED", ["CONFIG_PREPARED"], {
      reason: "transport-unavailable",
      canonical: prepared.canonical,
      contentHash: prepared.contentHash,
    });
  }
  const document = parseWatchProvisionV1(message).document;
  if (!document || receipt.contentHash !== document.contentHash || receipt.writerDeviceId !== document.writerDeviceId) {
    return decision("AUTHORITY_CONFLICT", ["AUTHORITY_CONFLICT"], { reason: "receipt-mismatch" });
  }
  return decision("PHONE_AUTHORITY_LOCKED", ["CONFIG_PREPARED", "PHONE_AUTHORITY_LOCKED"], {
    reason: "lock",
    canonical: document.canonical,
    contentHash: document.contentHash,
    rootToCommit: {
      matchId: document.matchId,
      principalId: document.principalId,
      deviceId: document.writerDeviceId,
      generation: 1,
    },
  });
}
