#!/usr/bin/env python3

import argparse
import json
import mimetypes
import socket
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


WEB_ROOT = Path(__file__).resolve().parent
DATA_ROOT = Path.home() / "Library" / "Application Support" / "ClimateEngine"


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

    return {
        "snapshot": snapshot,
        "history": history,
        "weather": weather,
        "weatherError": weather_error,
        "recommendation": recommendation,
        "additionalSensorSnapshot": additional_sensor_snapshot,
        "additionalSensorError": additional_sensor_error,
        "additionalHistorySummary": additional_history_summary,
        "additionalHistoryError": additional_history_error,
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
