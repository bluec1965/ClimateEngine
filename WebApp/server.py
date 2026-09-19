#!/usr/bin/env python3

import argparse
from contextlib import contextmanager
import fcntl
import json
import mimetypes
import os
import socket
import subprocess
import tempfile
import threading
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


WEB_ROOT = Path(__file__).resolve().parent
DATA_ROOT = Path.home() / "Library" / "Application Support" / "ClimateEngine"
VENTILATION_SESSION_PATH = DATA_ROOT / "ventilation-session.json"
VENTILATION_SESSION_LOCK = threading.Lock()
HEATING_DIRECTORY = DATA_ROOT / "heating"
HEATING_CONTROL_PATH = HEATING_DIRECTORY / "ventilation-control.json"
HEATING_ROOM_OVERRIDES_PATH = HEATING_DIRECTORY / "room-overrides.json"
HEATING_ROOM_COMFORT_PATH = HEATING_DIRECTORY / "room-comfort.json"
HEATING_LOCK = threading.Lock()
HEATING_ROOM_OVERRIDES_LOCK = threading.Lock()
HEATING_ROOM_COMFORT_LOCK = threading.Lock()
HEATING_SHORTCUT_THREAD_LOCK = threading.Lock()
HEATING_SHORTCUT_PROCESS_LOCK_PATH = Path("/tmp/climateengine-shortcuts.lock")
HEATING_THERMOSTATS = {
    "buero-alois": ({"snapshotID": "buero-alois", "name": "Büro Alois", "read": "ClimateEngine Read Heating Büro Alois", "comfort": "ClimateEngine Heating Büro Alois Comfort", "off": "ClimateEngine Heating Büro Alois Off", "on": "ClimateEngine Heating Büro Alois On", "revert-18.0": "ClimateEngine Heating Büro Alois Revert 18.0", "revert-21.5": "ClimateEngine Heating Büro Alois Revert 21.5"},),
    "bad-alois": ({"snapshotID": "bad-alois", "name": "Bad Alois", "read": "ClimateEngine Read Heating Bad Alois", "comfort": "ClimateEngine Heating Bad Alois Comfort", "off": "ClimateEngine Heating Bad Alois Off", "on": "ClimateEngine Heating Bad Alois On", "revert-18.0": "ClimateEngine Heating Bad Alois Revert 18.0", "revert-21.5": "ClimateEngine Heating Bad Alois Revert 21.5"},),
    "sauna": ({"snapshotID": "sauna", "name": "Sauna", "read": "ClimateEngine Read Heating Sauna", "comfort": "ClimateEngine Heating Sauna Comfort", "off": "ClimateEngine Heating Sauna Off", "on": "ClimateEngine Heating Sauna On", "revert-18.0": "ClimateEngine Heating Sauna Revert 18.0", "revert-21.5": "ClimateEngine Heating Sauna Revert 21.5"},),
    "galerie": ({"snapshotID": "galerie", "name": "Galerie", "read": "ClimateEngine Read Heating Galerie", "comfort": "ClimateEngine Heating Galerie Comfort", "off": "ClimateEngine Heating Galerie Off", "on": "ClimateEngine Heating Galerie On", "revert-18.0": "ClimateEngine Heating Galerie Revert 18.0", "revert-21.5": "ClimateEngine Heating Galerie Revert 21.5"},),
    "dachzimmer": (
        {"snapshotID": "dachzimmer-wand", "name": "Dachzimmer Wand", "read": "ClimateEngine Read Heating Dachzimmer Wand", "comfort": "ClimateEngine Heating Dachzimmer Wand Comfort", "off": "ClimateEngine Heating Dachzimmer Wand Off", "on": "ClimateEngine Heating Dachzimmer Wand On", "revert-18.0": "ClimateEngine Heating Dachzimmer Wand Revert 18.0", "revert-21.5": "ClimateEngine Heating Dachzimmer Wand Revert 21.5"},
        {"snapshotID": "dachzimmer-fenster", "name": "Dachzimmer Fenster", "read": "ClimateEngine Read Heating Dachzimmer Fenster", "comfort": "ClimateEngine Heating Dachzimmer Fenster Comfort", "off": "ClimateEngine Heating Dachzimmer Fenster Off", "on": "ClimateEngine Heating Dachzimmer Fenster On", "revert-18.0": "ClimateEngine Heating Dachzimmer Fenster Revert 18.0", "revert-21.5": "ClimateEngine Heating Dachzimmer Fenster Revert 21.5"},
    ),
}
HEATING_PROTOTYPE_SCHEDULE = {
    "roomID": "buero-alois",
    "roomName": "Büro Alois",
    "comfortTemperature": 21.5,
    "nightTemperature": 18.0,
    "weekdayComfortStartMinute": 6 * 60,
    "weekdayComfortEndMinute": 22 * 60,
    "weekendComfortStartMinute": 7 * 60 + 30,
    "weekendComfortEndMinute": 23 * 60,
}
HEATING_ROOM_NAMES = {
    "buero-alois": "Büro Alois", "bad-alois": "Bad Alois", "sauna": "Sauna",
    "galerie": "Galerie", "dachzimmer": "Dachzimmer",
}


class ComfortUnavailableError(RuntimeError):
    pass


@contextmanager
def heating_shortcut_transaction():
    """Keep one user action contiguous across web and polling processes."""
    with HEATING_SHORTCUT_THREAD_LOCK:
        with HEATING_SHORTCUT_PROCESS_LOCK_PATH.open("a+") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def read_optional_json(path):
    if not path.exists():
        return None
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def ventilation_session_payload(now=None):
    now = now or datetime.now().astimezone()
    session = read_optional_json(VENTILATION_SESSION_PATH)
    if not isinstance(session, dict):
        return {"active": False, "remainingSeconds": 0}
    try:
        started_at = datetime.fromisoformat(session["startedAt"].replace("Z", "+00:00"))
        expires_at = datetime.fromisoformat(session["expiresAt"].replace("Z", "+00:00"))
        active = started_at <= now < expires_at
        remaining = max(0, int((expires_at - now).total_seconds() + 0.999)) if active else 0
        payload = {
            **session,
            "active": active,
            "remainingSeconds": remaining,
        }
        if not active:
            reconcile_heating_after_ventilation()
        return payload
    except (KeyError, TypeError, ValueError):
        return {"active": False, "remainingSeconds": 0}


def write_ventilation_session(active, now=None):
    now = (now or datetime.now(timezone.utc)).replace(microsecond=0)
    expires_at = now + timedelta(minutes=10) if active else now
    session = {
        "version": 1,
        "startedAt": now.isoformat().replace("+00:00", "Z"),
        "expiresAt": expires_at.isoformat().replace("+00:00", "Z"),
    }
    VENTILATION_SESSION_PATH.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = VENTILATION_SESSION_PATH.with_suffix(".json.tmp")
    with VENTILATION_SESSION_LOCK:
        with temporary_path.open("w", encoding="utf-8") as file:
            json.dump(session, file, ensure_ascii=False, indent=2, sort_keys=True)
            file.write("\n")
        os.replace(temporary_path, VENTILATION_SESSION_PATH)
    if active:
        suspend_heating_for_ventilation()
    else:
        reconcile_heating_after_ventilation()
    return ventilation_session_payload(now=now)


def write_atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = path.with_suffix(".json.tmp")
    with temporary_path.open("w", encoding="utf-8") as file:
        json.dump(value, file, ensure_ascii=False, indent=2, sort_keys=True)
        file.write("\n")
    os.replace(temporary_path, path)


def heating_room_overrides_payload():
    try:
        state = read_optional_json(HEATING_ROOM_OVERRIDES_PATH)
    except (OSError, ValueError, json.JSONDecodeError):
        state = None
    if not isinstance(state, dict) or not isinstance(state.get("openRoomIDs"), list):
        return {"version": 1, "openRoomIDs": [], "updatedAt": None}
    return state


def write_heating_room_override(room_id, window_open, now=None):
    if room_id not in HEATING_THERMOSTATS:
        raise ValueError("Raum ist im Prototyp noch nicht schaltbar")
    if not isinstance(window_open, bool):
        raise ValueError("windowOpen muss ein Wahrheitswert sein")
    now = (now or datetime.now().astimezone()).replace(microsecond=0)
    with HEATING_ROOM_OVERRIDES_LOCK:
        state = heating_room_overrides_payload()
        open_room_ids = set(state["openRoomIDs"])
        if (room_id in open_room_ids) == window_open:
            return state

        def persist_open_rooms():
            persisted = {
                "version": 1,
                "openRoomIDs": sorted(open_room_ids),
                "updatedAt": now.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            }
            write_atomic_json(HEATING_ROOM_OVERRIDES_PATH, persisted)
            return persisted

        if window_open:
            open_room_ids.add(room_id)
            state = persist_open_rooms()
            # Persist the protective state before touching HomeKit. If the
            # command fails, later actions must still treat the window as open.
            if room_id in HEATING_THERMOSTATS and heating_enabled():
                with heating_shortcut_transaction():
                    set_room_heating_enabled(room_id, False)
            return state

        if room_id in HEATING_THERMOSTATS and heating_enabled():
            if not ventilation_session_payload(now=now)["active"]:
                with heating_shortcut_transaction():
                    set_room_heating_enabled(room_id, True)
                    comfort = heating_room_comfort_payload()
                    if room_id in comfort["activeRoomIDs"]:
                        apply_room_target(room_id, "comfort", 24.0)
                    else:
                        schedule = heating_prototype_payload(now=now, overrides=state)
                        target = schedule["targetTemperature"]
                        action = "revert-21.5" if target == 21.5 else "revert-18.0"
                        apply_room_target(room_id, action, target)

        # Only publish a closed window after every required thermostat action
        # has succeeded. A failure therefore keeps the safe, open state.
        open_room_ids.discard(room_id)
        return persist_open_rooms()


def heating_room_comfort_payload():
    try:
        state = read_optional_json(HEATING_ROOM_COMFORT_PATH)
    except (OSError, ValueError, json.JSONDecodeError):
        state = None
    if not isinstance(state, dict) or not isinstance(state.get("activeRoomIDs"), list):
        return {
            "version": 2,
            "activeRoomIDs": [],
            "updatedAt": None,
            "lastAppliedTargetTemperature": None,
            "lastAppliedTargetTemperatures": {},
        }
    return state


def run_shortcut_with_output(shortcut_name, timeout=30):
    with tempfile.TemporaryDirectory(prefix="climateengine-heating-") as directory:
        output_path = Path(directory) / "output.txt"
        result = subprocess.run(
            ["/usr/bin/shortcuts", "run", shortcut_name, "--output-path", str(output_path)],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        if result.returncode:
            detail = (result.stderr or result.stdout).strip().replace("\n", " ")
            suffix = f": {detail}" if detail else ""
            raise RuntimeError(f"Kurzbefehl {shortcut_name} fehlgeschlagen{suffix}")
        if output_path.exists():
            return output_path.read_text(encoding="utf-8-sig").strip()
        return result.stdout.strip()


def read_room_thermostat_snapshots(room_id):
    snapshots = []
    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    for thermostat in HEATING_THERMOSTATS[room_id]:
        lines = run_shortcut_with_output(thermostat["read"]).splitlines()
        if len(lines) != 4:
            raise RuntimeError(f"Heizungsstatus von {thermostat['name']} ist unvollständig")
        try:
            temperature = parse_temperature(lines[0])
            current_status = int(float(lines[1].replace(",", ".").strip()))
            activated = int(float(lines[2].replace(",", ".").strip()))
            target = parse_temperature(lines[3])
        except (TypeError, ValueError) as error:
            raise RuntimeError(f"Heizungsstatus von {thermostat['name']} ist ungültig") from error
        if (not -40 <= temperature <= 60 or current_status not in (0, 1, 2, 3)
                or activated not in (0, 1) or not 5 <= target <= 35):
            raise RuntimeError(f"Heizungsstatus von {thermostat['name']} ist ungültig")
        snapshots.append({
            "version": 1, "timestamp": timestamp,
            "snapshotID": thermostat["snapshotID"], "roomID": room_id,
            "roomName": thermostat["name"], "temperature": temperature,
            "currentStatus": current_status, "isEnabled": activated == 1,
            "targetTemperature": target, "available": True, "error": None,
        })
    for snapshot in snapshots:
        write_atomic_json(
            HEATING_DIRECTORY / f"{snapshot['snapshotID']}.json", snapshot
        )
    return snapshots


def read_room_heating_states(room_id):
    return [snapshot["isEnabled"] for snapshot in read_room_thermostat_snapshots(room_id)]


def read_room_heating(room_id):
    return all(read_room_heating_states(room_id))


def apply_room_target(room_id, action, expected_target):
    for thermostat in HEATING_THERMOSTATS[room_id]:
        # Write every thermostat before checking any of them. This prevents a
        # slow first HomeKit read from blocking the second thermostat entirely.
        run_shortcut_with_output(thermostat[action])
    try:
        snapshots = read_room_thermostat_snapshots(room_id)
        for snapshot in snapshots:
            # Aqara may return its previous HomeKit value for several minutes
            # even though the write shortcut itself completed successfully.
            snapshot["targetTemperature"] = expected_target
            write_atomic_json(
                HEATING_DIRECTORY / f"{snapshot['snapshotID']}.json", snapshot
            )
    except (OSError, RuntimeError, subprocess.TimeoutExpired):
        # The write result is authoritative; polling will refresh the remaining
        # measurements later and must not invalidate the room action.
        pass
    return expected_target


def write_heating_room_comfort(room_id, active, now=None):
    if room_id not in HEATING_THERMOSTATS:
        raise ValueError("Raum-Behaglichkeit ist für diesen Raum noch nicht verfügbar")
    if not isinstance(active, bool):
        raise ValueError("active muss ein Wahrheitswert sein")
    now = (now or datetime.now().astimezone()).replace(microsecond=0)
    room_name = HEATING_ROOM_NAMES[room_id]

    with HEATING_ROOM_COMFORT_LOCK:
        with heating_shortcut_transaction():
            previous = heating_room_comfort_payload()
            active_room_ids = set(previous["activeRoomIDs"])
            targets = dict(previous.get("lastAppliedTargetTemperatures") or {})
            if not targets and previous.get("lastAppliedTargetTemperature") is not None:
                for active_room_id in active_room_ids:
                    targets[active_room_id] = previous["lastAppliedTargetTemperature"]
            if active:
                if not heating_enabled():
                    raise ComfortUnavailableError("Die wohnungsweite Heizung ist ausgeschaltet")
                if room_id in heating_room_overrides_payload()["openRoomIDs"]:
                    raise ComfortUnavailableError(f"Fenster oder Tür in {room_name} ist offen")
                if ventilation_session_payload(now=now)["active"]:
                    raise ComfortUnavailableError("Die Stosslüftung ist aktiv")
                if not read_room_heating(room_id):
                    raise ComfortUnavailableError(f"Der Heizkörper in {room_name} ist ausgeschaltet")
                target = apply_room_target(room_id, "comfort", 24.0)
                active_room_ids.add(room_id)
                targets[room_id] = target
            else:
                active_room_ids.discard(room_id)
                protected = (
                    not heating_enabled()
                    or room_id in heating_room_overrides_payload()["openRoomIDs"]
                    or ventilation_session_payload(now=now)["active"]
                )
                if protected:
                    target = None
                else:
                    schedule = heating_prototype_payload(now=now)
                    target = schedule["targetTemperature"]
                    action = "revert-21.5" if target == 21.5 else "revert-18.0"
                    target = apply_room_target(room_id, action, target)
                if target is None:
                    targets.pop(room_id, None)
                else:
                    targets[room_id] = target

        state = {
            "version": 2,
            "activeRoomIDs": sorted(active_room_ids),
            "updatedAt": now.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "lastAppliedTargetTemperature": target,
            "lastAppliedTargetTemperatures": targets,
        }
        write_atomic_json(HEATING_ROOM_COMFORT_PATH, state)
        return state


def heating_prototype_payload(now=None, overrides=None):
    now = now or datetime.now().astimezone()
    schedule = HEATING_PROTOTYPE_SCHEDULE
    weekend = now.weekday() >= 5
    start = schedule["weekendComfortStartMinute"] if weekend else schedule["weekdayComfortStartMinute"]
    end = schedule["weekendComfortEndMinute"] if weekend else schedule["weekdayComfortEndMinute"]
    minute = now.hour * 60 + now.minute
    period = "comfort" if start <= minute < end else "night"
    target = schedule["comfortTemperature"] if period == "comfort" else schedule["nightTemperature"]
    overrides = overrides or heating_room_overrides_payload()
    window_open = schedule["roomID"] in overrides["openRoomIDs"]
    return {
        "mode": "active",
        "roomID": schedule["roomID"],
        "roomName": schedule["roomName"],
        "period": period,
        "targetTemperature": target,
        "comfortStartMinute": start,
        "comfortEndMinute": end,
        "windowOpen": window_open,
        "wouldDisableHeating": window_open,
    }


def heating_enabled():
    try:
        return read_optional_json(DATA_ROOT / "operating-mode.json").get("heatingEnabled") is True
    except (AttributeError, OSError, ValueError, json.JSONDecodeError):
        return False


def run_heating_shortcut(room_id, action):
    for thermostat in HEATING_THERMOSTATS[room_id]:
        result = subprocess.run(
            ["/usr/bin/shortcuts", "run", thermostat[action]], capture_output=True,
            text=True, timeout=30, check=False,
        )
        if result.returncode:
            detail = (result.stderr or result.stdout).strip().replace("\n", " ")
            suffix = f": {detail}" if detail else ""
            raise RuntimeError(f"Heizkörperbefehl für {thermostat['name']} fehlgeschlagen{suffix}")


def set_room_heating_enabled(room_id, enabled):
    run_heating_shortcut(room_id, "on" if enabled else "off")
    try:
        snapshots = read_room_thermostat_snapshots(room_id)
        for snapshot in snapshots:
            snapshot["isEnabled"] = enabled
            write_atomic_json(
                HEATING_DIRECTORY / f"{snapshot['snapshotID']}.json", snapshot
            )
    except (OSError, RuntimeError, subprocess.TimeoutExpired):
        pass


def suspend_heating_for_ventilation():
    if not heating_enabled():
        return
    with HEATING_LOCK:
        suspended, errors = [], {}
        for room_id in HEATING_THERMOSTATS:
            try:
                run_heating_shortcut(room_id, "off")
                suspended.append(room_id)
            except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
                errors[room_id] = str(error)
        write_atomic_json(HEATING_CONTROL_PATH, {
            "version": 2, "suspended": bool(suspended), "suspendedRoomIDs": suspended,
            "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "error": "; ".join(errors.values()) or None, "errors": errors,
        })


def reconcile_heating_after_ventilation():
    with HEATING_LOCK:
        try:
            state = read_optional_json(HEATING_CONTROL_PATH)
        except (OSError, ValueError, json.JSONDecodeError):
            return
        if not isinstance(state, dict) or state.get("suspended") is not True:
            return
        room_ids = state.get("suspendedRoomIDs")
        if not isinstance(room_ids, list):
            room_ids = ["buero-alois"]
        if not heating_enabled():
            write_atomic_json(HEATING_CONTROL_PATH, {
                "version": 2, "suspended": False, "suspendedRoomIDs": [],
                "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "error": None,
            })
            return
        remaining, errors = [], {}
        for room_id in room_ids:
            if room_id not in HEATING_THERMOSTATS:
                continue
            if room_id in heating_room_overrides_payload()["openRoomIDs"]:
                continue
            try:
                run_heating_shortcut(room_id, "on")
            except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
                remaining.append(room_id)
                errors[room_id] = str(error)
        write_atomic_json(HEATING_CONTROL_PATH, {
            "version": 2, "suspended": bool(remaining), "suspendedRoomIDs": remaining,
            "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "error": "; ".join(errors.values()) or None, "errors": errors,
        })


def parse_temperature(value):
    if isinstance(value, (int, float)):
        return float(value)
    return float(str(value).replace(",", ".").split()[0])


def resolve_effective_mode(state, snapshot, weather, previous_mode=None):
    if state.get("heatingEnabled") is True:
        return "heating"

    selection = state.get("selection", "automatic")
    if selection in ("summer", "transition"):
        return selection

    try:
        indoor_temperature = parse_temperature(snapshot["indoor"]["temperature"])
        if indoor_temperature >= 23.5:
            return "summer"
        if previous_mode == "summer" and indoor_temperature >= 22.5:
            return "summer"
    except (KeyError, TypeError, ValueError):
        pass

    try:
        weather_timestamp = datetime.fromisoformat(
            weather["timestamp"].replace("Z", "+00:00")
        )
        if weather_timestamp.tzinfo is None:
            weather_timestamp = weather_timestamp.astimezone()
        age = abs((datetime.now().astimezone() - weather_timestamp).total_seconds())
        if age <= 90 * 60:
            now = datetime.now().astimezone()
            horizon = now + timedelta(hours=6)
            readings = [weather["current"]]
            for reading in weather.get("hourlyForecast", []):
                timestamp = datetime.fromisoformat(
                    reading["timestamp"].replace("Z", "+00:00")
                )
                if timestamp.tzinfo is None:
                    timestamp = timestamp.astimezone()
                if now <= timestamp <= horizon:
                    readings.append(reading)
            temperatures = [parse_temperature(item["temperature"]) for item in readings]
            if max(temperatures, default=float("-inf")) >= 20:
                return "summer"
    except (KeyError, TypeError, ValueError):
        pass

    return "transition"


def read_operating_mode(snapshot, weather, previous_mode=None):
    state = {
        "version": 1,
        "heatingEnabled": False,
        "selection": "automatic",
        "updatedAt": None,
    }
    error = None
    path = DATA_ROOT / "operating-mode.json"
    try:
        saved_state = read_optional_json(path)
        if saved_state is not None:
            if saved_state.get("selection") not in (
                "automatic",
                "summer",
                "transition",
            ) or not isinstance(saved_state.get("heatingEnabled"), bool):
                raise ValueError("unbekannte Einstellung")
            state.update(saved_state)
    except Exception as read_error:
        error = f"Betriebsart konnte nicht geladen werden: {read_error}"

    state["effectiveMode"] = resolve_effective_mode(
        state, snapshot, weather, previous_mode
    )
    return state, error


def read_daily_history_summary(history_path):
    entries = []
    skipped_line_count = 0

    if history_path.exists():
        with history_path.open(encoding="utf-8") as file:
            for line in file:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                    timestamp_value = entry["timestamp"]
                    timestamp = datetime.fromisoformat(
                        timestamp_value.replace("Z", "+00:00")
                    )
                    if timestamp.tzinfo is None:
                        timestamp = timestamp.astimezone()
                    entries.append((timestamp, timestamp_value))
                except (KeyError, TypeError, ValueError, json.JSONDecodeError):
                    skipped_line_count += 1

    entries.sort(key=lambda entry: entry[0])
    return {
        "measurementCount": len(entries),
        "firstMeasurement": entries[0][1] if entries else None,
        "lastMeasurement": entries[-1][1] if entries else None,
        "skippedLineCount": skipped_line_count,
    }


def read_dashboard_data():
    snapshot_path = DATA_ROOT / "current.json"
    if not snapshot_path.exists():
        raise FileNotFoundError(f"Sensordatei nicht gefunden: {snapshot_path}")

    with snapshot_path.open(encoding="utf-8") as file:
        snapshot = json.load(file)

    history_date = datetime.now().astimezone().strftime("%Y-%m-%d")
    history_path = DATA_ROOT / "history" / f"{history_date}.jsonl"
    history = []

    if history_path.exists():
        with history_path.open(encoding="utf-8") as file:
            for line_number, line in enumerate(file, start=1):
                if line.strip():
                    try:
                        history.append(json.loads(line))
                    except json.JSONDecodeError as error:
                        raise ValueError(
                            f"Ungültiger Verlauf in Zeile {line_number}: {error}"
                        ) from error

    weather = None
    weather_error = None
    weather_path = DATA_ROOT / "weather" / "current.json"
    if weather_path.exists():
        try:
            with weather_path.open(encoding="utf-8") as file:
                weather = json.load(file)
            if not isinstance(weather, dict) or not isinstance(
                weather.get("current"), dict
            ):
                raise ValueError("Aktuelle Wetterbeobachtung fehlt")
        except Exception as error:
            weather = None
            weather_error = f"Wetterdaten konnten nicht geladen werden: {error}"

    recommendation = None
    recommendation_path = DATA_ROOT / "current-recommendation.json"
    if recommendation_path.exists():
        try:
            with recommendation_path.open(encoding="utf-8") as file:
                recommendation = json.load(file)
        except Exception:
            recommendation = None

    seasonal_recommendation = None
    seasonal_recommendation_error = None
    seasonal_path = DATA_ROOT / "seasonal-recommendation" / "current.json"
    try:
        seasonal_recommendation = read_optional_json(seasonal_path)
    except Exception as error:
        seasonal_recommendation_error = (
            f"Schattenauswertung konnte nicht geladen werden: {error}"
        )

    previous_mode = None
    if isinstance(seasonal_recommendation, dict):
        previous_mode = seasonal_recommendation.get("effectiveMode")
    operating_mode, operating_mode_error = read_operating_mode(
        snapshot, weather, previous_mode
    )

    additional_sensor_snapshot = None
    additional_sensor_error = None
    additional_sensor_path = DATA_ROOT / "additional-sensors" / "current.json"
    if additional_sensor_path.exists():
        try:
            with additional_sensor_path.open(encoding="utf-8") as file:
                additional_sensor_snapshot = json.load(file)
            if not isinstance(additional_sensor_snapshot, dict) or not isinstance(
                additional_sensor_snapshot.get("sensors"), list
            ):
                raise ValueError("Liste der Zusatzsensoren fehlt")
        except Exception as error:
            additional_sensor_snapshot = None
            additional_sensor_error = (
                f"Zusatzsensordaten konnten nicht geladen werden: {error}"
            )

    additional_history_error = None
    additional_history_path = (
        DATA_ROOT / "additional-sensors" / "history" / f"{history_date}.jsonl"
    )
    try:
        additional_history_summary = read_daily_history_summary(
            additional_history_path
        )
        skipped_line_count = additional_history_summary.pop("skippedLineCount")
        if skipped_line_count:
            additional_history_error = (
                "Zusatzhistorie teilweise geladen: "
                f"{skipped_line_count} beschädigte Einträge wurden ignoriert."
            )
    except Exception as error:
        additional_history_summary = {
            "measurementCount": 0,
            "firstMeasurement": None,
            "lastMeasurement": None,
        }
        additional_history_error = (
            f"Zusatzhistorie konnte nicht geladen werden: {error}"
        )

    heating_room_overrides = heating_room_overrides_payload()
    return {
        "snapshot": snapshot,
        "sensorAcquisition": read_optional_json(DATA_ROOT / "sensor-input" / "current-status.json"),
        "history": history,
        "weather": weather,
        "weatherError": weather_error,
        "recommendation": recommendation,
        "operatingMode": operating_mode,
        "operatingModeError": operating_mode_error,
        "seasonalRecommendation": seasonal_recommendation,
        "seasonalRecommendationError": seasonal_recommendation_error,
        "ventilationSession": ventilation_session_payload(),
        "heatingThermostats": [read_optional_json(HEATING_DIRECTORY / f"{thermostat['snapshotID']}.json") for thermostats in HEATING_THERMOSTATS.values() for thermostat in thermostats],
        "heatingVentilationControl": read_optional_json(HEATING_CONTROL_PATH),
        "heatingRoomOverrides": heating_room_overrides,
        "heatingRoomComfort": heating_room_comfort_payload(),
        "heatingPrototype": heating_prototype_payload(overrides=heating_room_overrides),
        "additionalSensorSnapshot": additional_sensor_snapshot,
        "additionalSensorAcquisition": read_optional_json(DATA_ROOT / "additional-sensors" / "current-status.json"),
        "additionalSensorError": additional_sensor_error,
        "additionalHistorySummary": additional_history_summary,
        "additionalHistoryError": additional_history_error,
        "biasCalibration": read_optional_json(DATA_ROOT / "bias-calibration.json"),
        "servedAt": datetime.now().astimezone().isoformat(),
    }


class ClimateEngineHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/api/dashboard":
            self.send_dashboard()
            return

        relative_path = "index.html" if path == "/" else path.lstrip("/")
        file_path = (WEB_ROOT / relative_path).resolve()

        if WEB_ROOT not in file_path.parents or not file_path.is_file():
            self.send_error(404, "Nicht gefunden")
            return

        content_type, _ = mimetypes.guess_type(file_path.name)
        content = file_path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type or "application/octet-stream")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(content)

    def do_POST(self):
        path = urlparse(self.path).path
        if path not in (
            "/api/ventilation-session",
            "/api/heating-room-override",
            "/api/heating-room-comfort",
        ):
            self.send_error(404, "Nicht gefunden")
            return

        origin = self.headers.get("Origin")
        host = self.headers.get("Host")
        if not origin or not host or origin not in (f"http://{host}", f"https://{host}"):
            self.send_json({"error": "Ungültiger Ursprung"}, status=403)
            return

        if self.headers.get_content_type() != "application/json":
            self.send_json({"error": "JSON erwartet"}, status=415)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 1024:
                raise ValueError("Ungültige Anfragegrösse")
            request = json.loads(self.rfile.read(length))
            if path == "/api/ventilation-session":
                action = request.get("action")
                if action not in ("start", "stop"):
                    raise ValueError("Unbekannte Aktion")
                self.send_json(write_ventilation_session(action == "start"))
            elif path == "/api/heating-room-override":
                self.send_json(write_heating_room_override(
                    request.get("roomID"), request.get("windowOpen")
                ))
            else:
                self.send_json(write_heating_room_comfort(
                    request.get("roomID"), request.get("active")
                ))
        except ComfortUnavailableError as error:
            self.send_json({"error": str(error)}, status=409)
        except (TypeError, ValueError, json.JSONDecodeError) as error:
            self.send_json({"error": str(error)}, status=400)
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
            self.send_json({"error": str(error)}, status=502)

    def send_json(self, value, status=200):
        payload = json.dumps(
            value,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def send_dashboard(self):
        try:
            payload = json.dumps(
                read_dashboard_data(),
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")
            status = 200
        except Exception as error:
            payload = json.dumps(
                {"error": str(error)},
                ensure_ascii=False,
            ).encode("utf-8")
            status = 500

        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        if args and str(args[1]) != "200":
            super().log_message(format, *args)


def local_ip():
    connection = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        connection.connect(("192.0.2.1", 80))
        return connection.getsockname()[0]
    except OSError:
        return "localhost"
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description="Lokales ClimateEngine-Dashboard")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", default=8080, type=int)
    arguments = parser.parse_args()

    server = ThreadingHTTPServer(
        (arguments.host, arguments.port),
        ClimateEngineHandler,
    )
    print("ClimateEngine Web läuft.")
    print(f"Auf diesem Mac: http://localhost:{arguments.port}")
    print(f"Auf dem iPhone:  http://{local_ip()}:{arguments.port}")
    print("Zum Beenden Ctrl+C drücken.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nClimateEngine Web beendet.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
