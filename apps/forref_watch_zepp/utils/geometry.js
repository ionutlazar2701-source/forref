export const SAFE_MARGIN = 12;
export const SQUARE_STATUS_BAR = 64;

export function radius(info) {
  return Math.min(info.width, info.height) / 2 - SAFE_MARGIN;
}

export function inside(info, x, y, w, h) {
  if (w < 40 || h < 28) {
    return false;
  }
  if (!info.round) {
    return x >= 2 && y >= SQUARE_STATUS_BAR && x + w <= info.width - 2 && y + h <= info.height - 2;
  }
  const cx = info.width / 2;
  const cy = info.height / 2;
  const r = radius(info);
  const pts = [
    [x, y],
    [x + w - 1, y],
    [x, y + h - 1],
    [x + w - 1, y + h - 1],
  ];
  for (let i = 0; i < pts.length; i++) {
    const dx = pts[i][0] - cx;
    const dy = pts[i][1] - cy;
    if (dx * dx + dy * dy > r * r) {
      return false;
    }
  }
  return true;
}

export function place(info, y, h, wantedW) {
  let w = Math.max(40, Math.min(wantedW, info.width - 4));
  let guard = 0;
  while (guard < 500) {
    const x = Math.round((info.width - w) / 2);
    if (inside(info, x, y, w, h)) {
      return { x: x, y: y, w: w, h: h, ok: true };
    }
    w -= 2;
    guard += 1;
    if (w < 40) {
      break;
    }
  }
  const x = Math.round((info.width - Math.max(w, 40)) / 2);
  return { x: x, y: y, w: Math.max(w, 40), h: h, ok: false };
}

function tryStack(info, count, h) {
  const gap = 6;
  const titleH = 34;
  const top = info.round ? 28 : SQUARE_STATUS_BAR + 4;
  const rows = [];
  for (let i = 0; i < count; i++) {
    const y = top + titleH + i * (h + gap);
    const rect = place(info, y, h, info.width - (info.round ? 8 : 16));
    if (!rect.ok) {
      return null;
    }
    rows.push(rect);
  }
  return { titleY: top, titleH: titleH, rows: rows };
}

export function layoutStack(info, count) {
  for (let h = 56; h >= 32; h -= 2) {
    const laid = tryStack(info, count, h);
    if (laid) {
      return laid;
    }
  }
  return tryStack(info, count, 32) || { titleY: 0, titleH: 28, rows: [] };
}

export function layoutClock(info, actionCount) {
  const actions = actionCount === 1 ? 1 : 2;
  const status = place(info, info.round ? 40 : SQUARE_STATUS_BAR + 4, 32, info.round ? 280 : info.width - 20);
  const time = place(info, status.y + status.h + 2, info.round ? 72 : 64, info.round ? 320 : info.width - 16);
  const score = place(info, time.y + time.h + 2, 28, info.round ? 280 : time.w);
  const primary = place(info, score.y + score.h + 6, info.round ? 48 : 44, info.round ? 280 : info.width - 20);
  let secondary = null;
  let backY = primary.y + primary.h + 6;
  if (actions === 2) {
    secondary = place(info, backY, primary.h, primary.w);
    backY = secondary.y + secondary.h + 6;
  }
  const back = place(info, backY, 40, info.round ? 200 : primary.w);
  return { status: status, time: time, score: score, primary: primary, secondary: secondary, back: back };
}

export function layoutLive(info, mode) {
  const gap = 8;
  const vertical = mode === "C";
  if (!vertical) {
    const teamH = info.round ? 100 : 108;
    const teamY = info.round ? 188 : SQUARE_STATUS_BAR + 132;
    const full = place(info, teamY, teamH, info.round ? 340 : info.width - 20);
    const w = Math.floor((full.w - gap) / 2);
    const home = { x: full.x, y: teamY, w: w, h: teamH, ok: inside(info, full.x, teamY, w, teamH) };
    const away = {
      x: full.x + w + gap,
      y: teamY,
      w: w,
      h: teamH,
      ok: inside(info, full.x + w + gap, teamY, w, teamH),
    };
    const navH = 46;
    const navY = info.round ? 328 : info.height - 58;
    const nav = place(info, navY, navH, full.w);
    const nw = Math.floor((nav.w - gap) / 2);
    const display = { x: nav.x, y: navY, w: nw, h: navH, ok: inside(info, nav.x, navY, nw, navH) };
    const back = {
      x: nav.x + nw + gap,
      y: navY,
      w: nav.w - nw - gap,
      h: navH,
      ok: inside(info, nav.x + nw + gap, navY, nav.w - nw - gap, navH),
    };
    return {
      phaseY: info.round ? 52 : SQUARE_STATUS_BAR + 6,
      timeY: info.round ? 96 : SQUARE_STATUS_BAR + 44,
      home: home,
      away: away,
      display: display,
      back: back,
    };
  }
  const bandH = info.round ? 72 : 80;
  const homeY = info.round ? 58 : SQUARE_STATUS_BAR + 8;
  const home = place(info, homeY, bandH, info.round ? 280 : info.width - 20);
  const awayY = info.round ? 250 : SQUARE_STATUS_BAR + 196;
  const away = place(info, awayY, bandH, home.w);
  const navH = 44;
  const navY = info.round ? 352 : info.height - 56;
  const nav = place(info, navY, navH, home.w);
  const nw = Math.floor((nav.w - gap) / 2);
  return {
    phaseY: info.round ? 146 : SQUARE_STATUS_BAR + 104,
    timeY: info.round ? 184 : SQUARE_STATUS_BAR + 140,
    home: home,
    away: away,
    display: { x: nav.x, y: navY, w: nw, h: navH, ok: inside(info, nav.x, navY, nw, navH) },
    back: {
      x: nav.x + nw + gap,
      y: navY,
      w: nav.w - nw - gap,
      h: navH,
      ok: inside(info, nav.x + nw + gap, navY, nav.w - nw - gap, navH),
    },
  };
}

export function layoutEvent(info) {
  const gap = 8;
  const top = info.round ? 78 : SQUARE_STATUS_BAR + 28;
  let cell = info.round ? 128 : 118;
  let rects = null;
  while (cell >= 64) {
    const totalW = cell * 2 + gap;
    const x0 = Math.round((info.width - totalW) / 2);
    const next = [];
    let ok = true;
    for (let row = 0; row < 2; row++) {
      for (let col = 0; col < 2; col++) {
        const rect = {
          x: x0 + col * (cell + gap),
          y: top + row * (cell + gap),
          w: cell,
          h: cell,
        };
        rect.ok = inside(info, rect.x, rect.y, rect.w, rect.h);
        if (!rect.ok) {
          ok = false;
        }
        next.push(rect);
      }
    }
    if (ok) {
      rects = next;
      break;
    }
    cell -= 2;
  }
  const gridBottom = rects ? rects[3].y + rects[3].h : top + 200;
  const back = place(info, gridBottom + 10, 42, info.round ? 220 : info.width - 24);
  return {
    yellow: rects ? rects[0] : back,
    red: rects ? rects[1] : back,
    goal: rects ? rects[2] : back,
    sub: rects ? rects[3] : back,
    back: back,
    titleY: info.round ? 36 : SQUARE_STATUS_BAR + 2,
  };
}

export function controlsOk(bag) {
  const names = Object.keys(bag);
  for (let i = 0; i < names.length; i++) {
    const value = bag[names[i]];
    if (value && typeof value.ok === "boolean" && !value.ok) {
      return false;
    }
  }
  return true;
}
