import importlib.util
import tempfile
import unittest
from unittest.mock import patch
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
        self.original_control_path = SERVER.HEATING_CONTROL_PATH
        SERVER.VENTILATION_SESSION_PATH = Path(self.temporary_directory.name) / "ventilation-session.json"
        SERVER.HEATING_CONTROL_PATH = Path(self.temporary_directory.name) / "heating-control.json"
        self.heating_enabled = patch.object(SERVER, "heating_enabled", return_value=False)
        self.heating_command = patch.object(SERVER, "run_heating_shortcut")
        self.heating_enabled_mock = self.heating_enabled.start()
        self.heating_command_mock = self.heating_command.start()

    def tearDown(self):
        SERVER.VENTILATION_SESSION_PATH = self.original_path
        SERVER.HEATING_CONTROL_PATH = self.original_control_path
        self.heating_command.stop()
        self.heating_enabled.stop()
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

    def test_heating_is_suspended_and_restored_when_enabled(self):
        self.heating_enabled_mock.return_value = True
        now = datetime(2026, 10, 1, 8, 0, tzinfo=timezone.utc)
        SERVER.write_ventilation_session(True, now=now)
        SERVER.write_ventilation_session(False, now=now + timedelta(minutes=2))
        self.assertEqual(
            [call.args for call in self.heating_command_mock.call_args_list],
            [
                ("buero-alois", "off"), ("bad-alois", "off"), ("sauna", "off"),
                ("buero-alois", "on"), ("bad-alois", "on"), ("sauna", "on"),
            ],
        )

    def test_one_failed_thermostat_does_not_block_the_others(self):
        self.heating_enabled_mock.return_value = True
        self.heating_command_mock.side_effect = lambda room_id, action: (
            (_ for _ in ()).throw(RuntimeError("offline"))
            if room_id == "bad-alois" else None
        )
        SERVER.suspend_heating_for_ventilation()
        state = SERVER.read_optional_json(SERVER.HEATING_CONTROL_PATH)
        self.assertEqual(state["suspendedRoomIDs"], ["buero-alois", "sauna"])
        SERVER.reconcile_heating_after_ventilation()
        state = SERVER.read_optional_json(SERVER.HEATING_CONTROL_PATH)
        self.assertFalse(state["suspended"])


class HeatingRoomPrototypeTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.original_path = SERVER.HEATING_ROOM_OVERRIDES_PATH
        SERVER.HEATING_ROOM_OVERRIDES_PATH = (
            Path(self.temporary_directory.name) / "room-overrides.json"
        )

    def tearDown(self):
        SERVER.HEATING_ROOM_OVERRIDES_PATH = self.original_path
        self.temporary_directory.cleanup()

    def test_window_override_is_persisted_and_cleared(self):
        opened = SERVER.write_heating_room_override("buero-alois", True)
        self.assertEqual(opened["openRoomIDs"], ["buero-alois"])
        self.assertTrue(SERVER.heating_prototype_payload(overrides=opened)["wouldDisableHeating"])
        closed = SERVER.write_heating_room_override("buero-alois", False)
        self.assertEqual(closed["openRoomIDs"], [])

    def test_weekend_schedule_uses_later_start(self):
        saturday = datetime(2026, 9, 19, 7, 0, tzinfo=timezone.utc)
        payload = SERVER.heating_prototype_payload(now=saturday)
        self.assertEqual(payload["period"], "night")
        self.assertEqual(payload["targetTemperature"], 18.0)
        self.assertEqual(payload["comfortStartMinute"], 450)

    def test_galerie_window_override_is_persisted_independently(self):
        SERVER.write_heating_room_override("buero-alois", True)
        opened = SERVER.write_heating_room_override("galerie", True)
        self.assertEqual(opened["openRoomIDs"], ["buero-alois", "galerie"])
        self.assertTrue(SERVER.heating_prototype_payload(overrides=opened)["wouldDisableHeating"])
        closed = SERVER.write_heating_room_override("galerie", False)
        self.assertEqual(closed["openRoomIDs"], ["buero-alois"])

    def test_other_rooms_are_rejected_in_prototype(self):
        with self.assertRaises(ValueError):
            SERVER.write_heating_room_override("sauna", True)


if __name__ == "__main__":
    unittest.main()
