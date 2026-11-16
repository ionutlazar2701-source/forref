import {
  O_APPEND,
  O_CREAT,
  O_RDONLY,
  O_WRONLY,
  closeSync,
  openSync,
  readSync,
  statSync,
  writeSync,
} from "@zos/fs";
import { getDeviceInfo } from "@zos/device";
import { JOURNAL_FILE } from "./capture_candidate";

function encode(text) {
  const buffer = new ArrayBuffer(text.length);
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < text.length; i++) {
    bytes[i] = text.charCodeAt(i);
  }
  return buffer;
}

function decode(buffer, length) {
  const bytes = new Uint8Array(buffer);
  let out = "";
  for (let i = 0; i < length; i++) {
    out += String.fromCharCode(bytes[i]);
  }
  return out;
}

export function watchDiagnosticSource() {
  try {
    const info = getDeviceInfo();
    const source = info && info.deviceSource != null ? String(info.deviceSource) : "";
    return source.replace(/[^0-9A-Za-z_-]/g, "").slice(0, 32);
  } catch (err) {
    return "";
  }
}

export function watchCaptureAdapter() {
  return {
    readAll() {
      let size = 0;
      try {
        const stat = statSync({ path: JOURNAL_FILE });
        if (!stat || !stat.size) {
          return "";
        }
        size = stat.size;
      } catch (err) {
        return "";
      }
      const fd = openSync({ path: JOURNAL_FILE, flag: O_RDONLY });
      try {
        const buffer = new ArrayBuffer(size);
        const count = readSync({
          fd: fd,
          buffer: buffer,
          options: { offset: 0, length: size, position: 0 },
        });
        if (count !== size) {
          throw new Error("short read");
        }
        return decode(buffer, count);
      } finally {
        closeSync({ fd: fd });
      }
    },
    append(text) {
      const buffer = encode(text);
      const fd = openSync({
        path: JOURNAL_FILE,
        flag: O_WRONLY | O_CREAT | O_APPEND,
      });
      try {
        return writeSync({
          fd: fd,
          buffer: buffer,
          options: { offset: 0, length: buffer.byteLength, position: null },
        });
      } finally {
        closeSync({ fd: fd });
      }
    },
  };
}
