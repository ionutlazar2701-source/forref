import { INSTALLATION_FILE, readInstallationId } from "./installation_id.js";
import { createFileProvisionStore } from "./provision_transport.js";
import { createWatchProvisionAdmission, parseWatchProvisionV1 } from "./watch_provision.js";
import { readStoredText } from "./goal_journal.js";

export const PROVISION_ROOT_FILE = "forref_watch_provision_v1.root";
export const PROVISION_ADMISSION_FILE = "forref_watch_provision_v1.admission";

function refused(reason, authorityActivated) {
  console.log("FORREF_EVENT outcome=REFUSED reason=" + reason);
  return {
    localCandidate: false,
    authoritativeCaptureAdmitted: false,
    captureStorageCertified: false,
    authorityActivated: authorityActivated === true,
    reason: reason,
  };
}

export function admitLocalGoal(input) {
  const installation = readInstallationId(input.installationStore);
  if (!installation.ok) return refused(installation.reason || "installation", false);
  const decision = createWatchProvisionAdmission(input.provisionStore).loadDurable(installation.id, false);
  if (!decision.authorityActivated || !decision.canonical) {
    return refused(decision.reason || decision.state || "authority", false);
  }
  const parsed = parseWatchProvisionV1(decision.canonical);
  const document = parsed.document;
  if (!document || document.writerDeviceId !== installation.id) {
    return refused("installation-identity", false);
  }
  if (input.matchId && input.matchId !== document.matchId) {
    return refused("match", true);
  }
  return {
    localCandidate: true,
    authoritativeCaptureAdmitted: false,
    captureStorageCertified: false,
    authorityActivated: true,
    reason: "",
    localInstallationId: installation.id,
    matchId: document.matchId,
    principalId: document.principalId,
    writerDeviceId: document.writerDeviceId,
    homeTeamId: document.homeTeamId,
    awayTeamId: document.awayTeamId,
    generation: 1,
  };
}

function textStore(fs, path) {
  return {
    read() {
      return readStoredText(fs, path);
    },
    write() {
      throw new Error("installation-write");
    },
  };
}

export function admitStoredGoal(fs, matchId) {
  return admitLocalGoal({
    matchId: matchId || "",
    installationStore: textStore(fs, INSTALLATION_FILE),
    provisionStore: createFileProvisionStore(fs, PROVISION_ROOT_FILE, PROVISION_ADMISSION_FILE),
  });
}
