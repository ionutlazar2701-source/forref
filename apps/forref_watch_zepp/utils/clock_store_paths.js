// Shared checkpoint names. The file pair is the screen-off record.
// LocalStorage is the in-app copy. Neither one is Match Memory.
export const CLOCK_FILE = "forref_clock001c_state.json";
export const CLOCK_MIRROR = "forref_clock001c_state.mirror.json";
export const CLOCK_KEY = "forref_clock001c_state";
export const CLOCK_WITNESS = "forref_clock001c_witness.json";
// CLOCK-004 dual slot. These names are not a new version of the v1 session file.
export const CLOCK_SEGMENT_A = "forref_clock004_a.json";
export const CLOCK_SEGMENT_B = "forref_clock004_b.json";
export const CLOCK_ENGINE = "forref_clock004_engine.txt";
// Independent CLOCK-006 note. It is not a segment slot and it is not restored.
export const CLOCK_PHONE_ANCHOR = "forref_clock006_anchor.json";
