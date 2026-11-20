// SDK-facing lifecycle for the background sampler.
// queryPermission is synchronous and returns Array<number>.
// stop confirms success before the local running flag is cleared.
// A tick, a relaunch, and a permission code are not match time.

import { Trust, isRunning } from "./match_clock.js";
import { startClass } from "./clock_sleep_evidence.js";

export const PERMISSION = "device:os.bg_service";
export const SERVICE_FILE = "app-service/clock_service";

export function screenLabel(settings) {
  const status = settings && settings.screen ? settings.screen.status : null;
  if (status === 1) {
    return "on";
  }
  if (status === 2) {
    return "off";
  }
  return "unknown";
}

function permissionCode(result) {
  if (!Array.isArray(result) || typeof result[0] !== "number") {
    return null;
  }
  return result[0];
}

function listed(value) {
  if (!Array.isArray(value)) {
    return false;
  }
  for (let i = 0; i < value.length; i += 1) {
    const item = value[i];
    if (item === SERVICE_FILE) {
      return true;
    }
    if (item && item.file === SERVICE_FILE) {
      return true;
    }
  }
  return false;
}

export function createServiceHost(sdk, log) {
  const emit = typeof log === "function" ? log : function (line) {
    console.log(line);
  };
  let running = false;
  let requestPending = false;
  let blocked = false;
  let absentNoted = 0;
  let restarts = 0;
  let published = "";

  function line(text) {
    try {
      emit("FORREF_CLOCK_SLEEP " + text);
    } catch (err) {
      // A log failure must not change the clock.
    }
  }

  function enumerate() {
    if (!sdk || typeof sdk.getAllAppServices !== "function") {
      line("services=unavailable");
      return null;
    }
    try {
      const value = sdk.getAllAppServices();
      if (!Array.isArray(value)) {
        line("services=invalid");
        return null;
      }
      const names = value.map(function (item) {
        return item && item.file ? item.file : String(item);
      });
      line("services=" + (names.length ? names.join(",") : "none"));
      return value;
    } catch (err) {
      line("services=unavailable");
      return null;
    }
  }

  function launch() {
    if (running) {
      return;
    }
    let code;
    let sawCallback = false;
    try {
      code = sdk.start({
        file: SERVICE_FILE,
        param: "",
        reload: false,
        complete_func: function (option) {
          sawCallback = true;
          const ok = !!(option && option.result === true);
          line("start-cb=" + (ok ? "true" : "false"));
          if (ok) {
            running = true;
          } else if (code === 0 || code === true) {
            running = true;
          } else {
            running = false;
          }
        },
      });
    } catch (err) {
      line("start=unavailable");
      return;
    }
    line("start-code=" + code + " start-class=" + startClass(code));
    if (!sawCallback && (code === 0 || code === true)) {
      running = true;
    }
  }

  function halt(why) {
    const value = enumerate();
    const present = value != null && listed(value);
    if (!running && !present) {
      return;
    }
    line("stop-reason=" + (why || "unspecified") + " listed=" + present);
    let code;
    let sawCallback = false;
    try {
      code = sdk.stop({
        file: SERVICE_FILE,
        complete_func: function (option) {
          sawCallback = true;
          const ok = !!(option && option.result === true);
          line("stop-cb=" + (ok ? "true" : "false"));
          if (ok || code === 0 || code === true) {
            running = false;
          }
        },
      });
    } catch (err) {
      line("stop=unavailable");
      return;
    }
    line("stop-code=" + code);
    if (!sawCallback && (code === 0 || code === true)) {
      running = false;
    }
  }

  function ask() {
    requestPending = true;
    let code;
    let sawCallback = false;
    try {
      code = sdk.requestPermission({
        permissions: [PERMISSION],
        callback: function (result) {
          sawCallback = true;
          requestPending = false;
          const status = permissionCode(result);
          line("request-cb=" + status);
          if (status === 2) {
            launch();
            return;
          }
          blocked = true;
          line("perm=denied");
        },
      });
    } catch (err) {
      requestPending = false;
      line("request=unavailable");
      return;
    }
    line("request=" + code);
    if (code === 2 && !sawCallback) {
      requestPending = false;
      launch();
    } else if (code === 1) {
      requestPending = false;
      blocked = true;
      line("perm=denied");
    } else if (code !== 0 && !sawCallback) {
      requestPending = false;
      line("request=unexpected");
    }
  }

  function ensure() {
    if (blocked || requestPending) {
      return;
    }
    const value = enumerate();
    if (value == null) {
      if (running) {
        return;
      }
    } else if (listed(value)) {
      running = true;
      absentNoted = 0;
      return;
    } else if (running) {
      absentNoted += 1;
      line("services=absent count=" + absentNoted);
      if (absentNoted < 2) {
        return;
      }
      running = false;
      absentNoted = 0;
      restarts += 1;
      if (restarts > 3) {
        blocked = true;
        line("services=gave-up");
        return;
      }
      line("services=restart");
    }
    let queried;
    try {
      queried = sdk.queryPermission({ permissions: [PERMISSION] });
    } catch (err) {
      line("perm=unavailable");
      return;
    }
    const status = permissionCode(queried);
    line("perm=" + status);
    if (status === 2) {
      launch();
      return;
    }
    if (status === 0) {
      ask();
      return;
    }
    blocked = true;
    line("perm=unknown");
  }

  function publish() {
    const next = String(running) + ":" + String(requestPending) + ":" + String(blocked);
    if (next === published) {
      return;
    }
    published = next;
    line("host running=" + running + " pending=" + requestPending + " blocked=" + blocked);
  }

  return {
    sync: function (session) {
      const needed = !!(session && isRunning(session.phase) && session.trust !== Trust.UNVERIFIED);
      if (!needed) {
        const why = !session ? "none" : session.trust === Trust.UNVERIFIED ? "unverified" : "phase";
        halt(why + " phase=" + (session ? session.phase : "") + " trust=" + (session ? session.trust : ""));
        publish();
        return;
      }
      ensure();
      publish();
    },
    snapshot: function () {
      return {
        running: running,
        requestPending: requestPending,
        blocked: blocked,
      };
    },
  };
}
