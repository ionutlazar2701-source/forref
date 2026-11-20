// Geometry frames for the V5 carousel. These are layout renders, not Zepp framebuffers.
import { writeFileSync, mkdirSync, readFileSync } from "node:fs";
import { deflateSync } from "node:zlib";
import { layoutLive, layoutStack } from "../utils/geometry.js";
import { CANVAS, ROLES, TEXT_PRIMARY, TEXT_SECONDARY, TEXT_WARNING, ACCENT } from "../utils/theme.js";
import { layoutDots, stackLimit, teamSeparator } from "../utils/live_carousel_layout.js";
import { dotMarks } from "../utils/live_carousel.js";

const FONT = {
  A: "01110,10001,10001,11111,10001,10001,10001",
  B: "11110,10001,10001,11110,10001,10001,11110",
  C: "01111,10000,10000,10000,10000,10000,01111",
  D: "11110,10001,10001,10001,10001,10001,11110",
  E: "11111,10000,10000,11110,10000,10000,11111",
  F: "11111,10000,10000,11110,10000,10000,10000",
  G: "01111,10000,10000,10111,10001,10001,01111",
  H: "10001,10001,10001,11111,10001,10001,10001",
  I: "11111,00100,00100,00100,00100,00100,11111",
  J: "00111,00010,00010,00010,00010,10010,01100",
  K: "10001,10010,10100,11000,10100,10010,10001",
  L: "10000,10000,10000,10000,10000,10000,11111",
  M: "10001,11011,10101,10101,10001,10001,10001",
  N: "10001,11001,10101,10011,10001,10001,10001",
  O: "01110,10001,10001,10001,10001,10001,01110",
  P: "11110,10001,10001,11110,10000,10000,10000",
  R: "11110,10001,10001,11110,10100,10010,10001",
  S: "01111,10000,10000,01110,00001,00001,11110",
  T: "11111,00100,00100,00100,00100,00100,00100",
  U: "10001,10001,10001,10001,10001,10001,01110",
  V: "10001,10001,10001,10001,10001,01010,00100",
  W: "10001,10001,10001,10101,10101,10101,01010",
  Y: "10001,10001,01010,00100,00100,00100,00100",
  "0": "01110,10001,10011,10101,11001,10001,01110",
  "1": "00100,01100,00100,00100,00100,00100,01110",
  "2": "01110,10001,00001,00010,00100,01000,11111",
  "3": "11110,00001,00001,01110,00001,00001,11110",
  "4": "00010,00110,01010,10010,11111,00010,00010",
  "5": "11111,10000,10000,11110,00001,00001,11110",
  "6": "01110,10000,10000,11110,10001,10001,01110",
  "7": "11111,00001,00010,00100,01000,01000,01000",
  "8": "01110,10001,10001,01110,10001,10001,01110",
  "9": "01110,10001,10001,01111,00001,00001,01110",
  " ": "00000,00000,00000,00000,00000,00000,00000",
  ".": "00000,00000,00000,00000,00000,01100,01100",
  ":": "00000,01100,01100,00000,01100,01100,00000",
  "-": "00000,00000,00000,11111,00000,00000,00000",
  "·": "00000,00000,00000,01100,01100,00000,00000",
  "—": "00000,00000,00000,11111,00000,00000,00000",
};

function rgb(hex) {
  return [(hex >> 16) & 255, (hex >> 8) & 255, hex & 255, 255];
}

function create(w, h) {
  const px = new Uint8Array(w * h * 4);
  const bg = rgb(CANVAS);
  for (let i = 0; i < px.length; i += 4) {
    px[i] = bg[0];
    px[i + 1] = bg[1];
    px[i + 2] = bg[2];
    px[i + 3] = 255;
  }
  return { w: w, h: h, px: px };
}

function put(img, x, y, color) {
  const xi = Math.round(x);
  const yi = Math.round(y);
  if (xi < 0 || yi < 0 || xi >= img.w || yi >= img.h) {
    return;
  }
  const at = (yi * img.w + xi) * 4;
  const c = rgb(color);
  img.px[at] = c[0];
  img.px[at + 1] = c[1];
  img.px[at + 2] = c[2];
  img.px[at + 3] = 255;
}

function fill(img, rect, color) {
  for (let y = rect.y; y < rect.y + rect.h; y++) {
    for (let x = rect.x; x < rect.x + rect.w; x++) {
      put(img, x, y, color);
    }
  }
}

function text(img, rect, value, color, scale) {
  const glyphs = String(value || "").toUpperCase().split("");
  let s = scale || 2;
  while (s > 1 && glyphs.length * 6 * s > rect.w - 8) {
    s -= 1;
  }
  const gw = 6 * s;
  const width = Math.min(glyphs.length * gw, rect.w - 4);
  let x = rect.x + Math.max(2, Math.round((rect.w - width) / 2));
  const y = rect.y + Math.max(2, Math.round((rect.h - 7 * s) / 2));
  const right = rect.x + rect.w - 2;
  glyphs.forEach((ch) => {
    if (x >= right) {
      return;
    }
    const rows = (FONT[ch] || FONT[" "]).split(",");
    rows.forEach((row, ry) => {
      for (let rx = 0; rx < row.length; rx++) {
        if (row[rx] === "1") {
          for (let dy = 0; dy < s; dy++) {
            for (let dx = 0; dx < s; dx++) {
              const px = x + rx * s + dx;
              if (px >= rect.x && px < right) {
                put(img, px, y + ry * s + dy, color);
              }
            }
          }
        }
      }
    });
    x += gw;
  });
}

function png(img) {
  const raw = Buffer.alloc((img.w * 4 + 1) * img.h);
  for (let y = 0; y < img.h; y++) {
    const start = y * (img.w * 4 + 1);
    raw[start] = 0;
    img.px.subarray(y * img.w * 4, (y + 1) * img.w * 4).forEach((byte, i) => {
      raw[start + 1 + i] = byte;
    });
  }
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0);
  ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}

function chunk(type, data) {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(data.length, 0);
  head.write(type, 4);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([Buffer.from(type), data])) >>> 0, 0);
  return Buffer.concat([head, data, crc]);
}

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
  }
  return ~c;
}

function label(key) {
  const src = readFileSync(new URL("../utils/text.js", import.meta.url), "utf8");
  const en = src.slice(src.indexOf("const EN"), src.indexOf("const RO"));
  const found = en.match(new RegExp(key + ': "([^"]*)"'));
  return found ? found[1] : key;
}

function buttonOf(img, rect, value, role) {
  const tone = ROLES[role] || ROLES.navigation;
  fill(img, rect, tone.normal);
  text(img, rect, value, tone.text, rect.h >= 70 ? 2 : 1);
}

function dots(img, info, page) {
  const laid = layoutDots(info);
  const marks = dotMarks(page);
  laid.dots.forEach((dot, index) => {
    fill(img, dot, marks[index].active ? ACCENT : TEXT_SECONDARY);
  });
}

function liveFrame(info, mode, unverified) {
  const img = create(info.width, info.height);
  const lay = layoutLive(info, mode);
  const phase = unverified ? label("timeUnverified") : label("clockReady");
  const digits = unverified ? "--:--" : "00:00";
  const phaseColor = unverified ? TEXT_WARNING : ACCENT;
  text(img, { x: 12, y: lay.phaseY, w: info.width - 24, h: 28 }, phase, phaseColor, 2);
  text(img, { x: 12, y: lay.timeY, w: info.width - 24, h: mode === "C" ? 36 : 48 }, digits, TEXT_PRIMARY, mode === "C" ? 3 : 4);
  text(
    img,
    { x: 12, y: lay.timeY + (mode === "C" ? 36 : 48), w: info.width - 24, h: 16 },
    label("distanceNone") + "  " + label("hrNone") + "  " + label("gpsNone"),
    TEXT_SECONDARY,
    1
  );
  const rule = teamSeparator(lay.home, lay.away);
  if (rule) {
    fill(img, rule, TEXT_SECONDARY);
  }
  buttonOf(img, lay.home, label("homeScore"), "neutral");
  buttonOf(img, lay.away, label("awayScore"), "neutral");
  buttonOf(img, lay.display, unverified ? label("back") : label("kickOff"), unverified ? "navigation" : "primary");
  buttonOf(img, lay.back, label("matchControls"), "navigation");
  dots(img, info, 1);
  return img;
}

function stacked(info, page, title, rows, status) {
  const img = create(info.width, info.height);
  const laid = layoutStack(info, rows.length + 1, stackLimit(info));
  const guide = laid.rows[0];
  text(img, { x: guide.x, y: laid.titleY, w: guide.w, h: laid.titleH }, title, ACCENT, 2);
  text(img, laid.rows[0], status, TEXT_PRIMARY, 1);
  rows.forEach((row, index) => {
    const slot = laid.rows[index + 1];
    if (row.role) {
      buttonOf(img, slot, row.label, row.role);
    } else {
      text(img, slot, row.label, TEXT_WARNING, 1);
    }
  });
  dots(img, info, page);
  return img;
}

const shapes = [
  { width: 390, height: 450, round: false, name: "rect" },
  { width: 480, height: 480, round: true, name: "round" },
];

const out = new URL("../../../docs/forref-execution/evidence/zepp-native-familiarity-v5/frames/", import.meta.url);
mkdirSync(out, { recursive: true });

for (const info of shapes) {
  writeFileSync(new URL(info.name + "-live.png", out), png(liveFrame(info, "A", false)));
  writeFileSync(new URL(info.name + "-live-c.png", out), png(liveFrame(info, "C", false)));
  writeFileSync(new URL(info.name + "-live-unverified.png", out), png(liveFrame(info, "A", true)));
  writeFileSync(
    new URL(info.name + "-controls.png", out),
    png(
      stacked(
        info,
        0,
        label("matchControls"),
        [
          { label: label("display"), role: "navigation" },
          { label: label("cautions"), role: "navigation" },
          { label: label("backToLive"), role: "navigation" },
        ],
        label("clockReady") + " · 00:00"
      )
    )
  );
  writeFileSync(
    new URL(info.name + "-cautions.png", out),
    png(
      stacked(
        info,
        2,
        label("cautions"),
        [
          { label: label("cautionsBody") },
          { label: label("matchControls"), role: "navigation" },
          { label: label("backToLive"), role: "navigation" },
        ],
        label("clockReady") + " · 00:00"
      )
    )
  );
}

console.log("frames", out.pathname);
