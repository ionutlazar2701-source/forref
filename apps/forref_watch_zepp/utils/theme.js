// True Black candidate tokens. The canvas value is fixed.
// Accent hexes stay open for founder ACCEPT / REVISE / REJECT.

export const CANVAS = 0x000000;
export const TEXT_PRIMARY = 0xffffff;
export const TEXT_SECONDARY = 0xb3cbd7;
export const TEXT_WARNING = 0xc4a35a;
export const ACCENT = 0x3fc3be;

export const ROLES = {
  primary: { normal: 0x3fc3be, press: 0xd7f6f5, text: 0x000000 },
  navigation: { normal: 0x2796d6, press: 0xd6edfa, text: 0x000000 },
  neutral: { normal: 0x000000, press: 0x163a4a, text: 0xffffff },
  yellow: { normal: 0x8a7430, press: 0x5c4c18, text: 0xffffff },
  red: { normal: 0x6e2430, press: 0x4a1820, text: 0xffffff },
  caution: { normal: 0x6e5418, press: 0x3a2c0c, text: 0xffffff },
  selected: { normal: 0x3fc3be, press: 0xd7f6f5, text: 0x000000 },
};

export function styleFor(fill) {
  if (typeof fill === "string" && Object.prototype.hasOwnProperty.call(ROLES, fill)) {
    return ROLES[fill];
  }
  return ROLES.navigation;
}
