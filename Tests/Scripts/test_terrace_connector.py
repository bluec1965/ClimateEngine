import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("terrace", ROOT / "Scripts/run-terrace-connector.py")
terrace = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terrace)
CONFIG = {
    "version": 1, "indoorShortcut": "indoor", "eveShortcut": "eve",
    "homepodShortcut": "homepod", "processingShortcut": "process",
}


class TerraceConnectorTests(unittest.TestCase):
    def test_additional_starter_does_not_use_main_terrace_configuration(self):
        with tempfile.TemporaryDirectory(prefix="climateengine-routing-test-") as temp:
            directory = Path(temp)
            config = directory / "terrace.json"
            config.write_text(json.dumps(CONFIG))
            fake_shortcuts = directory / "shortcuts"
            fake_shortcuts.write_text('#!/bin/zsh\nprint -r -- "$2"\n')
            fake_shortcuts.chmod(0o700)
            environment = dict(os.environ,
                CLIMATEENGINE_SHORTCUT_NAME="ClimateEngine Additional Sensor Connector",
                CLIMATEENGINE_TERRACE_CONFIG=str(config),
                CLIMATEENGINE_ADDITIONAL_CONFIG=str(directory / "missing-additional.json"),
                CLIMATEENGINE_SHORTCUTS_COMMAND=str(fake_shortcuts),
                CLIMATEENGINE_RETRY_LOCK=str(directory / "lock"),
                CLIMATEENGINE_RETRY_LOG=str(directory / "log"),
            )
            result = subprocess.run([str(ROOT / "Scripts/run-sensor-connector.sh")],
                env=environment, text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "ClimateEngine Additional Sensor Connector")

    def test_read_time_budget_scales_for_indoor_group(self):
        with tempfile.TemporaryDirectory(prefix="climateengine-budget-test-") as temp:
            with patch.object(terrace.subprocess, "run", return_value=types.SimpleNamespace(returncode=1)) as run:
                terrace.read_sensors("indoor", ["stube", "schlafzimmer", "buero-alois", "sauna"], "shortcuts", Path(temp), 0)
                self.assertEqual(run.call_args.kwargs["timeout"], 60)
                terrace.read_sensors("eve", ["eve-degree"], "shortcuts", Path(temp), 1)
                self.assertEqual(run.call_args.kwargs["timeout"], 25)

    def simulate(self, failing=(), timeout=(), invalid=(), collect_only=False, process_code=0):
        calls, inputs = [], []

        def fake_run(args, **kwargs):
            name = args[2]
            calls.append(name)
            if name in timeout:
                raise subprocess.TimeoutExpired(args, 25)
            if name == "process":
                inputs.append(json.loads(Path(args[4]).read_text()))
                return types.SimpleNamespace(returncode=process_code)
            if name in failing:
                return types.SimpleNamespace(returncode=1)
            text = "24\n55\n23\n50\n24\n51\n24\n52" if name == "indoor" else "20,2 °C\n56 %"
            if name in invalid:
                text = "20\n\n56"
            Path(args[4]).write_text(text)
            return types.SimpleNamespace(returncode=0)

        with patch.object(terrace.subprocess, "run", side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()) as output:
            code = terrace.run(CONFIG, collect_only=collect_only)
        return code, calls, inputs, output.getvalue()

    def test_eve_failure_keeps_homepod_and_processes_once(self):
        code, calls, inputs, _ = self.simulate(failing={"eve"})
        self.assertEqual(code, 0)
        self.assertEqual(calls, ["indoor", "homepod", "eve", "process"])
        readings = {s["id"]: s for s in inputs[0]["sensors"]}
        self.assertEqual(readings["eve-degree"]["failure"], "unavailable")
        self.assertIsNone(readings["eve-degree"]["measurement"])
        self.assertEqual(readings["homepod-terrasse"]["measurement"]["temperature"], 20.2)

    def test_timeout_does_not_cancel_next_read_or_invent_a_measurement(self):
        _, calls, inputs, _ = self.simulate(timeout={"homepod"})
        self.assertIn("eve", calls)
        readings = {s["id"]: s for s in inputs[0]["sensors"]}
        self.assertEqual(readings["homepod-terrasse"]["failure"], "timeout")
        self.assertIsNotNone(readings["eve-degree"]["measurement"])

    def test_both_failed_are_explicit_and_are_still_reported_to_cli(self):
        _, _, inputs, _ = self.simulate(failing={"eve", "homepod"})
        self.assertEqual(sum(s["measurement"] is None for s in inputs[0]["sensors"]), 2)

    def test_invalid_pair_does_not_shift_following_sensors(self):
        _, _, inputs, _ = self.simulate(invalid={"indoor", "eve"})
        self.assertEqual(sum(s["failure"] == "invalid" for s in inputs[0]["sensors"]), 5)

    def test_collect_only_never_processes_or_sends(self):
        _, calls, inputs, output = self.simulate(collect_only=True)
        self.assertNotIn("process", calls)
        self.assertEqual(inputs, [])
        self.assertEqual(len(json.loads(output)["sensors"]), 6)

    def test_processing_failure_is_not_retried(self):
        code, calls, _, _ = self.simulate(process_code=1)
        self.assertEqual(code, 1)
        self.assertEqual(calls.count("process"), 1)

    def test_parser_rejects_nonfinite_and_out_of_range(self):
        for text in ["nan\n50", "20\n101", "20\n", "20\n50\n30", "80\n50"]:
            with self.assertRaises(ValueError):
                terrace.parse_measurements(text, 1)

    @unittest.skipUnless((ROOT / ".build/debug/ClimateEngineCLI").is_file(), "Run swift build first")
    def test_collector_payload_is_accepted_by_real_cli_in_isolated_directory(self):
        actual_run = subprocess.run
        with tempfile.TemporaryDirectory(prefix="climateengine-terrace-integration-") as directory:
            def fake_homekit_real_cli(args, **kwargs):
                name = args[2]
                if name == "process":
                    environment = dict(os.environ, CLIMATEENGINE_DATA_DIRECTORY=directory)
                    result = actual_run(
                        [str(ROOT / ".build/debug/ClimateEngineCLI"), "sensor-readings"],
                        input=Path(args[4]).read_text(), text=True, capture_output=True,
                        env=environment, timeout=15,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    return result
                if name == "eve":
                    return types.SimpleNamespace(returncode=1)
                values = "24\n55\n23\n50\n24\n51\n24\n52" if name == "indoor" else "20\n55"
                Path(args[4]).write_text(values)
                return types.SimpleNamespace(returncode=0)

            with patch.object(terrace.subprocess, "run", side_effect=fake_homekit_real_cli):
                self.assertEqual(terrace.run(CONFIG), 0)
            snapshot = json.loads((Path(directory) / "current.json").read_text())
            self.assertEqual([s["id"] for s in snapshot["outdoorSensors"]], ["homepod-terrasse"])
            self.assertTrue(snapshot["acquisition"]["accepted"])
            history = list((Path(directory) / "history").glob("*.jsonl"))
            self.assertEqual(len(history), 1)
            self.assertEqual(len(history[0].read_text().splitlines()), 1)


if __name__ == "__main__":
    unittest.main()
