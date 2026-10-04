#!/usr/bin/python3
"""Bound the known MenuBarAgent leak using footprint, including compressed memory."""
import argparse
from datetime import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

TARGET = "/System/Library/CoreServices/MenuBarAgent.app/Contents/MacOS/MenuBarAgent"
THRESHOLD = 1024 ** 3
COOLDOWN = 600
ROOT = Path.home() / "Library/Application Support/ClimateEngine/diagnostics"


def memory_bytes(value):
    match = re.fullmatch(r"(\d+(?:\.\d+)?)([BKMGTP])?[+-]?", value)
    if not match:
        raise ValueError("Unrecognized memory value")
    units = {None: 1, "B": 1, "K": 1024, "M": 1024 ** 2,
             "G": 1024 ** 3, "T": 1024 ** 4, "P": 1024 ** 5}
    return int(float(match[1]) * units[match[2]])


def read_footprint(output, pid):
    for line in output.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[0] == str(pid):
            return memory_bytes(fields[1]), memory_bytes(fields[2])
    raise ValueError("MenuBarAgent memory sample missing")


def same_target(pid):
    result = subprocess.run(["/bin/ps", "-p", str(pid), "-o", "uid=,comm="],
                            capture_output=True, text=True, timeout=5, check=False)
    fields = result.stdout.strip().split(maxsplit=1)
    return fields == [str(os.getuid()), TARGET]


def restart_needed(footprint, now, previous):
    return footprint >= THRESHOLD and now - previous >= COOLDOWN


def log_event(root, message):
    log = root / "menubar-memory-guard.log"
    if log.exists() and log.stat().st_size > 100_000:
        os.replace(log, log.with_suffix(".log.previous"))
    with log.open("a", encoding="utf-8") as stream:
        stream.write(f"{datetime.now().astimezone().isoformat(timespec='seconds')} {message}\n")


def run(root=ROOT, dry_run=False):
    root.mkdir(parents=True, exist_ok=True)
    with (root / "menubar-memory-guard.lock").open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        state_path = root / "menubar-memory-guard.json"
        try:
            previous = float(json.loads(state_path.read_text())["lastRestart"])
        except (OSError, ValueError, KeyError, TypeError):
            previous = 0
        found = subprocess.run(["/usr/bin/pgrep", "-u", str(os.getuid()), "-x", "MenuBarAgent"],
                               capture_output=True, text=True, timeout=5, check=False)
        for token in found.stdout.split():
            pid = int(token)
            if not same_target(pid):
                continue
            # top's MEM includes compressed footprint; RSS would miss the leak.
            sample = subprocess.run(["/usr/bin/top", "-l", "1", "-pid", str(pid),
                                     "-stats", "pid,mem,cmprs"],
                                    capture_output=True, text=True, timeout=10, check=True)
            footprint, compressed = read_footprint(sample.stdout, pid)
            now = time.time()
            if restart_needed(footprint, now, previous) and same_target(pid):
                if dry_run:
                    log_event(root, f"WOULD_RESTART pid={pid} footprint_bytes={footprint} compressed_bytes={compressed}")
                    continue
                try:
                    os.kill(pid, signal.SIGTERM)
                except ProcessLookupError:
                    continue
                temporary = state_path.with_suffix(".json.tmp")
                temporary.write_text(json.dumps({"lastRestart": now}) + "\n")
                os.replace(temporary, state_path)
                log_event(root, f"RESTART pid={pid} footprint_bytes={footprint} compressed_bytes={compressed} threshold_bytes={THRESHOLD}")
                previous = now


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        run(dry_run=args.dry_run)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"MenuBarAgent-Speicherprüfung fehlgeschlagen: {error}", flush=True)
