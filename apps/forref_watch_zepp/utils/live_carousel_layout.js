import { layoutStack } from "./geometry.js";

const DOT = 8;
const DOT_GAP = 8;

function markerInside(info, x, y, w, h) {
  if (w < 4 || h < 4) {
    return false;
  }
  if (!info.round) {
    return x >= 2 && y >= 64 && x + w <= info.width - 2 && y + h <= info.height - 2;
  }
  const cx = info.width / 2;
  const cy = info.height / 2;
  const r = Math.min(info.width, info.height) / 2 - 12;
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

export function rectsOverlap(a, b) {
  if (!a || !b) {
    return false;
  }
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

export function layoutDots(info) {
  const rowW = DOT * 3 + DOT_GAP * 2;
  const x = Math.round((info.width - rowW) / 2);
  const y = info.round ? info.height - 34 : info.height - DOT - 2;
  const dots = [];
  let ok = true;
  for (let i = 0; i < 3; i++) {
    const rect = {
      x: x + i * (DOT + DOT_GAP),
      y: y,
      w: DOT,
      h: DOT,
    };
    rect.ok = markerInside(info, rect.x, rect.y, rect.w, rect.h);
    if (!rect.ok) {
      ok = false;
    }
    dots.push(rect);
  }
  return { dots: dots, ok: ok };
}

export function teamSeparator(home, away) {
  if (!home || !away) {
    return null;
  }
  if (away.x >= home.x + home.w) {
    const gapX = home.x + home.w;
    const gapW = away.x - gapX;
    const w = 2;
    if (gapW < w + 2) {
      return null;
    }
    return {
      x: gapX + Math.floor((gapW - w) / 2),
      y: home.y + 10,
      w: w,
      h: Math.max(4, home.h - 20),
      vertical: true,
    };
  }
  if (away.y >= home.y + home.h) {
    const gapY = home.y + home.h;
    const gapH = away.y - gapY;
    const h = 2;
    if (gapH < h + 2) {
      return null;
    }
    const inset = 16;
    return {
      x: home.x + inset,
      y: gapY + Math.floor((gapH - h) / 2),
      w: Math.max(4, home.w - inset * 2),
      h: h,
      vertical: false,
    };
  }
  return null;
}

export function stackLimit(info) {
  return layoutDots(info).dots[0].y;
}

export function pageFits(info, rowCount) {
  const laid = layoutStack(info, rowCount, stackLimit(info));
  if (!laid || !laid.rows || laid.rows.length < rowCount) {
    return false;
  }
  for (let i = 0; i < rowCount; i++) {
    if (!laid.rows[i] || laid.rows[i].ok !== true) {
      return false;
    }
  }
  return true;
}

export function dotsClearOf(info, obstacles) {
  const laid = layoutDots(info);
  if (!laid.ok) {
    return false;
  }
  const list = obstacles || [];
  for (let i = 0; i < laid.dots.length; i++) {
    for (let j = 0; j < list.length; j++) {
      if (list[j] && rectsOverlap(laid.dots[i], list[j])) {
        return false;
      }
    }
  }
  return true;
}
