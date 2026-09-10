import importlib.util
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "climateengine_web_server", ROOT / "WebApp" / "server.py"
)
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)


class OperatingModeHysteresisTests(unittest.TestCase):
    def setUp(self):
        self.state = {
            "heatingEnabled": False,
            "selection": "automatic",
        }

    @staticmethod
    def snapshot(temperature):
        return {"indoor": {"temperature": temperature}}

    def test_enters_summer_at_upper_threshold(self):
        self.assertEqual(
            SERVER.resolve_effective_mode(
                self.state, self.snapshot(23.5), None, "transition"
            ),
            "summer",
        )

    def test_deadband_preserves_previous_mode(self):
        self.assertEqual(
            SERVER.resolve_effective_mode(
                self.state, self.snapshot(23.0), None, "summer"
            ),
            "summer",
        )
        self.assertEqual(
            SERVER.resolve_effective_mode(
                self.state, self.snapshot(23.0), None, "transition"
            ),
            "transition",
        )

    def test_leaves_summer_below_lower_threshold(self):
        self.assertEqual(
            SERVER.resolve_effective_mode(
                self.state, self.snapshot(22.49), None, "summer"
            ),
            "transition",
        )


class VentilationSessionTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.original_path = SERVER.VENTILATION_SESSION_PATH
        SERVER.VENTILATION_SESSION_PATH = Path(self.temporary_directory.name) / "ventilation-session.json"

    def tearDown(self):
        SERVER.VENTILATION_SESSION_PATH = self.original_path
        self.temporary_directory.cleanup()

    def test_start_and_stop_are_persisted(self):
        now = datetime(2026, 10, 1, 8, 0, tzinfo=timezone.utc)
        started = SERVER.write_ventilation_session(True, now=now)
        self.assertTrue(started["active"])
        self.assertEqual(started["remainingSeconds"], 600)
        stopped = SERVER.write_ventilation_session(False, now=now + timedelta(minutes=2))
        self.assertFalse(stopped["active"])
        self.assertEqual(stopped["remainingSeconds"], 0)

    def test_session_expires_without_a_timer_process(self):
        now = datetime(2026, 10, 1, 8, 0, tzinfo=timezone.utc)
        SERVER.write_ventilation_session(True, now=now)
        expired = SERVER.ventilation_session_payload(now=now + timedelta(minutes=10))
        self.assertFalse(expired["active"])


if __name__ == "__main__":
    unittest.main()
