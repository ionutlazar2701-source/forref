// View-only page index for the Live workspace. A page change carries no match intent.

export const PAGE_CONTROLS = 0;
export const PAGE_LIVE = 1;
export const PAGE_CAUTIONS = 2;
export const PAGE_COUNT = 3;

export const SWIPE_MIN_PX = 48;
export const TAP_MAX_PX = 24;
export const AXIS_RATIO = 1.5;

export function initialPage() {
  return PAGE_LIVE;
}

export function clampPage(index) {
  const n = Number(index);
  if (!isFinite(n)) {
    return PAGE_LIVE;
  }
  if (n <= PAGE_CONTROLS) {
    return PAGE_CONTROLS;
  }
  if (n >= PAGE_CAUTIONS) {
    return PAGE_CAUTIONS;
  }
  return Math.round(n);
}

export function transitionPage(current, next) {
  const from = clampPage(current);
  const to = clampPage(next);
  const changed = from !== to;
  return {
    index: to,
    changed: changed,
    disarm: changed,
    intents: [],
  };
}

export function dotMarks(index) {
  const active = clampPage(index);
  const marks = [];
  for (let i = 0; i < PAGE_COUNT; i++) {
    marks.push({ index: i, active: i === active });
  }
  return marks;
}

export function backTarget(index) {
  const current = clampPage(index);
  if (current === PAGE_LIVE) {
    return { leave: true, index: current, intents: [] };
  }
  return { leave: false, index: PAGE_LIVE, intents: [] };
}

function contains(rect, x, y) {
  if (!rect || typeof rect.x !== "number") {
    return false;
  }
  return x >= rect.x && y >= rect.y && x < rect.x + rect.w && y < rect.y + rect.h;
}

function findHit(rects, x, y) {
  const names = Object.keys(rects || {});
  for (let i = 0; i < names.length; i++) {
    if (contains(rects[names[i]], x, y)) {
      return names[i];
    }
  }
  return "";
}

// Coordinate model for a future gesture API. The device path does not call this:
// onGesture reports a direction only, so a swipe cannot prove it missed a team button.
export function arbitratePointer(start, end, rects) {
  const x0 = start && typeof start.x === "number" ? start.x : 0;
  const y0 = start && typeof start.y === "number" ? start.y : 0;
  const x1 = end && typeof end.x === "number" ? end.x : x0;
  const y1 = end && typeof end.y === "number" ? end.y : y0;
  const dx = x1 - x0;
  const dy = y1 - y0;
  const adx = Math.abs(dx);
  const ady = Math.abs(dy);
  const origin = findHit(rects, x0, y0);
  const finish = findHit(rects, x1, y1);
  if (origin) {
    if (adx <= TAP_MAX_PX && ady <= TAP_MAX_PX && finish === origin) {
      return { kind: "tap", target: origin, pageDelta: 0, intents: [], consume: true, reason: "TAP" };
    }
    return { kind: "cancel", target: "", pageDelta: 0, intents: [], consume: true, reason: "STARTED_ON_CONTROL" };
  }
  if (adx >= SWIPE_MIN_PX && adx >= ady * AXIS_RATIO) {
    return {
      kind: "swipe",
      target: "",
      pageDelta: dx < 0 ? 1 : -1,
      intents: [],
      consume: true,
      reason: "HORIZONTAL",
    };
  }
  if (!origin && finish && adx <= TAP_MAX_PX && ady <= TAP_MAX_PX) {
    return { kind: "tap", target: finish, pageDelta: 0, intents: [], consume: true, reason: "TAP" };
  }
  return { kind: "ignore", target: "", pageDelta: 0, intents: [], consume: false, reason: "BELOW_THRESHOLD" };
}

export function applyPointerPage(current, decision) {
  if (!decision || decision.kind !== "swipe") {
    return transitionPage(current, current);
  }
  return transitionPage(current, clampPage(current) + decision.pageDelta);
}

// onGesture has no coordinates. Right slide is the system Back gesture.
// Off the Live page, Back returns to Live. It does not move the carousel forward.
export function arbitratePlatformGesture(event, codes, index) {
  const map = codes || {};
  const current = clampPage(index);
  let name = "unknown";
  if (event === map.left) {
    name = "left";
  } else if (event === map.right) {
    name = "right";
  } else if (event === map.up) {
    name = "up";
  } else if (event === map.down) {
    name = "down";
  }
  if (name === "right" && current !== PAGE_LIVE) {
    return {
      gate: "BACK_TO_LIVE",
      consume: true,
      pageDelta: 0,
      intents: [],
      reason: "PAGE_BACK",
      index: PAGE_LIVE,
    };
  }
  if (name === "right") {
    return {
      gate: "BLOCKED",
      consume: false,
      pageDelta: 0,
      intents: [],
      reason: "SYSTEM_BACK",
      index: current,
    };
  }
  if (name === "left") {
    return {
      gate: "BLOCKED",
      consume: false,
      pageDelta: 0,
      intents: [],
      reason: "NO_TOUCH_OWNERSHIP",
      index: current,
    };
  }
  return {
    gate: "BLOCKED",
    consume: false,
    pageDelta: 0,
    intents: [],
    reason: "IGNORED",
    index: current,
  };
}
