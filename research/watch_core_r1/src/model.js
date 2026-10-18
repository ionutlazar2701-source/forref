// RESEARCH ONLY. In-memory validation instrument.
// Capture footprints never create match records. Scenario transitions are simulations.

import {
  createClockScenario,
  interruptClock,
  readClock,
  recoverClock,
  stepClock,
} from './clock.js';
import {
  buildMatchAdmissionReady,
  buildMatchNegativeD10,
  buildMatchPositive,
  buildMatchSendOffReady,
  buildShootout,
  cloneCollection,
  getFixture,
  sharedParticipantIds,
} from './fixtures.js';

export const EMPTY_MATCH_RECORDS = Object.freeze([]);

export const RESEARCH_CAPTURE_CONTROLS = Object.freeze([
  Object.freeze({ kind: 'yellow', label: 'Yellow', widthPx: 86, heightPx: 48, researchOnly: true }),
  Object.freeze({ kind: 'red', label: 'Red', widthPx: 86, heightPx: 48, researchOnly: true }),
  Object.freeze({ kind: 'goal', label: 'Goal', widthPx: 86, heightPx: 48, researchOnly: true }),
  Object.freeze({
    kind: 'substitution',
    label: 'Substitution',
    widthPx: 86,
    heightPx: 48,
    researchOnly: true,
  }),
]);

export const RESEARCH_CAPTURE_KINDS = Object.freeze(
  RESEARCH_CAPTURE_CONTROLS.map((control) => control.kind),
);

export const RESEARCH_CAPTURE_GAP_PX = 8;
export const WATCH_COLUMN_PX = 228;

export const SCENARIO_NAMES = Object.freeze([
  'durableCautionAdmission',
  'failedNotYetD1Caution',
  'authoritativeSendOffRemoval',
  'disciplinaryRecoveryUncertainty',
  'restorationOfVerifiedCompleteness',
  'matchToShootoutScope',
]);

const TEAMS = new Set(['HOME', 'AWAY', 'ALL']);

function freshRecall() {
  return {
    scrollTop: 0,
    team: 'ALL',
    inspectedParticipantId: null,
    inspection: 'active',
  };
}

function baseState(collection, clockName = '67:12') {
  return {
    researchOnly: true,
    screen: 'live',
    scope: collection.scope,
    collection: cloneCollection(collection),
    historicalMatch: null,
    recall: freshRecall(),
    researchTaps: [],
    matchRecords: EMPTY_MATCH_RECORDS,
    clock: createClockScenario(clockName),
    scenarioTrace: null,
  };
}

export function createInitialState() {
  return baseState(buildMatchNegativeD10());
}

export function scenarioSeed(name) {
  switch (name) {
    case 'durableCautionAdmission':
    case 'failedNotYetD1Caution':
      return baseState(buildMatchAdmissionReady());
    case 'authoritativeSendOffRemoval':
      return baseState(buildMatchSendOffReady());
    case 'disciplinaryRecoveryUncertainty':
      return baseState(buildMatchNegativeD10());
    case 'restorationOfVerifiedCompleteness':
      return {
        ...baseState(buildMatchNegativeD10()),
        collection: {
          ...cloneCollection(buildMatchNegativeD10()),
          completeness: 'unverified',
        },
      };
    case 'matchToShootoutScope':
      return baseState(buildMatchPositive());
    default:
      throw new Error(`unknown research scenario: ${name}`);
  }
}

function updateParticipant(state, participantId, updater) {
  if (!participantId) throw new Error('missing research participant target');
  let found = false;
  const participants = state.collection.participants.map((participant) => {
    if (participant.id !== participantId) return participant;
    found = true;
    return updater(participant);
  });
  if (!found) throw new Error(`missing research participant ${participantId}`);
  return {
    ...state,
    collection: { ...state.collection, participants },
    matchRecords: EMPTY_MATCH_RECORDS,
  };
}

export function activateScope(state, nextCollection) {
  if (nextCollection.scope !== state.collection.scope) {
    const shared = sharedParticipantIds(state.collection, nextCollection);
    if (shared.length > 0) {
      throw new Error(`scope change reuses participant ids: ${shared.join(',')}`);
    }
  }
  const historicalMatch = nextCollection.scope === 'SHOOTOUT' && state.collection.scope === 'MATCH'
    ? cloneCollection(state.collection)
    : null;
  return {
    ...state,
    scope: nextCollection.scope,
    collection: cloneCollection(nextCollection),
    historicalMatch,
    recall: freshRecall(),
    matchRecords: EMPTY_MATCH_RECORDS,
  };
}

export function applyTransition(state, name) {
  switch (name) {
    case 'durableCautionAdmission':
      return updateParticipant(state, state.collection.admissionTargetId, (participant) => ({
        ...participant,
        standingCaution: true,
        admission: 'd1',
      }));
    case 'failedNotYetD1Caution':
      return updateParticipant(state, state.collection.admissionTargetId, (participant) => ({
        ...participant,
        standingCaution: false,
        admission: 'not-d1',
      }));
    case 'authoritativeSendOffRemoval':
      return updateParticipant(state, state.collection.sendOffTargetId, (participant) => ({
        ...participant,
        removed: true,
      }));
    case 'disciplinaryRecoveryUncertainty':
      return {
        ...state,
        collection: { ...state.collection, completeness: 'unverified' },
        matchRecords: EMPTY_MATCH_RECORDS,
      };
    case 'restorationOfVerifiedCompleteness':
      return {
        ...state,
        collection: { ...state.collection, completeness: 'verified-complete' },
        matchRecords: EMPTY_MATCH_RECORDS,
      };
    case 'matchToShootoutScope':
      if (state.collection.scope !== 'MATCH') {
        throw new Error('MATCH → SHOOTOUT requires MATCH scope');
      }
      return activateScope(state, buildShootout());
    default:
      throw new Error(`unknown research scenario: ${name}`);
  }
}

function summarize(state) {
  return {
    scope: state.scope,
    collectionId: state.collection.id,
    completeness: state.collection.completeness,
    participants: state.collection.participants.map((participant) => ({
      id: participant.id,
      team: participant.team,
      number: participant.number,
      standingCaution: participant.standingCaution,
      admission: participant.admission,
      removed: participant.removed,
    })),
    historicalIds: state.historicalMatch
      ? state.historicalMatch.participants.map((participant) => participant.id)
      : null,
  };
}

export function replayScenario(name) {
  const seed = scenarioSeed(name);
  const next = applyTransition(seed, name);
  return {
    ...next,
    scenarioTrace: {
      name,
      before: summarize(seed),
      after: summarize(next),
    },
  };
}

export function tapCapture(state, kind) {
  if (!RESEARCH_CAPTURE_KINDS.includes(kind)) {
    throw new Error(`unknown research capture: ${kind}`);
  }
  return {
    ...state,
    researchTaps: [
      ...state.researchTaps,
      { kind, researchOnly: true, wroteMatchRecord: false },
    ],
    matchRecords: EMPTY_MATCH_RECORDS,
  };
}

export function loadFixture(state, name) {
  const collection = cloneCollection(getFixture(name));
  return {
    ...state,
    scope: collection.scope,
    collection,
    historicalMatch: null,
    recall: freshRecall(),
    scenarioTrace: null,
    matchRecords: EMPTY_MATCH_RECORDS,
  };
}

export function openRecall(state) {
  return { ...state, screen: 'recall', matchRecords: EMPTY_MATCH_RECORDS };
}

export function setTeam(state, team) {
  if (!TEAMS.has(team)) throw new Error(`unknown team context: ${team}`);
  return {
    ...state,
    recall: { ...state.recall, team, scrollTop: 0 },
  };
}

export function setScroll(state, scrollTop) {
  if (!Number.isFinite(scrollTop) || scrollTop < 0) {
    throw new Error('scroll position must be a non-negative number');
  }
  return {
    ...state,
    recall: { ...state.recall, scrollTop },
  };
}

export function setInspection(state, inspection) {
  if (inspection !== 'active' && inspection !== 'historical-match') {
    throw new Error(`unknown inspection: ${inspection}`);
  }
  if (inspection === 'historical-match' && !state.historicalMatch) {
    throw new Error('no historical MATCH to inspect');
  }
  return {
    ...state,
    recall: {
      ...state.recall,
      inspection,
      scrollTop: 0,
      inspectedParticipantId: null,
    },
  };
}

function collectionForInspection(state) {
  return state.recall.inspection === 'historical-match'
    ? state.historicalMatch
    : state.collection;
}

export function openDetail(state, participantId, { scrollTop } = {}) {
  const collection = collectionForInspection(state);
  if (!collection || collection.completeness !== 'verified-complete') {
    throw new Error('detail withheld while collection is not verified complete');
  }
  const participant = collection.participants.find(
    (candidate) => candidate.id === participantId && !candidate.removed,
  );
  if (!participant) throw new Error('participant not in the verified collection');
  return {
    ...state,
    screen: 'detail',
    recall: {
      ...state.recall,
      scrollTop: scrollTop ?? state.recall.scrollTop,
      inspectedParticipantId: participantId,
    },
  };
}

export function backToRecall(state) {
  return { ...state, screen: 'recall' };
}

export function returnLive(state) {
  return { ...state, screen: 'live' };
}

export function visibleRoster(state) {
  const collection = collectionForInspection(state);
  if (!collection || collection.completeness !== 'verified-complete') {
    return { withheld: true, participants: [], collection };
  }
  const { team } = state.recall;
  const participants = collection.participants.filter(
    (participant) => !participant.removed && (team === 'ALL' || participant.team === team),
  );
  return { withheld: false, participants, collection };
}

export function inspectedParticipant(state) {
  const id = state.recall.inspectedParticipantId;
  if (!id) return null;
  const collection = collectionForInspection(state);
  if (!collection) return null;
  return collection.participants.find((participant) => participant.id === id) ?? null;
}

export function askStandingCaution(state, { team = 'HOME', number = 14, source = 'active' } = {}) {
  if (source !== 'active' && source !== 'historical-match') {
    throw new Error(`unknown caution source: ${source}`);
  }
  const question = `Does ${team} #${number} have a standing caution?`;
  const collection = source === 'historical-match' ? state.historicalMatch : state.collection;
  const meta = {
    question,
    scope: collection?.scope ?? null,
    depth: collection?.depth ?? null,
    collectionId: collection?.id ?? null,
    completeness: collection?.completeness ?? null,
  };
  if (!collection || collection.completeness !== 'verified-complete') {
    return {
      ...meta,
      certainty: 'unavailable',
      answer: null,
      basis: collection ? 'collection-not-verified-complete' : 'collection-unavailable',
    };
  }
  const found = collection.participants.find(
    (participant) => !participant.removed && participant.team === team && participant.number === number,
  );
  if (!found) {
    return { ...meta, certainty: 'certain', answer: false, basis: 'absent' };
  }
  if (found.standingCaution && found.admission !== 'd1') {
    return { ...meta, certainty: 'unavailable', answer: null, basis: 'admission-not-durable' };
  }
  if (found.standingCaution) {
    return {
      ...meta,
      certainty: 'certain',
      answer: true,
      basis: 'present-with-standing-caution',
    };
  }
  return {
    ...meta,
    certainty: 'certain',
    answer: false,
    basis: 'present-without-standing-caution',
  };
}

export function presentAnswer(result) {
  if (result.certainty !== 'certain' || result.answer === null) {
    return 'Unavailable — this collection cannot answer.';
  }
  if (result.answer === true) return 'Yes — standing caution.';
  if (result.basis === 'absent') return 'No — absent from the verified complete set.';
  if (result.basis === 'present-without-standing-caution') {
    return 'No — present without a standing caution.';
  }
  throw new Error(`unpresentable research answer: ${result.basis}`);
}

export function loadClockScenario(state, name) {
  return { ...state, clock: createClockScenario(name) };
}

export function tick(state, deltaMs) {
  return { ...state, clock: stepClock(state.clock, deltaMs) };
}

export function interruptTiming(state) {
  return { ...state, clock: interruptClock(state.clock) };
}

export function recoverTiming(state) {
  return { ...state, clock: recoverClock(state.clock) };
}

export function projectClock(state) {
  return readClock(state.clock);
}
