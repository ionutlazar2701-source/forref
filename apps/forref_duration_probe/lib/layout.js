const SAFE_MARGIN = 12;
const SQUARE_STATUS_BAR = 64;

export function layoutProbe(info, rowCount) {
  const round = info.round === true || info.screenShape === 1;
  const top = round ? 24 : SQUARE_STATUS_BAR;
  const titleH = 26;
  const gap = 6;
  const bottom = info.height - SAFE_MARGIN;
  const available = bottom - (top + titleH + 8);
  const h = Math.floor((available - gap * (rowCount - 1)) / rowCount);
  const pad = round ? Math.round(info.width * 0.12) : SAFE_MARGIN;
  const w = info.width - pad * 2;
  const x = Math.round((info.width - w) / 2);
  const rows = [];
  let y = top + titleH + 8;
  for (let i = 0; i < rowCount; i += 1) {
    rows.push({ x: x, y: y, w: w, h: h });
    y += h + gap;
  }
  return { titleY: top, titleH: titleH, rows: rows, rowH: h };
}

export function rowFits(info, row) {
  if (row.w < 40 || row.h < 28) {
    return false;
  }
  if (!(info.round === true || info.screenShape === 1)) {
    return row.y >= SQUARE_STATUS_BAR && row.x >= 2 && row.x + row.w <= info.width - 2 && row.y + row.h <= info.height - 2;
  }
  return true;
}
