// RESEARCH ONLY. A moving stimulus for referee timing trials.
// This clock is not Domain Clock authority and does not commit temporal records.

/** Product statements this instrument must keep visible during timing trials. */
export const FROZEN_TEMPORAL_SEMANTICS = Object.freeze({
  researchClockIsNotAuthority: true,
  phaseAtThreshold: 'running-period',
  thresholdEndsPeriod: false,
  thresholdEndsMatch: false,
  overrunShiftsNextNominalBase: false,
  addedTimeIsNotASecondTimer: true,
  displayContinuesThroughThreshold: true,
  statements: Object.freeze([
    '45:00 does not end the period.',
    '90:00 does not end the match.',
    'The main clock continues: 90:00 → 90:01. Added time is a phase, not a second timer.',
    'Overrun does not shift the next period nominal base.',
  ]),
});

export const CLOCK_SCENARIOS = Object.freeze({
  '67:12': Object.freeze({ originSeconds: 67 * 60 + 12 }),
  '44:58': Object.freeze({ originSeconds: 44 * 60 + 58 }),
  '45+': Object.freeze({ originSeconds: 45 * 60 + 1 }),
  '90+': Object.freeze({ originSeconds: 90 * 60 + 1 }),
  '105+': Object.freeze({ originSeconds: 105 * 60 + 1 }),
  '120+': Object.freeze({ originSeconds: 120 * 60 + 1 }),
});

export const CLOCK_SCENARIO_NAMES = Object.freeze(Object.keys(CLOCK_SCENARIOS));

export function createResearchClock({ originSeconds, elapsedMs = 0, interrupted = false }) {
  if (!Number.isInteger(originSeconds) || originSeconds < 0) {
    throw new Error('research clock origin must be a non-negative integer second');
  }
  if (!Number.isInteger(elapsedMs) || elapsedMs < 0) {
    throw new Error('research clock elapsed must be a non-negative integer millisecond');
  }
  return {
    researchOnly: true,
    authoritative: false,
    originSeconds,
    elapsedMs,
    interrupted: Boolean(interrupted),
  };
}

export function createClockScenario(name) {
  const scenario = CLOCK_SCENARIOS[name];
  if (!scenario) throw new Error(`unknown research clock scenario: ${name}`);
  return createResearchClock({ originSeconds: scenario.originSeconds });
}

export function clockTotalSeconds(clock) {
  return clock.originSeconds + clock.elapsedMs / 1000;
}

export function formatFootballClock(totalSeconds) {
  const whole = Math.floor(totalSeconds);
  const minutes = Math.floor(whole / 60);
  const seconds = whole % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export function stepClock(clock, deltaMs) {
  if (!Number.isInteger(deltaMs) || deltaMs < 0) {
    throw new Error('research clock step must be a non-negative integer millisecond');
  }
  if (clock.interrupted || deltaMs === 0) return clock;
  return { ...clock, elapsedMs: clock.elapsedMs + deltaMs };
}

export function interruptClock(clock) {
  if (clock.interrupted) return clock;
  return { ...clock, interrupted: true };
}

export function recoverClock(clock) {
  if (!clock.interrupted) return clock;
  return { ...clock, interrupted: false };
}

export function readClock(clock) {
  const totalSeconds = clockTotalSeconds(clock);
  return {
    label: formatFootballClock(totalSeconds),
    totalSeconds,
    phase: FROZEN_TEMPORAL_SEMANTICS.phaseAtThreshold,
    interrupted: clock.interrupted,
    authoritative: false,
    semantics: FROZEN_TEMPORAL_SEMANTICS,
  };
}
