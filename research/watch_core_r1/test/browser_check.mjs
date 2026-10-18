// RESEARCH ONLY. Headless browser pass for the validation instrument.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const port = 8765;
const debugPort = 9333;
const artifactDir = '/opt/cursor/artifacts';

function contentType(filePath) {
  if (filePath.endsWith('.html')) return 'text/html; charset=utf-8';
  if (filePath.endsWith('.css')) return 'text/css; charset=utf-8';
  if (filePath.endsWith('.js') || filePath.endsWith('.mjs')) return 'text/javascript; charset=utf-8';
  return 'text/plain; charset=utf-8';
}

function startServer() {
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    const relative = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname).replace(/^\/+/, '');
    const filePath = path.join(root, relative);
    if (!filePath.startsWith(root)) {
      response.writeHead(403);
      response.end('forbidden');
      return;
    }
    import('node:fs').then((fs) => {
      fs.readFile(filePath, (error, data) => {
        if (error) {
          response.writeHead(404);
          response.end('not found');
          return;
        }
        response.writeHead(200, { 'content-type': contentType(filePath) });
        response.end(data);
      });
    });
  });
  return new Promise((resolve) => {
    server.listen(port, '127.0.0.1', () => resolve(server));
  });
}

async function waitForJson(url) {
  const started = Date.now();
  while (Date.now() - started < 15000) {
    try {
      const response = await fetch(url);
      if (response.ok) return response.json();
    } catch {
      // Chrome is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`timed out waiting for ${url}`);
}

function send(socket, method, params = {}) {
  const id = send.nextId++;
  return new Promise((resolve, reject) => {
    const onMessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.id !== id) return;
      socket.removeEventListener('message', onMessage);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    };
    socket.addEventListener('message', onMessage);
    socket.send(JSON.stringify({ id, method, params }));
  });
}
send.nextId = 1;

const pageScript = `(() => {
  window.__research.setAutoAdvance(false);
  const result = { boot: document.querySelector('#boot-status').textContent };
  const watch = document.querySelector('.watch').getBoundingClientRect();
  result.watchWidth = watch.width;
  result.captures = [...document.querySelectorAll('[data-capture]')].map((element) => {
    const box = element.getBoundingClientRect();
    return {
      kind: element.dataset.capture,
      researchOnly: element.dataset.researchOnly,
      label: element.getAttribute('aria-label'),
      width: box.width,
      height: box.height,
    };
  });
  const boxes = [...document.querySelectorAll('[data-capture]')].map((element) => element.getBoundingClientRect());
  result.gapX = boxes[1].left - boxes[0].right;
  result.gapY = boxes[2].top - boxes[0].bottom;
  const recallBox = document.querySelector('[data-action="open-recall"]').getBoundingClientRect();
  result.recallGap = recallBox.top - boxes[2].bottom;
  for (const kind of ['yellow', 'red', 'goal', 'substitution']) window.__research.tap(kind);
  const tapped = window.__research.getState();
  result.tapCount = tapped.researchTaps.length;
  result.matchRecords = tapped.matchRecords.length;
  result.wrote = tapped.researchTaps.map((tap) => tap.wroteMatchRecord);

  window.__research.loadFixture('match-negative-d10');
  window.__research.setTeam('ALL');
  window.__research.openRecall();
  window.__research.setScroll(240);
  const list = document.querySelector('[data-recall-list]');
  result.scrollSet = list.scrollTop;
  result.rowCount = list.querySelectorAll('[data-participant-id]').length;
  window.__research.openDetail('neg-d10-a-11', list.scrollTop);
  result.detailScreen = window.__research.getState().screen;
  result.liveControlsOnDetail = document.querySelectorAll('[data-action="return-live"]').length;
  window.__research.backToRecall();
  const restored = document.querySelector('[data-recall-list]');
  result.scrollRestored = restored.scrollTop;
  result.team = window.__research.getState().recall.team;
  result.inspected = window.__research.getState().recall.inspectedParticipantId;
  result.inspectedMarked = document.querySelector('[data-participant-id="neg-d10-a-11"]').classList.contains('is-inspected');
  window.__research.openDetail('neg-d10-a-11', restored.scrollTop);
  document.querySelector('[data-action="return-live"]').click();
  result.screenAfterOneLiveAction = document.querySelector('.watch').dataset.screen;

  window.__research.replay('disciplinaryRecoveryUncertainty');
  window.__research.openRecall();
  result.uncertainRoster = document.querySelector('[data-roster]')?.dataset.roster ?? null;
  result.uncertainText = document.querySelector('[data-active-text]').textContent;

  result.scenarios = {};
  for (const name of [
    'durableCautionAdmission',
    'failedNotYetD1Caution',
    'authoritativeSendOffRemoval',
    'disciplinaryRecoveryUncertainty',
    'restorationOfVerifiedCompleteness',
    'matchToShootoutScope',
  ]) {
    window.__research.replay(name);
    const active = window.__research.ask('active');
    const historical = window.__research.ask('historical-match');
    result.scenarios[name] = {
      scope: window.__research.getState().scope,
      records: window.__research.getState().matchRecords.length,
      completeness: active.completeness,
      active: { certainty: active.certainty, answer: active.answer, basis: active.basis },
      historical: { certainty: historical.certainty, answer: historical.answer, basis: historical.basis },
      trace: document.querySelector('[data-scenario-trace]').dataset.scenarioTrace,
    };
  }

  result.verification = {};
  for (const name of ['match-positive-h14', 'match-negative-d2', 'match-negative-d6', 'match-negative-d10']) {
    window.__research.loadFixture(name);
    const answer = window.__research.ask('active');
    result.verification[name] = {
      depth: answer.depth,
      certainty: answer.certainty,
      answer: answer.answer,
      basis: answer.basis,
      text: document.querySelector('[data-active-text]').textContent,
    };
  }
  window.__research.loadFixture('match-unavailable');
  result.unavailableText = document.querySelector('[data-active-text]').textContent;

  window.__research.loadClock('44:58');
  result.at4458 = window.__research.readClock().label;
  window.__research.step(2000);
  result.at4500 = {
    label: window.__research.readClock().label,
    phase: window.__research.readClock().phase,
  };
  window.__research.step(1000);
  result.at4501 = window.__research.readClock().label;
  result.clocks = {};
  for (const name of ['67:12', '45+', '90+', '105+', '120+']) {
    window.__research.loadClock(name);
    const reading = window.__research.readClock();
    result.clocks[name] = { label: reading.label, phase: reading.phase, authoritative: reading.authoritative };
  }
  window.__research.loadClock('67:12');
  window.__research.step(1000);
  window.__research.interrupt();
  window.__research.step(5000);
  result.held = window.__research.readClock().label;
  window.__research.recover();
  window.__research.step(2000);
  result.recovered = window.__research.readClock().label;
  result.semantics = document.querySelectorAll('.semantics li').length;
  result.clockLabels = document.querySelectorAll('[data-clock-label]').length;
  result.errors = [...window.__researchErrors];
  return result;
})()`;

function assertBrowser(result) {
  const failures = [];
  const check = (name, condition) => {
    if (!condition) failures.push(name);
  };
  check('booted', result.boot === 'booted');
  check('watch width', result.watchWidth === 228);
  check('four captures', result.captures.length === 4);
  for (const capture of result.captures) {
    check(`${capture.kind} research only`, capture.researchOnly === 'true');
    check(`${capture.kind} 86px`, capture.width === 86);
    check(`${capture.kind} 48px`, capture.height === 48);
  }
  check('labels', result.captures.map((capture) => capture.label).join(',') === 'Yellow,Red,Goal,Substitution');
  check('horizontal gap', Math.abs(result.gapX - 8) < 0.5);
  check('vertical gap', Math.abs(result.gapY - 8) < 0.5);
  check('recall gap', Math.abs(result.recallGap - 8) < 0.5);
  check('no writes', result.matchRecords === 0 && result.tapCount === 4 && result.wrote.every((wrote) => wrote === false));
  check('d10 rows', result.rowCount === 10);
  check('scroll set', result.scrollSet === 240);
  check('detail', result.detailScreen === 'detail' && result.liveControlsOnDetail === 1);
  check('scroll restored', result.scrollRestored === 240 && result.team === 'ALL' && result.inspected === 'neg-d10-a-11' && result.inspectedMarked === true);
  check('one live action', result.screenAfterOneLiveAction === 'live');
  check('uncertain withheld', result.uncertainRoster === 'withheld' && result.uncertainText.startsWith('Unavailable'));
  check('durable yes', result.scenarios.durableCautionAdmission.active.answer === true && result.scenarios.durableCautionAdmission.records === 0);
  check('not d1', result.scenarios.failedNotYetD1Caution.active.basis === 'present-without-standing-caution');
  check('send off', result.scenarios.authoritativeSendOffRemoval.records === 0);
  check('uncertainty fail closed', result.scenarios.disciplinaryRecoveryUncertainty.active.certainty === 'unavailable' && result.scenarios.disciplinaryRecoveryUncertainty.active.answer === null);
  check('restored absent', result.scenarios.restorationOfVerifiedCompleteness.active.basis === 'absent');
  const shootout = result.scenarios.matchToShootoutScope;
  check('shootout split', shootout.scope === 'SHOOTOUT' && shootout.active.basis === 'absent' && shootout.historical.answer === true && shootout.records === 0);
  check('positive', result.verification['match-positive-h14'].text === 'Yes — standing caution.');
  for (const name of ['match-negative-d2', 'match-negative-d6', 'match-negative-d10']) {
    check(name, result.verification[name].basis === 'absent' && result.verification[name].text.startsWith('No — absent'));
  }
  check('unavailable', result.unavailableText.startsWith('Unavailable'));
  check('threshold', result.at4458 === '44:58' && result.at4500.label === '45:00' && result.at4500.phase === 'running-period' && result.at4501 === '45:01');
  check('67:12', result.clocks['67:12'].label === '67:12' && result.clocks['67:12'].authoritative === false);
  check('overruns', result.clocks['45+'].label === '45:01' && result.clocks['90+'].label === '90:01' && result.clocks['105+'].label === '105:01' && result.clocks['120+'].label === '120:01');
  check('phases', Object.values(result.clocks).every((reading) => reading.phase === 'running-period'));
  check('interrupt', result.held === '67:13' && result.recovered === '67:15');
  check('semantics', result.semantics === 4 && result.clockLabels === 1);
  check('js errors', result.errors.length === 0);
  return failures;
}

const server = await startServer();
const chrome = spawn('/usr/local/bin/google-chrome', [
  '--headless=new',
  '--no-sandbox',
  '--disable-gpu',
  '--disable-dev-shm-usage',
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=/tmp/r1-chrome-${debugPort}`,
  'about:blank',
], { stdio: 'ignore' });

try {
  await waitForJson(`http://127.0.0.1:${debugPort}/json/version`);
  const targetResponse = await fetch(`http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent(`http://127.0.0.1:${port}/`)}`, { method: 'PUT' });
  if (!targetResponse.ok) throw new Error(`unable to open tab: ${targetResponse.status}`);
  const target = await targetResponse.json();
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  await send(socket, 'Page.enable');
  await send(socket, 'Runtime.enable');
  await new Promise((resolve) => {
    const timeout = setTimeout(resolve, 3000);
    socket.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.method === 'Page.loadEventFired') {
        clearTimeout(timeout);
        resolve();
      }
    });
  });
  const boot = await send(socket, 'Runtime.evaluate', {
    expression: `document.querySelector('#boot-status') && document.querySelector('#boot-status').textContent`,
    returnByValue: true,
  });
  if (boot.result.value !== 'booted') {
    throw new Error(`page did not boot: ${JSON.stringify(boot)}`);
  }
  const evaluated = await send(socket, 'Runtime.evaluate', {
    expression: pageScript,
    returnByValue: true,
  });
  if (evaluated.exceptionDetails) {
    throw new Error(JSON.stringify(evaluated.exceptionDetails));
  }
  const result = evaluated.result.value;
  mkdirSync(artifactDir, { recursive: true });
  writeFileSync(path.join(artifactDir, 'browser_check.json'), `${JSON.stringify(result, null, 2)}\n`);
  const shot = await send(socket, 'Page.captureScreenshot', { format: 'png' });
  writeFileSync(path.join(artifactDir, 'research-instrument-after-checks.png'), Buffer.from(shot.data, 'base64'));
  socket.close();
  const failures = assertBrowser(result);
  if (failures.length > 0) {
    console.error(JSON.stringify(result, null, 2));
    throw new Error(`browser checks failed: ${failures.join('; ')}`);
  }
  console.log('browser checks passed');
  console.log(JSON.stringify({
    watchWidth: result.watchWidth,
    captures: result.captures,
    gaps: { x: result.gapX, y: result.gapY, recall: result.recallGap },
    scroll: { set: result.scrollSet, restored: result.scrollRestored, team: result.team, inspected: result.inspected },
    screenAfterOneLiveAction: result.screenAfterOneLiveAction,
    uncertainText: result.uncertainText,
    verification: result.verification,
    clocks: result.clocks,
    threshold: { at4458: result.at4458, at4500: result.at4500, at4501: result.at4501, held: result.held, recovered: result.recovered },
    errors: result.errors,
  }, null, 2));
} finally {
  chrome.kill('SIGTERM');
  server.close();
}
