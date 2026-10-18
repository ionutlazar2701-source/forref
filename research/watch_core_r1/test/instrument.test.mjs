import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  CLOCK_SCENARIO_NAMES,
  FROZEN_TEMPORAL_SEMANTICS,
  createClockScenario,
  formatFootballClock,
  readClock,
  stepClock,
} from '../src/clock.js';
import {
  buildMatchNegativeD10,
  buildMatchNegativeD2,
  buildMatchNegativeD6,
  buildMatchPositive,
  buildShootout,
  cloneCollection,
  getFixture,
  hasParticipant,
  sharedParticipantIds,
} from '../src/fixtures.js';
import {
  EMPTY_MATCH_RECORDS,
  RESEARCH_CAPTURE_CONTROLS,
  RESEARCH_CAPTURE_GAP_PX,
  SCENARIO_NAMES,
  WATCH_COLUMN_PX,
  activateScope,
  applyTransition,
  askStandingCaution,
  backToRecall,
  createInitialState,
  interruptTiming,
  loadClockScenario,
  loadFixture,
  openDetail,
  openRecall,
  presentAnswer,
  recoverTiming,
  replayScenario,
  returnLive,
  scenarioSeed,
  setScroll,
  setTeam,
  tapCapture,
  tick,
} from '../src/model.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceText = ['index.html', 'styles.css', 'src/clock.js', 'src/fixtures.js', 'src/model.js', 'src/app.js']
  .map((relative) => readFileSync(path.join(root, relative), 'utf8'))
  .join('\n');

test('research capture controls record a tap and do not write a match record', () => {
  let state = createInitialState();
  const before = state.collection.participants.map((participant) => ({ ...participant }));
  for (const control of RESEARCH_CAPTURE_CONTROLS) {
    state = tapCapture(state, control.kind);
  }
  assert.equal(state.matchRecords, EMPTY_MATCH_RECORDS);
  assert.equal(state.matchRecords.length, 0);
  assert.equal(state.researchTaps.length, 4);
  assert.deepEqual(state.researchTaps.map((tap) => tap.kind), ['yellow', 'red', 'goal', 'substitution']);
  assert.ok(state.researchTaps.every((tap) => tap.researchOnly === true && tap.wroteMatchRecord === false));
  assert.deepEqual(state.collection.participants, before);
  assert.equal(state.researchOnly, true);
  assert.throws(() => state.matchRecords.push({ kind: 'yellow' }), TypeError);
  assert.throws(() => tapCapture(state, 'injury'));
});

test('instrument source does not perform durable writes', () => {
  assert.doesNotMatch(sourceText, /localStorage|indexedDB|DurableCommit|firebase|package:match_core|\bfetch\s*\(|XMLHttpRequest/i);
  assert.doesNotMatch(sourceText, /matchRecords\.push|matchRecords\s*=\s*\[/);
  assert.doesNotMatch(sourceText, /Date\.now|Math\.random/);
  assert.match(sourceText, /RESEARCH ONLY/);
  assert.match(sourceText, /data-research-only="true"/);
  assert.match(sourceText, /data-capture="\$\{control\.kind\}"/);
  assert.deepEqual(
    RESEARCH_CAPTURE_CONTROLS.map((control) => control.kind),
    ['yellow', 'red', 'goal', 'substitution'],
  );
  assert.match(sourceText, /aria-label="\$\{esc\(control\.label\)\}"/);
  const css = readFileSync(path.join(root, 'styles.css'), 'utf8');
  assert.match(css, /grid-template-columns:\s*86px 86px/);
  assert.match(css, /gap:\s*8px/);
  assert.match(css, /\.capture\s*\{[^}]*width:\s*86px;/s);
  assert.match(css, /\.capture\s*\{[^}]*height:\s*48px;/s);
  assert.match(css, /\.watch\s*\{[^}]*width:\s*228px;/s);
  assert.equal(RESEARCH_CAPTURE_GAP_PX, 8);
  assert.equal(WATCH_COLUMN_PX, 228);
});

test('MATCH and SHOOTOUT fixtures are independent collections', () => {
  const matchFixtures = [
    buildMatchNegativeD2(),
    buildMatchNegativeD6(),
    buildMatchNegativeD10(),
    buildMatchPositive(),
  ];
  const shootout = buildShootout();
  for (const match of matchFixtures) {
    assert.equal(match.scope, 'MATCH');
    assert.deepEqual(sharedParticipantIds(match, shootout), []);
    assert.equal(hasParticipant(match, 'HOME', 14) || match.id === 'match-positive-h14', match.id === 'match-positive-h14');
  }
  assert.equal(shootout.scope, 'SHOOTOUT');
  assert.equal(hasParticipant(shootout, 'HOME', 14), false);
  assert.equal(hasParticipant(buildMatchPositive(), 'HOME', 14), true);
  assert.notEqual(buildMatchNegativeD2().depth, buildMatchNegativeD10().depth);
  assert.deepEqual(sharedParticipantIds(buildMatchNegativeD2(), buildMatchNegativeD6()), []);
  assert.deepEqual(sharedParticipantIds(buildMatchNegativeD6(), buildMatchNegativeD10()), []);
  assert.deepEqual(sharedParticipantIds(buildMatchNegativeD10(), buildMatchPositive()), []);

  const match = createInitialState();
  const retitled = cloneCollection(match.collection);
  retitled.scope = 'SHOOTOUT';
  assert.throws(
    () => activateScope(match, retitled),
    /reuses participant ids/,
  );
});

test('MATCH → SHOOTOUT keeps historical MATCH inspectable and does not copy its cautions', () => {
  const state = replayScenario('matchToShootoutScope');
  assert.equal(state.scope, 'SHOOTOUT');
  assert.equal(state.collection.id, 'shootout-priors');
  assert.equal(state.historicalMatch.id, 'match-positive-h14');
  assert.deepEqual(sharedParticipantIds(state.collection, state.historicalMatch), []);
  const active = askStandingCaution(state, { team: 'HOME', number: 14, source: 'active' });
  const historical = askStandingCaution(state, { team: 'HOME', number: 14, source: 'historical-match' });
  assert.deepEqual(
    { certainty: active.certainty, answer: active.answer, basis: active.basis },
    { certainty: 'certain', answer: false, basis: 'absent' },
  );
  assert.deepEqual(
    { certainty: historical.certainty, answer: historical.answer, basis: historical.basis },
    { certainty: 'certain', answer: true, basis: 'present-with-standing-caution' },
  );
  const loaded = loadFixture(createInitialState(), 'shootout-priors');
  assert.equal(loaded.historicalMatch, null);
  assert.equal(loaded.scope, 'SHOOTOUT');
});

test('D10 deep-list navigation restores scroll, team, and inspected participant', () => {
  let state = loadFixture(createInitialState(), 'match-negative-d10');
  assert.equal(state.collection.participants.length, 10);
  state = openRecall(state);
  state = setTeam(state, 'ALL');
  state = setScroll(state, 240);
  state = openDetail(state, 'neg-d10-a-11', { scrollTop: 240 });
  assert.equal(state.screen, 'detail');
  state = backToRecall(state);
  assert.equal(state.screen, 'recall');
  assert.equal(state.recall.scrollTop, 240);
  assert.equal(state.recall.team, 'ALL');
  assert.equal(state.recall.inspectedParticipantId, 'neg-d10-a-11');

  state = setTeam(state, 'HOME');
  state = setScroll(state, 64);
  state = openDetail(state, 'neg-d10-h-10', { scrollTop: 64 });
  state = backToRecall(state);
  assert.equal(state.recall.scrollTop, 64);
  assert.equal(state.recall.team, 'HOME');
  assert.equal(state.recall.inspectedParticipantId, 'neg-d10-h-10');
});

test('detail returns to LIVE in one action', () => {
  let state = openRecall(loadFixture(createInitialState(), 'match-negative-d10'));
  state = openDetail(state, 'neg-d10-h-10', { scrollTop: 240 });
  const live = returnLive(state);
  assert.equal(live.screen, 'live');
  assert.notEqual(live.screen, 'recall');
  assert.equal(live.recall.inspectedParticipantId, 'neg-d10-h-10');
  assert.equal(live.recall.scrollTop, 240);
});

test('scenario sequences are deterministic and fail closed', () => {
  for (const name of SCENARIO_NAMES) {
    const first = replayScenario(name);
    const second = replayScenario(name);
    assert.equal(JSON.stringify(first), JSON.stringify(second));
    assert.equal(first.matchRecords.length, 0);
    assert.equal(first.scenarioTrace.name, name);
  }

  const admitted = replayScenario('durableCautionAdmission');
  assert.equal(
    admitted.collection.participants.find((participant) => participant.id === 'pos-h-14').admission,
    'd1',
  );
  assert.equal(askStandingCaution(admitted).answer, true);

  const failed = replayScenario('failedNotYetD1Caution');
  const target = failed.collection.participants.find((participant) => participant.id === 'pos-h-14');
  assert.equal(target.standingCaution, false);
  assert.equal(target.admission, 'not-d1');
  assert.deepEqual(askStandingCaution(failed), {
    ...askStandingCaution(failed),
    certainty: 'certain',
    answer: false,
    basis: 'present-without-standing-caution',
  });

  const removed = replayScenario('authoritativeSendOffRemoval');
  const sentOff = removed.collection.participants.find((participant) => participant.id === 'pos-h-8');
  assert.equal(sentOff.removed, true);
  assert.equal(askStandingCaution(removed, { team: 'HOME', number: 8 }).basis, 'absent');
  assert.equal(askStandingCaution(removed, { team: 'HOME', number: 14 }).answer, true);

  const uncertain = replayScenario('disciplinaryRecoveryUncertainty');
  const uncertainAnswer = askStandingCaution(uncertain);
  assert.equal(uncertain.collection.completeness, 'unverified');
  assert.equal(uncertainAnswer.certainty, 'unavailable');
  assert.equal(uncertainAnswer.answer, null);
  assert.equal(presentAnswer(uncertainAnswer).startsWith('Unavailable'), true);
  assert.doesNotMatch(presentAnswer(uncertainAnswer), /^No/);

  const positiveUncertain = applyTransition(
    loadFixture(createInitialState(), 'match-positive-h14'),
    'disciplinaryRecoveryUncertainty',
  );
  const hiddenYes = askStandingCaution(positiveUncertain);
  assert.equal(hiddenYes.certainty, 'unavailable');
  assert.equal(hiddenYes.answer, null);

  const restored = replayScenario('restorationOfVerifiedCompleteness');
  assert.equal(restored.collection.completeness, 'verified-complete');
  assert.equal(askStandingCaution(restored).basis, 'absent');
  const already = applyTransition(
    loadFixture(createInitialState(), 'match-negative-d10'),
    'restorationOfVerifiedCompleteness',
  );
  assert.equal(already.collection.completeness, 'verified-complete');
  assert.deepEqual(
    already.collection.participants.map((participant) => participant.id),
    scenarioSeed('restorationOfVerifiedCompleteness').collection.participants.map((participant) => participant.id),
  );

  const unavailable = loadFixture(createInitialState(), 'match-unavailable');
  const unavailableAnswer = askStandingCaution(unavailable);
  assert.equal(unavailableAnswer.certainty, 'unavailable');
  assert.equal(unavailableAnswer.answer, null);
  assert.equal(unavailableAnswer.basis, 'collection-not-verified-complete');
});

test('positive and negative HOME #14 verification fixtures', () => {
  const positive = loadFixture(createInitialState(), 'match-positive-h14');
  const yes = askStandingCaution(positive);
  assert.equal(yes.question, 'Does HOME #14 have a standing caution?');
  assert.equal(yes.certainty, 'certain');
  assert.equal(yes.answer, true);
  assert.equal(presentAnswer(yes), 'Yes — standing caution.');

  for (const name of ['match-negative-d2', 'match-negative-d6', 'match-negative-d10']) {
    const negative = loadFixture(createInitialState(), name);
    const no = askStandingCaution(negative);
    assert.equal(no.question, 'Does HOME #14 have a standing caution?');
    assert.equal(no.certainty, 'certain');
    assert.equal(no.answer, false);
    assert.equal(no.basis, 'absent');
    const expectedDepth = name.endsWith('d10') ? 'D10' : name.endsWith('d6') ? 'D6' : 'D2';
    assert.equal(negative.collection.depth, expectedDepth);
    assert.equal(hasParticipant(negative.collection, 'HOME', 14), false);
  }
  assert.equal(getFixture('match-negative-d2').depth, 'D2');
  assert.equal(getFixture('match-negative-d6').depth, 'D6');
  assert.equal(getFixture('match-negative-d10').depth, 'D10');
  assert.equal(getFixture('match-negative-d2').participants.length, 2);
  assert.equal(getFixture('match-negative-d6').participants.length, 6);
  assert.equal(getFixture('match-negative-d10').participants.length, 10);
});

test('advancing research clock crosses thresholds without changing phase', () => {
  assert.deepEqual(CLOCK_SCENARIO_NAMES, ['67:12', '44:58', '45+', '90+', '105+', '120+']);
  const expected = {
    '67:12': '67:12',
    '44:58': '44:58',
    '45+': '45:01',
    '90+': '90:01',
    '105+': '105:01',
    '120+': '120:01',
  };
  for (const [name, label] of Object.entries(expected)) {
    const reading = readClock(createClockScenario(name));
    assert.equal(reading.label, label);
    assert.equal(reading.phase, 'running-period');
    assert.equal(reading.authoritative, false);
    assert.equal(reading.semantics, FROZEN_TEMPORAL_SEMANTICS);
  }

  let clock = createClockScenario('44:58');
  clock = stepClock(clock, 2000);
  assert.equal(formatFootballClock(readClock(clock).totalSeconds), '45:00');
  assert.equal(readClock(clock).phase, 'running-period');
  clock = stepClock(clock, 1000);
  assert.equal(readClock(clock).label, '45:01');
  assert.equal(FROZEN_TEMPORAL_SEMANTICS.thresholdEndsPeriod, false);
  assert.equal(FROZEN_TEMPORAL_SEMANTICS.thresholdEndsMatch, false);
  assert.equal(FROZEN_TEMPORAL_SEMANTICS.overrunShiftsNextNominalBase, false);
  assert.equal(FROZEN_TEMPORAL_SEMANTICS.addedTimeIsNotASecondTimer, true);
  assert.equal(FROZEN_TEMPORAL_SEMANTICS.statements.length, 4);

  let state = loadClockScenario(createInitialState(), '67:12');
  state = tick(state, 1000);
  assert.equal(readClock(state.clock).label, '67:13');
  state = interruptTiming(state);
  state = tick(state, 5000);
  assert.equal(readClock(state.clock).label, '67:13');
  assert.equal(readClock(state.clock).interrupted, true);
  state = recoverTiming(state);
  state = tick(state, 2000);
  assert.equal(readClock(state.clock).label, '67:15');
  assert.equal(readClock(state.clock).phase, 'running-period');

  const late = readClock(createClockScenario('120+'));
  assert.equal(late.label, '120:01');
  assert.equal(late.phase, 'running-period');
});
