import importlib.util
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).parents[2] / "Scripts" / "run-bias-calibration.py"
SPEC = importlib.util.spec_from_file_location("bias_calibration", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class BiasCalibrationTests(unittest.TestCase):
    def test_stable_profiles_are_green_and_weekly_changes_are_limited(self):
        now = datetime(2026, 9, 15, 12, tzinfo=timezone.utc)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "history").mkdir(parents=True)
            (root / "additional-sensors" / "history").mkdir(parents=True)
            main_path = root / "history" / "2026-09-15.jsonl"
            additional_path = root / "additional-sensors" / "history" / "2026-09-15.jsonl"
            with main_path.open("w", encoding="utf-8") as main, additional_path.open("w", encoding="utf-8") as additional:
                for index in range(500):
                    timestamp = now - timedelta(minutes=index * 5)
                    stamp = timestamp.isoformat().replace("+00:00", "Z")
                    rooms = []
                    sensors = []
                    for room_id, (baseline_id, adjusted_id, _, _) in MODULE.ROOMS.items():
                        rooms.append({"id": baseline_id, "measurement": {"temperature": 21.0, "humidity": 50.0}})
                        sensors.append({"id": adjusted_id, "measurement": {"temperature": 20.0, "humidity": 48.0}})
                    outdoors = [
                        {"id": "eve-degree", "measurement": {"temperature": 10.0, "humidity": 70.0}},
                        {"id": "homepod-terrasse", "measurement": {"temperature": 9.0, "humidity": 68.0}},
                    ]
                    main.write(json.dumps({"timestamp": stamp, "indoorRooms": rooms, "outdoorSensors": outdoors}) + "\n")
                    additional.write(json.dumps({"timestamp": stamp, "sensors": sensors}) + "\n")

            document = MODULE.calibrate(root, now=now, force=True)
            profiles = {profile["roomID"]: profile for profile in document["profiles"]}
            self.assertTrue(all(not profile["isProvisional"] for profile in profiles.values()))
            self.assertEqual(profiles["buero-alois"]["temperatureAdjustment"], 1.0)
            self.assertEqual(profiles["terrasse"]["temperatureAdjustment"], 0.3)

            unchanged = MODULE.calibrate(root, now=now + timedelta(days=6))
            self.assertEqual(unchanged["generatedAt"], document["generatedAt"])


if __name__ == "__main__":
    unittest.main()
