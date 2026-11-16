// Classifies watch filesystem results for the provisional journal.
// A missing file is empty. Any other stat or read failure stays unverified.

export function isAbsentFileError(err) {
  if (!err) {
    return false;
  }
  if (err.code === "ENOENT") {
    return true;
  }
  const text = String(err.message || err);
  return /not found|no such file|not exist|enoent/i.test(text);
}

function unverified(code, err) {
  const wrapped = new Error(code);
  wrapped.code = code;
  wrapped.cause = err;
  return wrapped;
}

export function readCaptureJournal(io) {
  let stat;
  try {
    stat = io.stat();
  } catch (err) {
    if (isAbsentFileError(err)) {
      return { status: "absent", bytes: "" };
    }
    throw unverified("UNVERIFIED_STAT", err);
  }
  if (stat == null) {
    return { status: "absent", bytes: "" };
  }
  if (typeof stat.size !== "number" || !isFinite(stat.size) || stat.size < 0) {
    throw unverified("UNVERIFIED_STAT", new Error("stat size"));
  }
  if (stat.size === 0) {
    return { status: "empty", bytes: "" };
  }
  let fd = null;
  try {
    fd = io.open();
    const read = io.read(fd, stat.size);
    if (!read || read.length !== stat.size || typeof read.text !== "string" || read.text.length !== stat.size) {
      throw unverified("UNVERIFIED_READ", new Error("short read"));
    }
    const closed = io.close(fd);
    fd = null;
    if (closed !== 0 && closed != null) {
      throw unverified("UNVERIFIED_READ", new Error("close"));
    }
    return { status: "ok", bytes: read.text };
  } catch (err) {
    if (fd != null) {
      try {
        io.close(fd);
      } catch (ignore) {
        // The read is already unverified. A close failure does not repair it.
      }
    }
    if (err && (err.code === "UNVERIFIED_READ" || err.code === "UNVERIFIED_STAT")) {
      throw err;
    }
    throw unverified("UNVERIFIED_READ", err);
  }
}
