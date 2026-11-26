// Display cadence only. Elapsed time stays on the UTC anchor.
// One foreground timer paints Live. A second 1000 ms timer can land on the
// opposite phase after sleep or navigation and then keep painting every 2 s.

export function displayedSeconds(text) {
  if (!text || text.indexOf("—") >= 0) {
    return null;
  }
  let body = text;
  let extra = 0;
  const plus = text.indexOf("+");
  if (plus >= 0) {
    const mark = parseInt(text.slice(0, plus).trim(), 10);
    if (!isFinite(mark)) {
      return null;
    }
    extra = mark * 60;
    body = text.slice(plus + 1).trim();
  }
  const cut = body.indexOf(":");
  if (cut < 0) {
    return null;
  }
  const minutes = parseInt(body.slice(0, cut), 10);
  const seconds = parseInt(body.slice(cut + 1), 10);
  if (!isFinite(minutes) || !isFinite(seconds)) {
    return null;
  }
  return extra + minutes * 60 + seconds;
}

export function noteCadence(previous, current) {
  const dt = previous && previous.utc != null && current.utc != null ? current.utc - previous.utc : null;
  const prevSec = displayedSeconds(previous && previous.digits);
  const nowSec = displayedSeconds(current.digits);
  const step = prevSec == null || nowSec == null ? null : nowSec - prevSec;
  return {
    utc: current.utc,
    dt: dt,
    prevDigits: previous && previous.digits ? previous.digits : "",
    digits: current.digits || "",
    step: step,
    prepareMs: current.prepareMs,
    commitMs: current.commitMs,
    paintMs: current.paintMs,
  };
}

export function formatCadence(row) {
  return (
    "FORREF_CLOCK_CADENCE utc=" +
    row.utc +
    " dt=" +
    (row.dt == null ? "" : row.dt) +
    " prev=" +
    (row.prevDigits || "") +
    " now=" +
    (row.digits || "") +
    " step=" +
    (row.step == null ? "" : row.step) +
    " prepareMs=" +
    row.prepareMs +
    " commitMs=" +
    (row.commitMs == null ? "" : row.commitMs) +
    " paintMs=" +
    row.paintMs +
    " timers=1"
  );
}

export function classifyCadence(rows) {
  const timed = [];
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].dt != null) {
      timed.push(rows[i]);
    }
  }
  if (timed.length < 4) {
    return "SHORT";
  }
  let slow = 0;
  let skipped = 0;
  let healthy = 0;
  for (let i = 0; i < timed.length; i++) {
    const row = timed[i];
    if (row.dt >= 1500 && row.dt <= 2600 && row.step != null && row.step >= 2) {
      slow += 1;
    } else if (row.dt >= 700 && row.dt <= 1400 && row.step != null && row.step >= 2) {
      skipped += 1;
    } else if (row.dt >= 700 && row.dt <= 1400 && row.step === 1) {
      healthy += 1;
    }
  }
  if (slow >= timed.length - 1) {
    return "CALLBACK_2S";
  }
  if (skipped >= timed.length - 1) {
    return "RENDER_SKIP";
  }
  if (healthy >= timed.length - 1) {
    return "ONE_SECOND";
  }
  return "MIXED";
}

// Two independent 1000 ms timers that wake on opposite phases.
// Only the paint timer changes the digits, so the face steps by 2 s
// and stays there until the timers are created again on the same phase.
export function oppositePhaseGaps(period, ticks) {
  const gaps = [];
  for (let i = 1; i < ticks; i++) {
    gaps.push(period * 2);
  }
  return gaps;
}

// First wake lands on the next UTC second. The repeat stays one second.
// A delay under 80 ms waits one more second so two paints do not share a second.
export function nextTimerDelay(utc, period) {
  const span = period || 1000;
  if (utc == null || !isFinite(utc)) {
    return span;
  }
  const remain = span - (utc % span);
  if (remain < 80) {
    return remain + span;
  }
  return remain;
}

export function createForegroundHost(io) {
  let timerId = null;
  let listener = null;
  let previous = null;

  function tick() {
    const utc = io.utc ? io.utc() : io.now();
    const started = io.now();
    let sampled = null;
    try {
      sampled = io.sample("fg");
    } catch (err) {
      io.log("FORREF_CLOCK_FG src=fg reason=UNAVAILABLE");
      return;
    }
    const sampleMs = io.now() - started;
    const commitMs = sampled && sampled.commitMs != null ? sampled.commitMs : null;
    const paintStarted = io.now();
    let digits = sampled && sampled.digits ? sampled.digits : "";
    let paintMs = 0;
    if (listener) {
      const painted = listener(sampled);
      if (painted && painted.digits != null) {
        digits = painted.digits;
      }
      paintMs = painted && painted.paintMs != null ? painted.paintMs : io.now() - paintStarted;
    }
    const current = {
      utc: utc,
      digits: digits,
      prepareMs: commitMs == null ? sampleMs : sampleMs - commitMs,
      commitMs: commitMs,
      paintMs: paintMs,
    };
    const row = noteCadence(previous, current);
    previous = current;
    io.log(formatCadence(row));
  }

  function start() {
    if (timerId != null) {
      return timerId;
    }
    const delay = io.delay ? io.delay() : 1000;
    timerId = io.arm(tick, delay);
    io.log("FORREF_CLOCK_FG timer=on");
    return timerId;
  }

  function stop() {
    if (timerId == null) {
      return true;
    }
    try {
      io.disarm(timerId);
    } catch (err) {
      io.log("FORREF_CLOCK_FG timer-stop=fail");
      return false;
    }
    timerId = null;
    io.log("FORREF_CLOCK_FG timer=off");
    return true;
  }

  function restart() {
    if (!stop()) {
      return timerId;
    }
    return start();
  }

  function bind(fn) {
    listener = fn;
    return function () {
      if (listener === fn) {
        listener = null;
      }
    };
  }

  return {
    start: start,
    stop: stop,
    restart: restart,
    bind: bind,
    tick: tick,
    id: function () {
      return timerId;
    },
  };
}
