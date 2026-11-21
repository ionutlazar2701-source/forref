// Amazfit Bip 6 is 390×450. The square status bar occupies the top 64 px
// in the same coordinate space used by the other Bip 6 probes.
export const STATUS_BAR = 64;
export const MARGIN = 12;

export function layoutChron(width, height) {
  const x = MARGIN;
  const inner = width - MARGIN * 2;
  const buttonH = 56;
  const gap = 8;
  const buttonY = height - MARGIN - buttonH;
  const buttonW = Math.floor((inner - gap) / 2);
  return {
    width: width,
    height: height,
    background: { x: 0, y: 0, w: width, h: height },
    title: { x: x, y: STATUS_BAR, w: inner, h: 26 },
    clock: { x: x, y: STATUS_BAR + 32, w: inner, h: 64 },
    status: { x: x, y: STATUS_BAR + 102, w: inner, h: 30 },
    detail: { x: x, y: STATUS_BAR + 136, w: inner, h: 52 },
    diagnostic: { x: x, y: STATUS_BAR + 192, w: inner, h: 28 },
    primary: { x: x, y: buttonY, w: buttonW, h: buttonH },
    secondary: { x: x + buttonW + gap, y: buttonY, w: buttonW, h: buttonH },
  };
}

export function layoutFits(box, width, height) {
  return box.x >= 0 &&
    box.y >= STATUS_BAR &&
    box.w > 0 &&
    box.h >= 26 &&
    box.x + box.w <= width &&
    box.y + box.h <= height - 8;
}
