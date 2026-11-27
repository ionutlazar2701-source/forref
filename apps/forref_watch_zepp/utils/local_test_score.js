export const LOCAL_TEST_LABEL = "LOCAL TEST";
export const GOAL_CONTEXT_FILE = "forref_watch_goal_context_v1.json";

function conflict() {
  return { kind: "conflict", knownScore: false, home: null, away: null };
}

export function localTestScore(entries, context, status) {
  if (!context || context.authorityActivated !== true) {
    return { kind: "hidden", knownScore: false, home: null, away: null };
  }
  if (context.generation && context.generation !== 1) return conflict();
  if (status === "corrupt") return conflict();
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
    if (entry.matchId && context.matchId && entry.matchId !== context.matchId) return conflict();
    if (entry.principalId && context.principalId && entry.principalId !== context.principalId) return conflict();
    if (entry.writerDeviceId && context.writerDeviceId && entry.writerDeviceId !== context.writerDeviceId) return conflict();
    if (entry.generation && entry.generation !== 1) return conflict();
    if (seen[entry.captureIntentId]) continue;
    seen[entry.captureIntentId] = true;
    if (entry.scoringTeamId === context.homeTeamId) home += 1;
    else if (entry.scoringTeamId === context.awayTeamId) away += 1;
    else return { kind: "unavailable", knownScore: false, home: null, away: null };
  }
  return { kind: "local-test", knownScore: false, home: home, away: away };
}

export function localTestPresentation(preview, fits, labels) {
  if (!preview || preview.kind === "hidden") {
    return { warning: "", home: labels.homeScore, away: labels.awayScore, numerals: false, withheld: false };
  }
  if (preview.kind === "conflict") {
    return { warning: "", home: labels.conflict, away: labels.conflict, numerals: false, withheld: false };
  }
  if (preview.kind !== "local-test" || fits !== true) {
    return {
      warning: "",
      home: labels.home + " —",
      away: labels.away + " —",
      numerals: false,
      withheld: preview.kind === "local-test",
    };
  }
  return {
    warning: labels.localTest,
    home: labels.home + " " + preview.home,
    away: labels.away + " " + preview.away,
    numerals: true,
    withheld: false,
  };
}

export function createLocalScoreCache() {
  let value = null;
  let fresh = false;
  return {
    invalidate() {
      fresh = false;
    },
    publish(preview) {
      value = preview;
      fresh = true;
    },
    paint() {
      return fresh ? value : null;
    },
  };
}

const publishedScore = createLocalScoreCache();

export function invalidatePublishedLocalScore() {
  publishedScore.invalidate();
}

export function publishLocalScore(preview) {
  publishedScore.publish(preview);
}

export function readPublishedLocalScore() {
  return publishedScore.paint();
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
