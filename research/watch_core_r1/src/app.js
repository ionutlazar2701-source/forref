// RESEARCH ONLY. Watch-face stimulus for WATCH CORE 002D.
// Yellow / Red / Goal / Substitution footprints do not write match records.

import { FROZEN_TEMPORAL_SEMANTICS } from './clock.js';
import {
  RESEARCH_CAPTURE_CONTROLS,
  SCENARIO_NAMES,
  askStandingCaution,
  backToRecall,
  createInitialState,
  interruptTiming,
  loadClockScenario,
  loadFixture,
  openDetail,
  openRecall,
  presentAnswer,
  projectClock,
  recoverTiming,
  replayScenario,
  returnLive,
  setInspection,
  setTeam,
  tapCapture,
  tick,
  visibleRoster,
  inspectedParticipant,
} from './model.js';

const FIXTURE_BUTTONS = [
  ['match-negative-d2', 'Negative D2'],
  ['match-negative-d6', 'Negative D6'],
  ['match-negative-d10', 'Negative D10'],
  ['match-positive-h14', 'Positive HOME #14'],
  ['shootout-priors', 'SHOOTOUT collection'],
  ['match-unavailable', 'Unavailable collection'],
];

const SCENARIO_LABELS = {
  durableCautionAdmission: 'Durable caution admission',
  failedNotYetD1Caution: 'Failed / not-yet-D1 caution',
  authoritativeSendOffRemoval: 'Authoritative send-off removal',
  disciplinaryRecoveryUncertainty: 'Disciplinary recovery uncertainty',
  restorationOfVerifiedCompleteness: 'Restore verified completeness',
  matchToShootoutScope: 'MATCH → SHOOTOUT',
};

const CLOCK_BUTTONS = ['67:12', '44:58', '45+', '90+', '105+', '120+'];

const app = document.querySelector('#app');
const bootStatus = document.querySelector('#boot-status');

let state = createInitialState();
let autoAdvance = true;

function esc(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function answerBlock(title, result, attr) {
  return `
    <section class="answer" data-answer-block="${attr}">
      <h2>${esc(title)}</h2>
      <p class="question">${esc(result.question)}</p>
      <p class="answer-text" data-${attr}-text>${esc(presentAnswer(result))}</p>
      <p class="meta" data-${attr}-certainty="${esc(result.certainty)}" data-${attr}-basis="${esc(result.basis)}">
        ${esc(result.certainty)} · ${esc(result.basis)}
        ${result.collectionId ? ` · ${esc(result.collectionId)}` : ''}
      </p>
    </section>`;
}

function captureButtons() {
  return RESEARCH_CAPTURE_CONTROLS.map((control) => `
    <button
      type="button"
      class="capture"
      data-action="tap-capture"
      data-capture="${control.kind}"
      data-research-only="true"
      aria-label="${esc(control.label)}"
    >${esc(control.label)}</button>`).join('');
}

function liveFace(clock) {
  return `
    <p class="research-mark">RESEARCH ONLY</p>
    <p class="clock" data-clock-label>${esc(clock.label)}</p>
    <p class="motion" data-clock-motion>${clock.interrupted ? 'Clock held' : 'Clock advancing'}</p>
    <p class="phase" data-clock-phase="${esc(clock.phase)}">Running period</p>
    <div class="capture-grid" data-capture-grid>
      ${captureButtons()}
    </div>
    <button type="button" class="recall-control" data-action="open-recall">Recall</button>
    <p class="footnote">Capture controls do not write a match record.</p>`;
}

function rosterRows(roster) {
  if (roster.withheld) {
    return `<p class="withheld" data-roster="withheld">Unverified collection. The roster is withheld so absence is not shown as a fact.</p>`;
  }
  if (roster.participants.length === 0) {
    return `<p class="withheld" data-roster="empty">Verified collection has no active participants in this team.</p>`;
  }
  return `
    <div class="recall-list" data-recall-list>
      ${roster.participants.map((participant) => `
        <button
          type="button"
          class="recall-row${participant.id === state.recall.inspectedParticipantId ? ' is-inspected' : ''}"
          data-action="open-detail"
          data-participant-id="${esc(participant.id)}"
        >
          <span>${esc(participant.team)} #${esc(participant.number)}</span>
          <span>${participant.standingCaution ? 'standing caution' : 'no standing caution'}</span>
        </button>`).join('')}
    </div>`;
}

function recallFace(roster) {
  const collection = roster.collection;
  const heading = collection
    ? `${collection.scope} · ${collection.depth} · ${collection.completeness}`
    : 'No collection';
  const teams = ['ALL', 'HOME', 'AWAY'].map((team) => `
    <button type="button" data-action="set-team" data-team="${team}" aria-pressed="${state.recall.team === team}">
      ${team}
    </button>`).join('');
  const historicalToggle = state.historicalMatch ? `
    <button type="button" data-action="set-inspection" data-inspection="active" aria-pressed="${state.recall.inspection === 'active'}">Active</button>
    <button type="button" data-action="set-inspection" data-inspection="historical-match" aria-pressed="${state.recall.inspection === 'historical-match'}">Historical MATCH</button>` : '';
  return `
    <p class="research-mark">RESEARCH ONLY</p>
    <p class="heading" data-recall-heading>${esc(heading)}</p>
    <p class="meta">Inspection: ${esc(state.recall.inspection)}</p>
    <div class="team-row">${teams}</div>
    <div class="team-row">${historicalToggle}</div>
    ${rosterRows(roster)}
    <button type="button" class="recall-control" data-action="return-live">LIVE</button>`;
}

function detailFace() {
  const participant = inspectedParticipant(state);
  const roster = visibleRoster(state);
  if (!participant || roster.withheld) {
    return `
      <p class="research-mark">RESEARCH ONLY</p>
      <p class="withheld">Participant detail is withheld.</p>
      <button type="button" class="recall-control" data-action="back-recall">Recall</button>
      <button type="button" class="recall-control" data-action="return-live">LIVE</button>`;
  }
  const caution = participant.standingCaution && participant.admission === 'd1'
    ? 'Yes — standing caution.'
    : participant.admission === 'not-d1'
      ? 'No — present without a standing caution. Admission is not D1.'
      : 'No — present without a standing caution.';
  return `
    <p class="research-mark">RESEARCH ONLY</p>
    <p class="clock detail-id">${esc(participant.team)} #${esc(participant.number)}</p>
    <p data-detail-source>Source: ${esc(state.recall.inspection)}</p>
    <p data-detail-caution>${esc(caution)}</p>
    <button type="button" class="recall-control" data-action="back-recall">Recall</button>
    <button type="button" class="recall-control" data-action="return-live">LIVE</button>`;
}

function face(clock) {
  if (state.screen === 'recall') return recallFace(visibleRoster(state));
  if (state.screen === 'detail') return detailFace();
  return liveFace(clock);
}

function studyRail(clock, activeAnswer, historicalAnswer) {
  const taps = state.researchTaps.length === 0
    ? '<li data-tap-log="empty">No research taps.</li>'
    : state.researchTaps.map((tap) => `
        <li data-tap-kind="${esc(tap.kind)}" data-wrote-match-record="${tap.wroteMatchRecord}">
          ${esc(tap.kind)} — no match record
        </li>`).join('');
  const trace = state.scenarioTrace
    ? `<p data-scenario-trace="${esc(state.scenarioTrace.name)}">${esc(SCENARIO_LABELS[state.scenarioTrace.name])} replayed. Scope ${esc(state.scenarioTrace.after.scope)}. Completeness ${esc(state.scenarioTrace.after.completeness)}.</p>`
    : '<p data-scenario-trace="">No scenario replayed.</p>';
  return `
    <section class="rail">
      <h1>002D research instrument</h1>
      <p class="meta">Match records: ${state.matchRecords.length}. Research only.</p>
      ${answerBlock('Active collection', activeAnswer, 'active')}
      ${answerBlock('Historical MATCH', historicalAnswer, 'historical')}
      <h2>Verification fixtures</h2>
      <div class="button-row">
        ${FIXTURE_BUTTONS.map(([name, label]) => `
          <button type="button" data-action="load-fixture" data-fixture="${esc(name)}">${esc(label)}</button>`).join('')}
      </div>
      <h2>Scenario sequences</h2>
      <div class="button-row">
        ${SCENARIO_NAMES.map((name) => `
          <button type="button" data-action="replay-scenario" data-scenario="${esc(name)}">${esc(SCENARIO_LABELS[name])}</button>`).join('')}
      </div>
      ${trace}
      <h2>Research clock</h2>
      <div class="button-row">
        ${CLOCK_BUTTONS.map((name) => `
          <button type="button" data-action="load-clock" data-clock-scenario="${esc(name)}">${esc(name)}</button>`).join('')}
        <button type="button" data-action="step-clock">Step 1s</button>
        <button type="button" data-action="interrupt-clock">Interrupt</button>
        <button type="button" data-action="recover-clock">Recover</button>
      </div>
      <ul class="semantics">
        ${FROZEN_TEMPORAL_SEMANTICS.statements.map((statement) => `<li>${esc(statement)}</li>`).join('')}
      </ul>
      <p class="meta" data-clock-seconds="${clock.totalSeconds}">Displayed ${esc(clock.label)}. Phase ${esc(clock.phase)}. Authority: none.</p>
      <h2>Research tap log</h2>
      <ul data-tap-log>${taps}</ul>
    </section>`;
}

function render() {
  const clock = projectClock(state);
  const activeAnswer = askStandingCaution(state, { team: 'HOME', number: 14, source: 'active' });
  const historicalAnswer = askStandingCaution(state, {
    team: 'HOME',
    number: 14,
    source: 'historical-match',
  });
  app.innerHTML = `
    <div class="layout">
      <section class="watch" data-screen="${esc(state.screen)}" data-research-only="true">
        ${face(clock)}
      </section>
      ${studyRail(clock, activeAnswer, historicalAnswer)}
    </div>`;
  const list = app.querySelector('[data-recall-list]');
  if (list) {
    list.addEventListener('scroll', () => {
      state = {
        ...state,
        recall: { ...state.recall, scrollTop: list.scrollTop },
      };
    });
    list.scrollTop = state.recall.scrollTop;
  }
}

function paintClock() {
  const clock = projectClock(state);
  const label = app.querySelector('[data-clock-label]');
  const motion = app.querySelector('[data-clock-motion]');
  const seconds = app.querySelector('[data-clock-seconds]');
  if (label) label.textContent = clock.label;
  if (motion) motion.textContent = clock.interrupted ? 'Clock held' : 'Clock advancing';
  if (seconds) {
    seconds.dataset.clockSeconds = String(clock.totalSeconds);
    seconds.textContent = `Displayed ${clock.label}. Phase ${clock.phase}. Authority: none.`;
  }
}

app.addEventListener('click', (event) => {
  const button = event.target.closest('[data-action]');
  if (!button || !app.contains(button)) return;
  const action = button.dataset.action;
  if (action === 'tap-capture') state = tapCapture(state, button.dataset.capture);
  else if (action === 'open-recall') state = openRecall(state);
  else if (action === 'return-live') state = returnLive(state);
  else if (action === 'back-recall') state = backToRecall(state);
  else if (action === 'set-team') state = setTeam(state, button.dataset.team);
  else if (action === 'set-inspection') state = setInspection(state, button.dataset.inspection);
  else if (action === 'open-detail') {
    const list = app.querySelector('[data-recall-list]');
    state = openDetail(state, button.dataset.participantId, {
      scrollTop: list ? list.scrollTop : state.recall.scrollTop,
    });
  } else if (action === 'load-fixture') state = loadFixture(state, button.dataset.fixture);
  else if (action === 'replay-scenario') state = replayScenario(button.dataset.scenario);
  else if (action === 'load-clock') state = loadClockScenario(state, button.dataset.clockScenario);
  else if (action === 'step-clock') state = tick(state, 1000);
  else if (action === 'interrupt-clock') state = interruptTiming(state);
  else if (action === 'recover-clock') state = recoverTiming(state);
  else return;
  render();
});

window.__research = {
  getState: () => state,
  tap: (kind) => {
    state = tapCapture(state, kind);
    render();
  },
  replay: (name) => {
    state = replayScenario(name);
    render();
  },
  loadFixture: (name) => {
    state = loadFixture(state, name);
    render();
  },
  ask: (source = 'active') => askStandingCaution(state, { team: 'HOME', number: 14, source }),
  openRecall: () => {
    state = openRecall(state);
    render();
  },
  openDetail: (participantId, scrollTop) => {
    state = openDetail(state, participantId, { scrollTop });
    render();
  },
  setTeam: (team) => {
    state = setTeam(state, team);
    render();
  },
  setScroll: (scrollTop) => {
    const list = app.querySelector('[data-recall-list]');
    if (!list) throw new Error('recall list is not on screen');
    list.scrollTop = scrollTop;
    state = { ...state, recall: { ...state.recall, scrollTop: list.scrollTop } };
  },
  backToRecall: () => {
    state = backToRecall(state);
    render();
  },
  returnLive: () => {
    state = returnLive(state);
    render();
  },
  loadClock: (name) => {
    state = loadClockScenario(state, name);
    render();
  },
  step: (deltaMs) => {
    state = tick(state, deltaMs);
    render();
  },
  interrupt: () => {
    state = interruptTiming(state);
    render();
  },
  recover: () => {
    state = recoverTiming(state);
    render();
  },
  readClock: () => projectClock(state),
  setAutoAdvance: (value) => {
    autoAdvance = Boolean(value);
  },
};

render();
bootStatus.textContent = 'booted';

window.setInterval(() => {
  if (!autoAdvance || state.clock.interrupted) return;
  const before = state.clock.elapsedMs;
  state = tick(state, 1000);
  if (state.clock.elapsedMs === before) return;
  if (state.screen === 'live') paintClock();
  else {
    const seconds = app.querySelector('[data-clock-seconds]');
    if (seconds) {
      const clock = projectClock(state);
      seconds.dataset.clockSeconds = String(clock.totalSeconds);
      seconds.textContent = `Displayed ${clock.label}. Phase ${clock.phase}. Authority: none.`;
    }
  }
}, 1000);
