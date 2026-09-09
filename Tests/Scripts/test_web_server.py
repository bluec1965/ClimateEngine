import importlib.util
import unittest
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


if __name__ == "__main__":
    unittest.main()
