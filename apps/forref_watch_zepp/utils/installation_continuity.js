import { GOAL_JOURNAL_FILE, readStoredText } from "./goal_journal.js";
import { INSTALLATION_FILE } from "./installation_id.js";
import { GOAL_CONTEXT_FILE } from "./local_test_score.js";

const PROVISION_CORRELATION_FILE = "forref_watch_provision_correlation_v1.txt";

const PROVISION_ROOT_FILE = "forref_watch_provision_v1.root";
const PROVISION_ADMISSION_FILE = "forref_watch_provision_v1.admission";
const ENROLL_CORRELATION_FILE = "forref_watch_enroll_correlation_v1.txt";
const ENROLL_ROOT_FILE = "forref_watch_enroll_v1.root";
const ENROLL_ADMISSION_FILE = "forref_watch_enroll_v1.admission";
const PAIR_CORRELATION_FILE = "forref_watch_pair_correlation_v1.txt";
const PAIR_ROOT_FILE = "forref_watch_pair_v1.root";
const PAIR_ADMISSION_FILE = "forref_watch_pair_v1.admission";
const TRANSFER_CORRELATION_FILE = "forref_watch_transfer_correlation_v1.txt";
const TRANSFER_ROOT_FILE = "forref_watch_transfer_v1.root";
const TRANSFER_ADMISSION_FILE = "forref_watch_transfer_v1.admission";

export const DATA_PREFIX = "data://";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function durablePath(name) {
  return DATA_PREFIX + name;
}

function uuid() {
  const bytes = new Array(16);
  for (let i = 0; i < 16; i += 1) bytes[i] = Math.floor(Math.random() * 256);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.map((value) => value.toString(16).padStart(2, "0")).join("");
  return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-" + hex.slice(12, 16) + "-" + hex.slice(16, 20) + "-" + hex.slice(20);
}

function readAt(fs, path) {
  return readStoredText(fs, path);
}

function classify(read) {
  if (!read || read.status === "absent") return { presence: "absent", text: "" };
  if (read.status !== "ok") return { presence: "unreadable", text: "" };
  return { presence: "present", text: String(read.text) };
}

function identityOf(read) {
  const file = classify(read);
  if (file.presence !== "present") return { presence: file.presence, id: "" };
  const id = file.text.trim();
  if (!UUID.test(id)) return { presence: "corrupt", id: "" };
  return { presence: "present", id: id };
}

function writeExact(fs, path, text) {
  try {
    fs.writeFileSync({ path: path, data: text, options: { encoding: "utf8" } });
  } catch (err) {
    return false;
  }
  const back = readAt(fs, path);
  return !!(back && back.status === "ok" && String(back.text) === text);
}

function listedNames(fs) {
  if (!fs || typeof fs.readdirSync !== "function") return [];
  const names = [];
  const dirs = [DATA_PREFIX, "."];
  for (let i = 0; i < dirs.length; i += 1) {
    try {
      const found = fs.readdirSync({ path: dirs[i] });
      const list = Array.isArray(found) ? found : [];
      for (let n = 0; n < list.length; n += 1) {
        const raw = String(list[n]);
        const name = raw.split("/").pop();
        if (name) names.push(name);
      }
    } catch (err) {
      // A missing directory listing is not evidence that a named file is absent.
    }
  }
  return names;
}

function filePair(fs, name) {
  return {
    data: classify(readAt(fs, durablePath(name))),
    legacy: classify(readAt(fs, name)),
  };
}

function pairPresence(pair) {
  if (pair.data.presence === "unreadable" || pair.legacy.presence === "unreadable") return "unreadable";
  if (pair.data.presence === "present" && pair.legacy.presence === "present" && pair.data.text !== pair.legacy.text) return "conflict";
  if (pair.data.presence === "present" || pair.legacy.presence === "present") return "present";
  return "absent";
}

function copyLegacy(fs, name, pair) {
  if (pair.data.presence === "present" || pair.legacy.presence !== "present") return pairPresence(pair);
  if (pair.data.presence === "unreadable") return "unreadable";
  const copied = writeExact(fs, durablePath(name), pair.legacy.text);
  return copied ? "present" : "unverified";
}

function phaseOf(text) {
  const match = /"phase"\s*:\s*"([a-z]+)"/.exec(text || "");
  return match ? match[1] : "";
}

function admissionState(text) {
  if ((text || "").indexOf("state=WATCH_ACTIVATED") >= 0) return "activated";
  if ((text || "").indexOf("state=WATCH_CONFIG_VERIFIED") >= 0) return "prepared";
  return "";
}

function enrollPresence(correlation, root, admission) {
  const parts = [pairPresence(correlation), pairPresence(root), pairPresence(admission)];
  if (parts.indexOf("unreadable") >= 0) return "unreadable";
  if (parts.indexOf("conflict") >= 0) return "conflict";
  if (parts.indexOf("present") >= 0) return "present";
  return "absent";
}

function journalListed(names) {
  for (let i = 0; i < names.length; i += 1) {
    if (/^forref_watch_goal_/.test(names[i])) return true;
  }
  return false;
}

function lineFor(result) {
  const files = result.files || {};
  return "FORREF_IDENTITY case=" + (result.case || "recovery") +
    " created=" + (result.created ? "1" : "0") +
    " reason=" + (result.reason || "") +
    " evidence=" + (result.evidence || "") +
    " installation=" + (files.installation || "absent") +
    " correlation=" + (files.correlation || "absent") +
    " enroll=" + (files.enroll || "absent") +
    " pair=" + (files.pair || "absent") +
    " transfer=" + (files.transfer || "absent") +
    " root=" + (files.root || "absent") +
    " admission=" + (files.admission || "absent") +
    " journal=" + (files.journal || "absent") +
    " phase=" + (result.phase || "") +
    " id=" + (result.id || "");
}

function recovery(reason, files, phase, evidence) {
  const result = {
    ok: false,
    id: "",
    reason: reason,
    created: false,
    case: "recovery",
    evidence: evidence || "",
    phase: phase || "",
    files: files,
  };
  result.line = lineFor(result);
  return result;
}

function success(id, created, evidence, files, phase) {
  const result = {
    ok: true,
    id: id,
    reason: "",
    created: created,
    case: created ? "fresh" : "reused",
    evidence: evidence,
    phase: phase || "",
    files: files,
  };
  result.line = lineFor(result);
  return result;
}

export function readDurableText(fs, name) {
  const data = readAt(fs, durablePath(name));
  if (data && data.status === "ok") return data;
  if (data && data.status === "unreadable") return data;
  return readAt(fs, name);
}

export function readDurableInstallation(fs) {
  const data = identityOf(readAt(fs, durablePath(INSTALLATION_FILE)));
  const legacy = identityOf(readAt(fs, INSTALLATION_FILE));
  if (data.presence === "unreadable" || legacy.presence === "unreadable") {
    return { ok: false, id: "", reason: "unreadable" };
  }
  if (data.presence === "corrupt" || legacy.presence === "corrupt") {
    return { ok: false, id: "", reason: "corrupt" };
  }
  if (data.id && legacy.id && data.id !== legacy.id) {
    return { ok: false, id: "", reason: "identity-conflict" };
  }
  if (data.id) return { ok: true, id: data.id, reason: "", evidence: "data" };
  if (legacy.id) return { ok: true, id: legacy.id, reason: "", evidence: "legacy" };
  return { ok: false, id: "", reason: "missing-installation" };
}

export function resolveInstallation(fs) {
  const names = listedNames(fs);
  const installation = {
    data: identityOf(readAt(fs, durablePath(INSTALLATION_FILE))),
    legacy: identityOf(readAt(fs, INSTALLATION_FILE)),
  };
  const correlation = filePair(fs, PROVISION_CORRELATION_FILE);
  const root = filePair(fs, PROVISION_ROOT_FILE);
  const admission = filePair(fs, PROVISION_ADMISSION_FILE);
  const context = filePair(fs, GOAL_CONTEXT_FILE);
  const journal = filePair(fs, GOAL_JOURNAL_FILE);
  const enrollCorrelation = filePair(fs, ENROLL_CORRELATION_FILE);
  const enrollRoot = filePair(fs, ENROLL_ROOT_FILE);
  const enrollAdmission = filePair(fs, ENROLL_ADMISSION_FILE);
  const pairCorrelation = filePair(fs, PAIR_CORRELATION_FILE);
  const pairRoot = filePair(fs, PAIR_ROOT_FILE);
  const pairAdmission = filePair(fs, PAIR_ADMISSION_FILE);
  const transferCorrelation = filePair(fs, TRANSFER_CORRELATION_FILE);
  const transferRoot = filePair(fs, TRANSFER_ROOT_FILE);
  const transferAdmission = filePair(fs, TRANSFER_ADMISSION_FILE);
  const journalPresent = pairPresence(journal) !== "absent" || journalListed(names);
  const files = {
    installation: installation.data.presence === "present" || installation.legacy.presence === "present"
      ? "present"
      : installation.data.presence === "unreadable" || installation.legacy.presence === "unreadable"
        ? "unreadable"
        : installation.data.presence === "corrupt" || installation.legacy.presence === "corrupt"
          ? "corrupt"
          : "absent",
    correlation: pairPresence(correlation),
    root: pairPresence(root),
    admission: pairPresence(admission),
    journal: journalPresent ? (pairPresence(journal) === "unreadable" ? "unreadable" : "present") : "absent",
    context: pairPresence(context),
    enroll: enrollPresence(enrollCorrelation, enrollRoot, enrollAdmission),
    pair: enrollPresence(pairCorrelation, pairRoot, pairAdmission),
    transfer: enrollPresence(transferCorrelation, transferRoot, transferAdmission),
  };
  const admissionText = admission.data.text || admission.legacy.text;
  const correlationText = correlation.data.text || correlation.legacy.text;
  const phase = phaseOf(correlationText);
  const activated = admissionState(admissionText) === "activated" || phase === "activated" || phase === "reported";
  const prepared = files.root === "present" || files.correlation === "present" || admissionState(admissionText) === "prepared" || phase === "verified" || phase === "pending";
  const statePresent = files.correlation !== "absent" || files.root !== "absent" || files.admission !== "absent" || files.journal !== "absent" || files.context !== "absent" || files.enroll !== "absent" || files.pair !== "absent" || files.transfer !== "absent";

  if (installation.data.presence === "unreadable" || installation.legacy.presence === "unreadable") {
    return recovery("unreadable", files, phase, "");
  }
  if (installation.data.presence === "corrupt" || installation.legacy.presence === "corrupt") {
    return recovery("corrupt", files, phase, "");
  }
  if (installation.data.id && installation.legacy.id && installation.data.id !== installation.legacy.id) {
    return recovery("identity-conflict", files, phase, "conflict");
  }

  const known = installation.data.id || installation.legacy.id;
  if (known) {
    if (!installation.data.id) {
      const copied = writeExact(fs, durablePath(INSTALLATION_FILE), known);
      if (!copied) {
        const failed = recovery("copy-unverified", files, phase, "legacy");
        failed.id = known;
        failed.line = lineFor(failed);
        return failed;
      }
    }
    copyLegacy(fs, PROVISION_CORRELATION_FILE, correlation);
    copyLegacy(fs, PROVISION_ROOT_FILE, root);
    copyLegacy(fs, PROVISION_ADMISSION_FILE, admission);
    return success(known, false, installation.data.id ? "data" : "legacy", files, phase);
  }

  if (statePresent) {
    const reason = activated ? "lost-identity-activated" : prepared ? "lost-identity-prepared" : "lost-identity-state";
    return recovery(reason, files, phase, "state");
  }

  const created = uuid();
  const wrote = writeExact(fs, durablePath(INSTALLATION_FILE), created);
  if (!wrote) return recovery("unverified", files, "", "fresh");
  files.installation = "present";
  return success(created, true, "fresh", files, "");
}
