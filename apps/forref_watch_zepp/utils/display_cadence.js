// Display scheduling only. Official elapsed time stays the open anchor plus
// device UTC. A paint delay is not a second of match time.

export function nextPaintDelay(nowMs) {
  if (typeof nowMs !== "number" || !isFinite(nowMs)) {
    return 1000;
  }
  const into = Math.floor(nowMs) % 1000;
  const normalized = into < 0 ? into + 1000 : into;
  if (normalized === 0) {
    return 1000;
  }
  return 1000 - normalized;
}

export function digitHoldKey(parts) {
  return [
    parts.mode,
    parts.unverified ? "1" : "0",
    parts.added ? "1" : "0",
    parts.telemetry ? "1" : "0",
    parts.detail ? "1" : "0",
    parts.phaseY,
    parts.timeY,
  ].join("|");
}
