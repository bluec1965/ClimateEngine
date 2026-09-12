#!/usr/bin/env python3
"""Collect independent read-only helpers; persist only real successful readings."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("terrace_reader", ROOT / "Scripts/run-terrace-connector.py")
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
IDS = ["homepod-kueche", "homepod-bad-peter", "homepod-schlafzimmer",
       "homepod-buero-alois-rechts", "homepod-sauna-links", "homepod-buero-peter",
       "homepod-bad-alois", "dachzimmer-sensor"]
DEFAULT_HEATING_SHORTCUT = "ClimateEngine Read Heating Büro Alois"


def read_heating(shortcut, command, directory, timeout=25):
    output = directory / "heating.txt"
    snapshot = {"version": 1, "timestamp": reader.timestamp(), "roomID": "buero-alois",
        "roomName": "Büro Alois", "temperature": None, "currentStatus": None,
        "available": False, "error": "unavailable"}
    try:
        result = subprocess.run([command, "run", shortcut, "--output-path", str(output)],
            capture_output=True, text=True, timeout=timeout, check=False)
        if result.returncode:
            return snapshot
        lines = output.read_text(encoding="utf-8-sig").strip().splitlines()
        if len(lines) != 2:
            raise ValueError("Wrong number of heating values")
        temperature = float(lines[0].replace("°C", "").replace("°", "").replace(",", ".").strip())
        status = int(float(lines[1].replace(",", ".").strip()))
        if not -40 <= temperature <= 60 or status not in (0, 1, 2, 3):
            raise ValueError("Heating value out of range")
        snapshot.update({"temperature": temperature, "currentStatus": status,
            "available": True, "error": None})
    except subprocess.TimeoutExpired:
        snapshot["error"] = "timeout"
    except (OSError, UnicodeError, ValueError):
        snapshot["error"] = "invalid"
    return snapshot


def write_heating(snapshot, data_root=None):
    root = Path(data_root or os.environ.get("CLIMATEENGINE_DATA_DIRECTORY",
        Path.home() / "Library/Application Support/ClimateEngine"))
    destination = root / "heating/buero-alois.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2,
        sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, destination)


def run(config, command="/usr/bin/shortcuts", cli=None, collect_only=False, data_root=None):
    shortcuts = config.get("shortcuts", {})
    if config.get("version") != 1 or set(shortcuts) != set(IDS) or any(
        not isinstance(name, str) or not name.strip() for name in shortcuts.values()
    ) or len(set(shortcuts.values())) != len(IDS):
        raise ValueError("Für jeden der acht Zusatzsensoren ist ein eigener Lese-Kurzbefehl erforderlich.")
    with tempfile.TemporaryDirectory(prefix="climateengine-additional-") as temp:
        sensors = []
        deadline = time.monotonic() + 150
        for index, sensor_id in enumerate(IDS):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                sensors.append({"id": sensor_id, "measuredAt": reader.timestamp(),
                    "measurement": None, "failure": "timeout"})
                continue
            sensors.extend(reader.read_sensors(shortcuts[sensor_id], [sensor_id], command,
                Path(temp), index, timeout=min(25, remaining)))
        payload = json.dumps({"version": 1, "timestamp": reader.timestamp(), "sensors": sensors},
            ensure_ascii=False, allow_nan=False)
        if collect_only:
            print(payload)
            return 0
        heating = read_heating(config.get("heatingShortcut", DEFAULT_HEATING_SHORTCUT),
            command, Path(temp), timeout=min(25, max(1, deadline - time.monotonic())))
        write_heating(heating, data_root)
        # No SMS and no retries; the primary recommendation flow is independent.
        return subprocess.run([str(cli or ROOT / ".build/debug/ClimateEngineCLI"), "additional-readings"],
            input=payload, text=True, timeout=20, check=False).returncode


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--collect-only", action="store_true")
    args = parser.parse_args()
    try:
        with args.config.open(encoding="utf-8") as file:
            config = json.load(file)
        sys.exit(run(config, os.environ.get("CLIMATEENGINE_SHORTCUTS_COMMAND", "/usr/bin/shortcuts"),
            collect_only=args.collect_only))
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Zusatz-Connector fehlgeschlagen: {error}", file=sys.stderr)
        sys.exit(1)
