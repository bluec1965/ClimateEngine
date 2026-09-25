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
        self.original_overrides_path = SERVER.HEATING_ROOM_OVERRIDES_PATH
        SERVER.VENTILATION_SESSION_PATH = Path(self.temporary_directory.name) / "ventilation-session.json"
        SERVER.HEATING_CONTROL_PATH = Path(self.temporary_directory.name) / "heating-control.json"
        SERVER.HEATING_ROOM_OVERRIDES_PATH = Path(self.temporary_directory.name) / "room-overrides.json"
        self.heating_enabled = patch.object(SERVER, "heating_enabled", return_value=False)
        self.heating_command = patch.object(SERVER, "run_heating_shortcut")
        self.heating_enabled_mock = self.heating_enabled.start()
        self.heating_command_mock = self.heating_command.start()

    def tearDown(self):
        SERVER.VENTILATION_SESSION_PATH = self.original_path
        SERVER.HEATING_CONTROL_PATH = self.original_control_path
        SERVER.HEATING_ROOM_OVERRIDES_PATH = self.original_overrides_path
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
                ("schlafzimmer", "off"), ("buero-peter", "off"),
                ("buero-alois", "off"), ("bad-alois", "off"), ("sauna", "off"),
                ("galerie", "off"), ("dachzimmer", "off"),
                ("schlafzimmer", "on"), ("buero-peter", "on"),
                ("buero-alois", "on"), ("bad-alois", "on"), ("sauna", "on"),
                ("galerie", "on"), ("dachzimmer", "on"),
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
        self.assertEqual(
            state["suspendedRoomIDs"],
            ["schlafzimmer", "buero-peter", "buero-alois", "sauna", "galerie", "dachzimmer"],
        )
        SERVER.reconcile_heating_after_ventilation()
        state = SERVER.read_optional_json(SERVER.HEATING_CONTROL_PATH)
        self.assertFalse(state["suspended"])


class HeatingRoomPrototypeTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.original_path = SERVER.HEATING_ROOM_OVERRIDES_PATH
        self.original_comfort_path = SERVER.HEATING_ROOM_COMFORT_PATH
        SERVER.HEATING_ROOM_OVERRIDES_PATH = (
            Path(self.temporary_directory.name) / "room-overrides.json"
        )
        SERVER.HEATING_ROOM_COMFORT_PATH = (
            Path(self.temporary_directory.name) / "room-comfort.json"
        )
        self.heating_enabled = patch.object(SERVER, "heating_enabled", return_value=True)
        self.read_heating = patch.object(SERVER, "read_room_heating", return_value=True)
        self.apply_target = patch.object(
            SERVER, "apply_room_target", side_effect=lambda _room, _action, target: target
        )
        self.set_heating = patch.object(SERVER, "set_room_heating_enabled")
        self.ventilation = patch.object(
            SERVER, "ventilation_session_payload", return_value={"active": False}
        )
        self.heating_enabled_mock = self.heating_enabled.start()
        self.read_heating_mock = self.read_heating.start()
        self.apply_target_mock = self.apply_target.start()
        self.set_heating_mock = self.set_heating.start()
        self.ventilation_mock = self.ventilation.start()

    def tearDown(self):
        SERVER.HEATING_ROOM_OVERRIDES_PATH = self.original_path
        SERVER.HEATING_ROOM_COMFORT_PATH = self.original_comfort_path
        self.ventilation.stop()
        self.set_heating.stop()
        self.apply_target.stop()
        self.read_heating.stop()
        self.heating_enabled.stop()
        self.temporary_directory.cleanup()

    def test_window_override_is_persisted_and_cleared(self):
        now = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
        opened = SERVER.write_heating_room_override("buero-alois", True, now=now)
        self.assertEqual(opened["openRoomIDs"], ["buero-alois"])
        self.assertTrue(SERVER.heating_prototype_payload(overrides=opened)["wouldDisableHeating"])
        self.set_heating_mock.assert_called_once_with("buero-alois", False)
        closed = SERVER.write_heating_room_override("buero-alois", False, now=now)
        self.assertEqual(closed["openRoomIDs"], [])
        self.assertEqual(
            [call.args for call in self.set_heating_mock.call_args_list],
            [("buero-alois", False), ("buero-alois", True)],
        )
        self.apply_target_mock.assert_called_once_with("buero-alois", "revert-21.5", 21.5)

    def test_closing_window_restores_active_comfort(self):
        now = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
        SERVER.write_heating_room_comfort("sauna", True, now=now)
        SERVER.write_heating_room_override("sauna", True, now=now)
        self.apply_target_mock.reset_mock()
        SERVER.write_heating_room_override("sauna", False, now=now)
        self.set_heating_mock.assert_called_with("sauna", True)
        self.apply_target_mock.assert_called_once_with("sauna", "comfort", 24.0)

    def test_failed_window_command_keeps_safe_open_state(self):
        self.set_heating_mock.side_effect = RuntimeError("Thermostat nicht erreichbar")
        with self.assertRaises(RuntimeError):
            SERVER.write_heating_room_override("bad-alois", True)
        self.assertEqual(
            SERVER.heating_room_overrides_payload()["openRoomIDs"], ["bad-alois"]
        )

    def test_failed_close_keeps_window_open(self):
        SERVER.write_heating_room_override("bad-alois", True)
        self.set_heating_mock.side_effect = RuntimeError("Thermostat nicht erreichbar")
        with self.assertRaises(RuntimeError):
            SERVER.write_heating_room_override("bad-alois", False)
        self.assertEqual(
            SERVER.heating_room_overrides_payload()["openRoomIDs"], ["bad-alois"]
        )

    def test_window_state_does_not_control_heating_when_global_heating_is_off(self):
        self.heating_enabled_mock.return_value = False
        SERVER.write_heating_room_override("sauna", True)
        SERVER.write_heating_room_override("sauna", False)
        self.set_heating_mock.assert_not_called()

    def test_gallery_window_controls_its_thermostat(self):
        SERVER.write_heating_room_override("galerie", True)
        SERVER.write_heating_room_override("galerie", False)
        self.assertEqual(
            [call.args for call in self.set_heating_mock.call_args_list],
            [("galerie", False), ("galerie", True)],
        )

    def test_dachzimmer_window_and_comfort_are_room_wide(self):
        now = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
        SERVER.write_heating_room_override("dachzimmer", True, now=now)
        SERVER.write_heating_room_override("dachzimmer", False, now=now)
        self.assertEqual(
            [call.args for call in self.set_heating_mock.call_args_list],
            [("dachzimmer", False), ("dachzimmer", True)],
        )
        SERVER.write_heating_room_comfort("dachzimmer", True, now=now)
        self.apply_target_mock.assert_called_with("dachzimmer", "comfort", 24.0)

    def test_new_rooms_have_independent_window_and_comfort_controls(self):
        now = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
        SERVER.write_heating_room_override("schlafzimmer", True, now=now)
        opened = SERVER.write_heating_room_override("buero-peter", True, now=now)
        self.assertEqual(opened["openRoomIDs"], ["buero-peter", "schlafzimmer"])
        SERVER.write_heating_room_override("schlafzimmer", False, now=now)
        SERVER.write_heating_room_override("buero-peter", False, now=now)
        SERVER.write_heating_room_comfort("schlafzimmer", True, now=now)
        state = SERVER.write_heating_room_comfort("buero-peter", True, now=now)
        self.assertEqual(state["activeRoomIDs"], ["buero-peter", "schlafzimmer"])

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
            SERVER.write_heating_room_override("stube", True)

    def test_all_three_heating_prototype_windows_are_independent(self):
        SERVER.write_heating_room_override("buero-alois", True)
        SERVER.write_heating_room_override("bad-alois", True)
        opened = SERVER.write_heating_room_override("sauna", True)
        self.assertEqual(
            opened["openRoomIDs"], ["bad-alois", "buero-alois", "sauna"]
        )
        closed = SERVER.write_heating_room_override("bad-alois", False)
        self.assertEqual(closed["openRoomIDs"], ["buero-alois", "sauna"])

    def test_comfort_is_applied_and_persisted_after_fresh_read(self):
        now = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
        state = SERVER.write_heating_room_comfort("buero-alois", True, now=now)
        self.assertEqual(state["activeRoomIDs"], ["buero-alois"])
        self.assertEqual(state["lastAppliedTargetTemperature"], 24.0)
        self.read_heating_mock.assert_called_once_with("buero-alois")
        self.apply_target_mock.assert_called_once_with("buero-alois", "comfort", 24.0)
        self.assertEqual(
            SERVER.heating_room_comfort_payload()["activeRoomIDs"], ["buero-alois"]
        )

    def test_comfort_is_rejected_when_heating_is_disabled(self):
        self.heating_enabled_mock.return_value = False
        with self.assertRaises(SERVER.ComfortUnavailableError):
            SERVER.write_heating_room_comfort("buero-alois", True)
        self.read_heating_mock.assert_not_called()
        self.apply_target_mock.assert_not_called()

    def test_comfort_is_rejected_for_open_window_or_ventilation(self):
        SERVER.write_heating_room_override("buero-alois", True)
        with self.assertRaises(SERVER.ComfortUnavailableError):
            SERVER.write_heating_room_comfort("buero-alois", True)
        SERVER.write_heating_room_override("buero-alois", False)
        self.ventilation_mock.return_value = {"active": True}
        with self.assertRaises(SERVER.ComfortUnavailableError):
            SERVER.write_heating_room_comfort("buero-alois", True)

    def test_comfort_is_rejected_when_fresh_thermostat_read_is_off(self):
        self.read_heating_mock.return_value = False
        with self.assertRaises(SERVER.ComfortUnavailableError):
            SERVER.write_heating_room_comfort("buero-alois", True)
        self.apply_target_mock.assert_not_called()

    def test_comfort_reverts_to_current_weekday_schedule(self):
        now = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
        SERVER.write_heating_room_comfort("buero-alois", True, now=now)
        self.apply_target_mock.reset_mock()
        state = SERVER.write_heating_room_comfort("buero-alois", False, now=now)
        self.assertEqual(state["activeRoomIDs"], [])
        self.assertEqual(state["lastAppliedTargetTemperature"], 21.5)
        self.apply_target_mock.assert_called_once_with("buero-alois", "revert-21.5", 21.5)

    def test_comfort_reverts_to_night_schedule(self):
        now = datetime(2026, 9, 18, 23, 0, tzinfo=timezone.utc)
        state = SERVER.write_heating_room_comfort("buero-alois", False, now=now)
        self.assertEqual(state["lastAppliedTargetTemperature"], 18.0)
        self.apply_target_mock.assert_called_once_with("buero-alois", "revert-18.0", 18.0)

    def test_comfort_rooms_are_persisted_independently(self):
        now = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
        SERVER.write_heating_room_comfort("buero-alois", True, now=now)
        state = SERVER.write_heating_room_comfort("sauna", True, now=now)
        self.assertEqual(state["activeRoomIDs"], ["buero-alois", "sauna"])
        state = SERVER.write_heating_room_comfort("bad-alois", True, now=now)
        self.assertEqual(
            state["activeRoomIDs"], ["bad-alois", "buero-alois", "sauna"]
        )
        state = SERVER.write_heating_room_comfort("sauna", False, now=now)
        self.assertEqual(state["activeRoomIDs"], ["bad-alois", "buero-alois"])
        self.assertEqual(
            state["lastAppliedTargetTemperatures"],
            {"bad-alois": 24.0, "buero-alois": 24.0, "sauna": 21.5},
        )


class HeatingComfortShortcutTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.original_heating_directory = SERVER.HEATING_DIRECTORY
        SERVER.HEATING_DIRECTORY = Path(self.temporary_directory.name) / "heating"

    def tearDown(self):
        SERVER.HEATING_DIRECTORY = self.original_heating_directory
        self.temporary_directory.cleanup()

    def test_write_is_confirmed_with_independent_read_shortcut(self):
        with patch.object(
            SERVER,
            "run_shortcut_with_output",
            side_effect=["", "21.5 °C\n2\n1\n24 °C"],
        ) as command:
            self.assertEqual(
                SERVER.apply_room_target("buero-alois", "comfort", 24.0), 24.0
            )
        self.assertEqual(
            [call.args[0] for call in command.call_args_list],
            [
                "ClimateEngine Heating Büro Alois Comfort",
                "ClimateEngine Read Heating Büro Alois",
            ],
        )

    def test_stale_read_back_target_does_not_reject_successful_write(self):
        with patch.object(
            SERVER,
            "run_shortcut_with_output",
            side_effect=["", "21.5 °C\n2\n1\n21.5 °C"],
        ):
            self.assertEqual(
                SERVER.apply_room_target("buero-alois", "comfort", 24.0), 24.0
            )
        snapshot = SERVER.read_optional_json(
            SERVER.HEATING_DIRECTORY / "buero-alois.json"
        )
        self.assertEqual(snapshot["targetTemperature"], 24.0)

    def test_stale_homekit_target_is_persisted_as_successful_write(self):
        with patch.object(
            SERVER,
            "run_shortcut_with_output",
            side_effect=[
                "",
                "22 °C\n2\n1\n21.5 °C",
            ],
        ):
            self.assertEqual(SERVER.apply_room_target("galerie", "comfort", 24.0), 24.0)
        snapshot = SERVER.read_optional_json(SERVER.HEATING_DIRECTORY / "galerie.json")
        self.assertEqual(snapshot["targetTemperature"], 24.0)
        self.assertTrue(snapshot["isEnabled"])

    def test_sauna_uses_its_own_shortcuts(self):
        with patch.object(
            SERVER,
            "run_shortcut_with_output",
            side_effect=["", "21.0 °C\n2\n1\n24 °C"],
        ) as command:
            self.assertEqual(SERVER.apply_room_target("sauna", "comfort", 24.0), 24.0)
        self.assertEqual(
            [call.args[0] for call in command.call_args_list],
            ["ClimateEngine Heating Sauna Comfort", "ClimateEngine Read Heating Sauna"],
        )

    def test_new_rooms_use_their_own_shortcuts(self):
        cases = [
            ("schlafzimmer", "ClimateEngine Heating Schlafzimmer Comfort", "ClimateEngine Read Heating Schlafzimmer"),
            ("buero-peter", "ClimateEngine Heating Büro Peter Comfort", "ClimateEngine Read Heating Büro Peter"),
        ]
        for room_id, comfort_shortcut, read_shortcut in cases:
            with self.subTest(room_id=room_id), patch.object(
                SERVER,
                "run_shortcut_with_output",
                side_effect=["", "21.0 °C\n2\n1\n24 °C"],
            ) as command:
                self.assertEqual(SERVER.apply_room_target(room_id, "comfort", 24.0), 24.0)
            self.assertEqual(
                [call.args[0] for call in command.call_args_list],
                [comfort_shortcut, read_shortcut],
            )

    def test_dachzimmer_confirms_both_thermostat_targets(self):
        with patch.object(
            SERVER,
            "run_shortcut_with_output",
            side_effect=[
                "", "",
                "21.0 °C\n2\n1\n24 °C",
                "21.2 °C\n2\n1\n24 °C",
            ],
        ) as command:
            self.assertEqual(
                SERVER.apply_room_target("dachzimmer", "comfort", 24.0), 24.0
            )
        self.assertEqual(
            [call.args[0] for call in command.call_args_list],
            [
                "ClimateEngine Heating Dachzimmer Wand Comfort",
                "ClimateEngine Heating Dachzimmer Fenster Comfort",
                "ClimateEngine Read Heating Dachzimmer Wand",
                "ClimateEngine Read Heating Dachzimmer Fenster",
            ],
        )

    def test_dachzimmer_writes_both_despite_stale_second_target(self):
        with patch.object(
            SERVER,
            "run_shortcut_with_output",
            side_effect=[
                "", "",
                "21.0 °C\n2\n1\n24 °C",
                "21.2 °C\n2\n1\n21.5 °C",
            ],
        ) as command:
            self.assertEqual(
                SERVER.apply_room_target("dachzimmer", "comfort", 24.0), 24.0
            )
        self.assertEqual(command.call_args_list[1].args[0], "ClimateEngine Heating Dachzimmer Fenster Comfort")

    def test_dachzimmer_off_writes_both_even_when_read_is_stale(self):
        with patch.object(SERVER, "run_heating_shortcut") as command, patch.object(
            SERVER,
            "run_shortcut_with_output",
            side_effect=[
                "21.0 °C\n2\n0\n18 °C",
                "21.2 °C\n2\n1\n18 °C",
            ],
        ):
            SERVER.set_room_heating_enabled("dachzimmer", False)
        command.assert_called_once_with("dachzimmer", "off")


if __name__ == "__main__":
    unittest.main()
