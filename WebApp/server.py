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
DATA_ROOT = Path.home() / "Documents" / "ClimateEngine"


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

    return {
        "snapshot": snapshot,
        "history": history,
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
