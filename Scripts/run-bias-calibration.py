#!/usr/bin/env python3
"""Build guarded weekly bias profiles from paired ClimateEngine history."""

import argparse
from bisect import bisect_left
from datetime import datetime, timedelta, timezone
import glob
import json
import math
import os
from pathlib import Path
import statistics


ROOMS = {
    "stube": ("stube", "homepod-kueche", -0.403, 5.0625915527344),
    "schlafzimmer": ("schlafzimmer", "homepod-schlafzimmer", -0.12, 3.5944519042969),
    "buero-alois": ("buero-alois", "homepod-buero-alois-rechts", 0.9, -1.0),
    "sauna": ("sauna", "homepod-sauna-links", -0.5, 1.0),
}
TERRACE_ID = "terrasse"
MINIMUM_PAIRS = 500
WINDOW_DAYS = 14
MAX_TEMPERATURE_STEP = 0.3
MAX_HUMIDITY_STEP = 1.0
MAX_TEMPERATURE_MAD = 0.8
MAX_HUMIDITY_MAD = 3.0


def parse_time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def iso_time(value):
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_json_lines(pattern):
    values = []
    for filename in sorted(glob.glob(str(pattern))):
        with open(filename, encoding="utf-8") as stream:
            for line in stream:
                try:
                    values.append(json.loads(line))
                except (ValueError, json.JSONDecodeError):
                    continue
    return values


def limited(previous, measured, maximum_step):
    return previous + max(-maximum_step, min(maximum_step, measured - previous))


def profile(room_id, baseline_id, adjusted_id, values, previous, start, end):
    temperature_differences = [value[0] for value in values]
    humidity_differences = [value[1] for value in values]
    measured_temperature = statistics.median(temperature_differences) if values else previous[0]
    measured_humidity = statistics.median(humidity_differences) if values else previous[1]
    temperature_mad = statistics.median(
        abs(value - measured_temperature) for value in temperature_differences
    ) if values else math.inf
    humidity_mad = statistics.median(
        abs(value - measured_humidity) for value in humidity_differences
    ) if values else math.inf
    stable = (
        len(values) >= MINIMUM_PAIRS
        and temperature_mad <= MAX_TEMPERATURE_MAD
        and humidity_mad <= MAX_HUMIDITY_MAD
    )
    return {
        "roomID": room_id,
        "baselineSensorID": baseline_id,
        "adjustedSensorID": adjusted_id,
        "temperatureAdjustment": round(limited(previous[0], measured_temperature, MAX_TEMPERATURE_STEP), 3),
        "relativeHumidityAdjustment": round(limited(previous[1], measured_humidity, MAX_HUMIDITY_STEP), 3),
        "sampleCount": len(values),
        "analysisPeriod": f"{start:%d.%m.%Y}–{end:%d.%m.%Y}",
        "temperatureMAD": None if not values else round(temperature_mad, 3),
        "humidityMAD": None if not values else round(humidity_mad, 3),
        "isProvisional": not stable,
        "caveat": None if stable else "Zu wenige oder zu stark streuende Messpaare; bisherige Korrektur wird nur begrenzt angepasst.",
    }


def calibrate(data_root, now=None, force=False):
    now = now or datetime.now(timezone.utc)
    output = data_root / "bias-calibration.json"
    existing = None
    if output.exists():
        try:
            existing = json.loads(output.read_text(encoding="utf-8"))
            generated = parse_time(existing["generatedAt"])
            if not force and now - generated < timedelta(days=7):
                return existing
        except (KeyError, OSError, ValueError, json.JSONDecodeError):
            existing = None

    main = load_json_lines(data_root / "history" / "*.jsonl")
    additional = load_json_lines(data_root / "additional-sensors" / "history" / "*.jsonl")
    start = now - timedelta(days=WINDOW_DAYS)
    main = [entry for entry in main if start <= parse_time(entry["timestamp"]) <= now]
    additional_index = sorted(
        (parse_time(entry["timestamp"]), {sensor["id"]: sensor["measurement"] for sensor in entry.get("sensors", [])})
        for entry in additional if start <= parse_time(entry["timestamp"]) <= now
    )
    additional_times = [item[0] for item in additional_index]
    previous_profiles = {item["roomID"]: item for item in (existing or {}).get("profiles", [])}
    profiles = []

    for room_id, (baseline_id, adjusted_id, fallback_t, fallback_h) in ROOMS.items():
        values = []
        for entry in main:
            timestamp = parse_time(entry["timestamp"])
            rooms = {item["id"]: item["measurement"] for item in entry.get("indoorRooms", [])}
            if baseline_id not in rooms:
                continue
            index = bisect_left(additional_times, timestamp)
            candidates = [additional_index[i] for i in (index - 1, index)
                          if 0 <= i < len(additional_index)
                          and abs((additional_index[i][0] - timestamp).total_seconds()) <= 180
                          and adjusted_id in additional_index[i][1]]
            if not candidates:
                continue
            adjusted = min(candidates, key=lambda item: abs((item[0] - timestamp).total_seconds()))[1][adjusted_id]
            baseline = rooms[baseline_id]
            values.append((baseline["temperature"] - adjusted["temperature"], baseline["humidity"] - adjusted["humidity"]))
        old = previous_profiles.get(room_id, {})
        previous = (old.get("temperatureAdjustment", fallback_t), old.get("relativeHumidityAdjustment", fallback_h))
        profiles.append(profile(room_id, baseline_id, adjusted_id, values, previous, start, now))

    terrace_values = []
    for entry in main:
        sensors = {item["id"]: item["measurement"] for item in entry.get("outdoorSensors", [])}
        if "eve-degree" in sensors and "homepod-terrasse" in sensors:
            baseline, adjusted = sensors["eve-degree"], sensors["homepod-terrasse"]
            terrace_values.append((baseline["temperature"] - adjusted["temperature"], baseline["humidity"] - adjusted["humidity"]))
    old = previous_profiles.get(TERRACE_ID, {})
    previous = (old.get("temperatureAdjustment", 0.0), old.get("relativeHumidityAdjustment", 0.0))
    profiles.append(profile(TERRACE_ID, "eve-degree", "homepod-terrasse", terrace_values, previous, start, now))

    document = {"version": 1, "generatedAt": iso_time(now), "windowDays": WINDOW_DAYS, "profiles": profiles}
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, output)
    return document


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", type=Path, default=Path.home() / "Library" / "Application Support" / "ClimateEngine")
    parser.add_argument("--force", action="store_true")
    arguments = parser.parse_args()
    print(json.dumps(calibrate(arguments.data_root, force=arguments.force), ensure_ascii=False))
