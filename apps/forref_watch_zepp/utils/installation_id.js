const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export const INSTALLATION_FILE = "forref_watch_installation_v1.txt";

function uuid() {
  const bytes = new Array(16);
  for (let i = 0; i < 16; i += 1) {
    bytes[i] = Math.floor(Math.random() * 256);
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.map((value) => value.toString(16).padStart(2, "0")).join("");
  return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-" + hex.slice(12, 16) + "-" + hex.slice(16, 20) + "-" + hex.slice(20);
}

export function readInstallationId(store) {
  const read = store.read();
  if (read.status === "unreadable") {
    console.log("FORREF_PROVISION outcome=RECOVERY_REQUIRED reason=installation-unreadable");
    return { ok: false, reason: "unreadable", id: "" };
  }
  if (read.status !== "ok" || !read.text) {
    console.log("FORREF_PROVISION outcome=RECOVERY_REQUIRED reason=missing-installation");
    return { ok: false, reason: "missing-installation", id: "" };
  }
  const id = String(read.text).trim();
  if (!UUID.test(id)) {
    console.log("FORREF_PROVISION outcome=RECOVERY_REQUIRED reason=installation-corrupt");
    return { ok: false, reason: "corrupt", id: "" };
  }
  return { ok: true, reason: "", id: id };
}

export function loadInstallationId(store) {
  const read = store.read();
  if (read.status === "unreadable") {
    console.log("FORREF_PROVISION outcome=RECOVERY_REQUIRED reason=installation-unreadable");
    return { ok: false, reason: "unreadable", id: "" };
  }
  if (read.status === "ok" && read.text) {
    const id = String(read.text).trim();
    if (!UUID.test(id)) {
      console.log("FORREF_PROVISION outcome=RECOVERY_REQUIRED reason=installation-corrupt");
      return { ok: false, reason: "corrupt", id: "" };
    }
    return { ok: true, reason: "", id: id };
  }
  const created = uuid();
  const wrote = store.write(created);
  const back = store.read();
  if (!wrote || wrote.status !== "ok" || !back || back.status !== "ok" || String(back.text).trim() !== created) {
    console.log("FORREF_PROVISION outcome=STORAGE_UNVERIFIED reason=installation-write");
    return { ok: false, reason: "unverified", id: "" };
  }
  console.log("FORREF_PROVISION outcome=INSTALLATION_CREATED reason=");
  return { ok: true, reason: "", id: created };
}
