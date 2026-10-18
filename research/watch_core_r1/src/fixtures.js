// RESEARCH ONLY. Synthetic disciplinary collections for the validation instrument.
// These fixtures are not Match Memory and are not reused across scope by retitling.

function player(id, team, number, extra = {}) {
  return {
    id,
    team,
    number,
    standingCaution: false,
    admission: null,
    removed: false,
    ...extra,
  };
}

function collection({ id, scope, depth, participants, admissionTargetId, sendOffTargetId }) {
  return {
    id,
    scope,
    depth,
    completeness: 'verified-complete',
    researchOnly: true,
    admissionTargetId,
    sendOffTargetId,
    participants,
  };
}

export function cloneCollection(collectionValue) {
  return structuredClone(collectionValue);
}

export function participantIds(collectionValue) {
  return collectionValue.participants.map((participant) => participant.id);
}

export function sharedParticipantIds(left, right) {
  const rightIds = new Set(participantIds(right));
  return participantIds(left).filter((id) => rightIds.has(id));
}

export function buildMatchNegativeD2() {
  return collection({
    id: 'match-negative-d2',
    scope: 'MATCH',
    depth: 'D2',
    admissionTargetId: 'neg-d2-h-2',
    sendOffTargetId: 'neg-d2-a-3',
    participants: [
      player('neg-d2-h-2', 'HOME', 2),
      player('neg-d2-a-3', 'AWAY', 3),
    ],
  });
}

export function buildMatchNegativeD6() {
  return collection({
    id: 'match-negative-d6',
    scope: 'MATCH',
    depth: 'D6',
    admissionTargetId: 'neg-d6-h-2',
    sendOffTargetId: 'neg-d6-h-6',
    participants: [
      player('neg-d6-h-2', 'HOME', 2),
      player('neg-d6-h-4', 'HOME', 4),
      player('neg-d6-h-6', 'HOME', 6),
      player('neg-d6-a-3', 'AWAY', 3),
      player('neg-d6-a-5', 'AWAY', 5),
      player('neg-d6-a-7', 'AWAY', 7),
    ],
  });
}

export function buildMatchNegativeD10() {
  return collection({
    id: 'match-negative-d10',
    scope: 'MATCH',
    depth: 'D10',
    admissionTargetId: 'neg-d10-h-2',
    sendOffTargetId: 'neg-d10-h-8',
    participants: [
      player('neg-d10-h-2', 'HOME', 2),
      player('neg-d10-h-4', 'HOME', 4),
      player('neg-d10-h-6', 'HOME', 6),
      player('neg-d10-h-8', 'HOME', 8),
      player('neg-d10-h-10', 'HOME', 10),
      player('neg-d10-a-3', 'AWAY', 3),
      player('neg-d10-a-5', 'AWAY', 5),
      player('neg-d10-a-7', 'AWAY', 7),
      player('neg-d10-a-9', 'AWAY', 9),
      player('neg-d10-a-11', 'AWAY', 11),
    ],
  });
}

export function buildMatchPositive() {
  return collection({
    id: 'match-positive-h14',
    scope: 'MATCH',
    depth: 'D5',
    admissionTargetId: 'pos-h-14',
    sendOffTargetId: 'pos-h-8',
    participants: [
      player('pos-h-14', 'HOME', 14, { standingCaution: true, admission: 'd1' }),
      player('pos-h-8', 'HOME', 8),
      player('pos-h-4', 'HOME', 4),
      player('pos-a-3', 'AWAY', 3),
      player('pos-a-9', 'AWAY', 9),
    ],
  });
}

/** Before-state for durable admission and for a not-yet-D1 attempt. Same match identity as the positive fixture, without a standing caution. */
export function buildMatchAdmissionReady() {
  const next = buildMatchPositive();
  next.id = 'match-admission-ready';
  const target = next.participants.find((participant) => participant.id === next.admissionTargetId);
  target.standingCaution = false;
  target.admission = null;
  return next;
}

/** Positive match plus a durable caution on the designated send-off participant. */
export function buildMatchSendOffReady() {
  const next = buildMatchPositive();
  next.id = 'match-sendoff-ready';
  const target = next.participants.find((participant) => participant.id === next.sendOffTargetId);
  target.standingCaution = true;
  target.admission = 'd1';
  return next;
}

export function buildShootout() {
  return collection({
    id: 'shootout-priors',
    scope: 'SHOOTOUT',
    depth: 'D4',
    admissionTargetId: 'so-h-4',
    sendOffTargetId: 'so-a-5',
    participants: [
      player('so-h-8', 'HOME', 8, { standingCaution: true, admission: 'd1' }),
      player('so-h-4', 'HOME', 4),
      player('so-a-5', 'AWAY', 5),
      player('so-a-11', 'AWAY', 11),
    ],
  });
}

export function buildUnavailableCollection() {
  return {
    id: 'match-unavailable',
    scope: 'MATCH',
    depth: 'D0',
    completeness: 'unavailable',
    researchOnly: true,
    admissionTargetId: null,
    sendOffTargetId: null,
    participants: [],
  };
}

export const FIXTURES = Object.freeze({
  'match-negative-d2': buildMatchNegativeD2,
  'match-negative-d6': buildMatchNegativeD6,
  'match-negative-d10': buildMatchNegativeD10,
  'match-positive-h14': buildMatchPositive,
  'match-admission-ready': buildMatchAdmissionReady,
  'match-sendoff-ready': buildMatchSendOffReady,
  'shootout-priors': buildShootout,
  'match-unavailable': buildUnavailableCollection,
});

export const FIXTURE_NAMES = Object.freeze(Object.keys(FIXTURES));

export function getFixture(name) {
  const build = FIXTURES[name];
  if (!build) throw new Error(`unknown research fixture: ${name}`);
  return build();
}

export function hasParticipant(collectionValue, team, number) {
  return collectionValue.participants.some(
    (participant) => !participant.removed && participant.team === team && participant.number === number,
  );
}
