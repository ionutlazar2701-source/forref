export const LOCAL_TEST_LABEL = "LOCAL TEST";
export const GOAL_CONTEXT_FILE = "forref_watch_goal_context_v1.json";

export function localTestScore(entries, context, status) {
  if (!context || context.authorityActivated !== true) {
    return { kind: "hidden", knownScore: false, home: null, away: null };
  }
  if (status === "corrupt") {
    return { kind: "conflict", knownScore: false, home: null, away: null };
  }
  if (status !== "ok" && status !== "empty") {
    return { kind: "unavailable", knownScore: false, home: null, away: null };
  }
  const seen = {};
  let home = 0;
  let away = 0;
  const rows = entries || [];
  for (let i = 0; i < rows.length; i += 1) {
    const entry = rows[i];
    if (entry.semanticType && entry.semanticType !== "GOAL") {
      return { kind: "unavailable", knownScore: false, home: null, away: null };
    }
    if (seen[entry.captureIntentId]) continue;
    seen[entry.captureIntentId] = true;
    if (entry.scoringTeamId === context.homeTeamId) home += 1;
    else if (entry.scoringTeamId === context.awayTeamId) away += 1;
    else return { kind: "unavailable", knownScore: false, home: null, away: null };
  }
  return { kind: "local-test", knownScore: false, home: home, away: away };
}

export function readGoalContext(fs) {
  let text = "";
  try {
    text = fs.readFileSync({
      path: GOAL_CONTEXT_FILE,
      options: { encoding: "utf8" },
    });
  } catch (err) {
    return null;
  }
  if (text == null || text === "") return null;
  try {
    const parsed = JSON.parse(String(text));
    if (!parsed || parsed.authorityActivated !== true) return null;
    if (!parsed.matchId || !parsed.homeTeamId || !parsed.awayTeamId || !parsed.writerDeviceId) {
      return null;
    }
    return parsed;
  } catch (err) {
    return null;
  }
}
