import { O_APPEND, O_CREAT, O_RDONLY, O_WRONLY, closeSync, openSync, readSync, statSync, unlinkSync, writeSync } from "@zos/fs";
import { COUNTER_FILE } from "../lib/chunk_store";
import { JOURNAL_FILE } from "../lib/journal";

function encode(text) {
  const buffer = new ArrayBuffer(text.length);
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < text.length; i++) {
    bytes[i] = text.charCodeAt(i) & 127;
  }
  return buffer;
}

function decodeExact(buffer, length) {
  const bytes = new Uint8Array(buffer);
  let out = "";
  for (let i = 0; i < length; i++) {
    if (bytes[i] > 127) {
      throw new Error("non-ascii");
    }
    out += String.fromCharCode(bytes[i]);
  }
  return out;
}

function absent(err) {
  const text = String((err && (err.code || err.message)) || err || "");
  return /enoent|not found|no such file|not exist/i.test(text);
}

function safeName(name) {
  const text = String(name || "");
  if (!/^[A-Za-z0-9._-]+$/.test(text)) {
    throw new Error("bad name");
  }
  return text;
}

export function chunkAdapter() {
  return {
    readCounter() {
      let stat;
      try {
        stat = statSync({ path: COUNTER_FILE });
      } catch (err) {
        if (absent(err)) {
          return "";
        }
        throw err;
      }
      if (stat == null || stat.size === 0 || stat.size > 64) {
        return "";
      }
      const fd = openSync({ path: COUNTER_FILE, flag: O_RDONLY });
      try {
        const buffer = new ArrayBuffer(stat.size);
        const count = readSync({ fd: fd, buffer: buffer, options: { offset: 0, length: stat.size, position: 0 } });
        if (count !== stat.size) {
          throw new Error("short read");
        }
        return decodeExact(buffer, count);
      } finally {
        closeSync({ fd: fd });
      }
    },
    writeCounter(text) {
      const buffer = encode(text);
      const fd = openSync({ path: COUNTER_FILE, flag: O_WRONLY | O_CREAT });
      try {
        return writeSync({ fd: fd, buffer: buffer, options: { offset: 0, length: buffer.byteLength, position: 0 } });
      } finally {
        closeSync({ fd: fd });
      }
    },
    writeChunk(name, text) {
      const path = safeName(name);
      const buffer = encode(text);
      const fd = openSync({ path: path, flag: O_WRONLY | O_CREAT });
      try {
        return writeSync({ fd: fd, buffer: buffer, options: { offset: 0, length: buffer.byteLength, position: 0 } });
      } finally {
        closeSync({ fd: fd });
      }
    },
    statChunk(name) {
      const stat = statSync({ path: safeName(name) });
      return stat && typeof stat.size === "number" ? stat.size : 0;
    },
  };
}

export function deviceAdapter() {
  return {
    readAll() {
      let stat;
      try {
        stat = statSync({ path: JOURNAL_FILE });
      } catch (err) {
        if (absent(err)) {
          return "";
        }
        throw err;
      }
      if (stat == null || stat.size === 0) {
        return "";
      }
      const fd = openSync({ path: JOURNAL_FILE, flag: O_RDONLY });
      try {
        const buffer = new ArrayBuffer(stat.size);
        const count = readSync({ fd: fd, buffer: buffer, options: { offset: 0, length: stat.size, position: 0 } });
        if (count !== stat.size) {
          throw new Error("short read");
        }
        return decodeExact(buffer, count);
      } finally {
        closeSync({ fd: fd });
      }
    },
    append(text) {
      const buffer = encode(text);
      const fd = openSync({ path: JOURNAL_FILE, flag: O_WRONLY | O_CREAT | O_APPEND });
      try {
        return writeSync({ fd: fd, buffer: buffer, options: { offset: 0, length: buffer.byteLength, position: null } });
      } finally {
        closeSync({ fd: fd });
      }
    },
    clear() {
      try {
        unlinkSync({ path: JOURNAL_FILE });
      } catch (err) {
        if (!absent(err)) {
          throw err;
        }
      }
      return true;
    },
  };
}
