#!/usr/bin/env python3
"""Read-only HomeKit helpers followed by exactly one processing/SMS shortcut.

The three helpers must only return measurements. They must not call the CLI,
send messages or modify HomeKit. Failure of one helper never cancels the others.
"""

import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def timestamp():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_measurements(text, count):
    # Never compact invalid/empty lines: that would shift subsequent sensors.
    lines = text.strip().splitlines()
    if len(lines) != count * 2:
        raise ValueError("Wrong number of sensor values")
    numbers = []
    for line in lines:
        value = float(line.replace("°C", "").replace("°", "").replace("%", "").replace(",", ".").strip())
        if not math.isfinite(value):
            raise ValueError("Non-finite sensor value")
        numbers.append(value)
    readings = []
    for index in range(0, len(numbers), 2):
        temperature, humidity = numbers[index:index + 2]
        if not -40 <= temperature <= 60 or not 0 <= humidity <= 100:
            raise ValueError("Sensor value out of range")
        readings.append({"temperature": temperature, "humidity": humidity})
    return readings


def read_sensors(shortcut, ids, command, directory, sequence, timeout=None):
    observed_at = timestamp()
    output = directory / f"read-{sequence}.txt"
    failure = None
    measurements = [None] * len(ids)
    try:
        result = subprocess.run(
            [command, "run", shortcut, "--output-path", str(output)],
            capture_output=True, text=True,
            timeout=timeout if timeout is not None else (60 if len(ids) > 1 else 25), check=False,
        )
        if result.returncode:
            failure = "unavailable"
        else:
            measurements = parse_measurements(output.read_text(encoding="utf-8-sig"), len(ids))
    except subprocess.TimeoutExpired:
        failure = "timeout"
    except (OSError, UnicodeError, ValueError):
        failure = "invalid"
    return [
        {
            "id": sensor_id, "measuredAt": observed_at,
            "measurement": measurement, "failure": failure,
        }
        for sensor_id, measurement in zip(ids, measurements)
    ]


def run(config, command="/usr/bin/shortcuts", collect_only=False):
    keys = ["indoorShortcut", "eveShortcut", "homepodShortcut", "processingShortcut"]
    if config.get("version") != 1 or any(
        not isinstance(config.get(key), str) or not config[key].strip() for key in keys
    ) or len({config[key] for key in keys}) != 4:
        raise ValueError("Vier unterschiedliche Kurzbefehle und version=1 erforderlich")

    with tempfile.TemporaryDirectory(prefix="climateengine-terrace-") as temp:
        directory = Path(temp)
        sensors = []
        for sequence, (key, ids) in enumerate([
            ("indoorShortcut", ["stube", "schlafzimmer", "buero-alois", "sauna"]),
            ("homepodShortcut", ["homepod-terrasse"]),
            ("eveShortcut", ["eve-degree"]),
        ]):
            sensors.extend(read_sensors(config[key], ids, command, directory, sequence))
        payload = {"version": 1, "timestamp": timestamp(), "sensors": sensors}
        if collect_only:
            print(json.dumps(payload, ensure_ascii=False, allow_nan=False))
            return 0
        input_path = directory / "sensor-readings.json"
        input_path.write_text(json.dumps(payload, allow_nan=False), encoding="utf-8")
        # This is the only stage that may evaluate or send an SMS. Do not retry
        # it: a failure could have happened after a message was already sent.
        result = subprocess.run(
            [command, "run", config["processingShortcut"], "--input-path", str(input_path)],
            timeout=60, check=False,
        )
        return result.returncode


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--collect-only", action="store_true", help="Nur lesen; keine CLI-Auswertung oder SMS")
    args = parser.parse_args()
    try:
        with args.config.open(encoding="utf-8") as file:
            config = json.load(file)
        sys.exit(run(config, os.environ.get("CLIMATEENGINE_SHORTCUTS_COMMAND", "/usr/bin/shortcuts"), args.collect_only))
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Terrasse-Connector fehlgeschlagen: {error}", file=sys.stderr)
        sys.exit(1)
