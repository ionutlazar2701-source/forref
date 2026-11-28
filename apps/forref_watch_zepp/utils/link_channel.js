// Device-to-side liveness. PING and PONG carry a sequence only.
// This module does not import ZML and does not touch the match clock.

export function pingRequest(seq) {
  return { method: "PING", params: { seq: seq } };
}

export function isPong(body, seq) {
  return !!(body && body.method === "PONG" && body.seq === seq);
}

export function replyLink(req) {
  if (!req || req.method !== "PING") return null;
  const seq = req.params && req.params.seq;
  if (typeof seq !== "number" || !Number.isInteger(seq) || seq < 1) return { error: "seq" };
  return { body: { method: "PONG", seq: seq } };
}

export function nextLinkSeq(globalData) {
  const current = globalData && globalData.linkSeq;
  const seq = typeof current === "number" && Number.isInteger(current) && current >= 0 ? current + 1 : 1;
  globalData.linkSeq = seq;
  return seq;
}
