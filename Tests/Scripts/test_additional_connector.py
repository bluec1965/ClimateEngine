import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("additional", ROOT / "Scripts/run-additional-connector.py")
additional = importlib.util.module_from_spec(spec)
spec.loader.exec_module(additional)
CONFIG = {"version": 1, "shortcuts": {sensor: sensor for sensor in additional.IDS}}


class AdditionalConnectorTests(unittest.TestCase):
    def simulate(self, failed=(), timeouts=(), collect_only=False, process_code=0):
        calls, payloads = [], []
        def fake_run(args, **kwargs):
            calls.append(args)
            if args[1] == "additional-readings":
                payloads.append(json.loads(kwargs["input"]))
                return types.SimpleNamespace(returncode=process_code)
            sensor = args[2]
            if sensor in timeouts: raise subprocess.TimeoutExpired(args, 25)
            if sensor in failed: return types.SimpleNamespace(returncode=1)
            Path(args[4]).write_text("24 °C\n55 %")
            return types.SimpleNamespace(returncode=0)
        with patch.object(additional.subprocess, "run", side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()) as output:
            code = additional.run(CONFIG, cli="test-cli", collect_only=collect_only)
        return code, calls, payloads, output.getvalue()

    def test_failed_bedroom_does_not_abort_other_seven(self):
        code, calls, payloads, _ = self.simulate(failed={"homepod-schlafzimmer"})
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 9)
        sensors = payloads[0]["sensors"]
        self.assertEqual(sum(s["measurement"] is not None for s in sensors), 7)
        self.assertEqual(sensors[2]["failure"], "unavailable")
        self.assertEqual(sensors[-1]["id"], "dachzimmer-sensor")

    def test_timeout_continues_without_copying_values(self):
        _, _, payloads, _ = self.simulate(timeouts={"homepod-kueche"})
        self.assertIsNone(payloads[0]["sensors"][0]["measurement"])
        self.assertEqual(payloads[0]["sensors"][0]["failure"], "timeout")
        self.assertEqual(sum(s["measurement"] is not None for s in payloads[0]["sensors"]), 7)

    def test_collect_only_does_not_call_cli(self):
        _, calls, payloads, output = self.simulate(collect_only=True)
        self.assertEqual(len(calls), 8)
        self.assertEqual(payloads, [])
        self.assertEqual(len(json.loads(output)["sensors"]), 8)

    def test_processing_never_retried(self):
        code, calls, _, _ = self.simulate(process_code=1)
        self.assertEqual(code, 1)
        self.assertEqual(sum(c[1] == "additional-readings" for c in calls), 1)

    def test_overall_budget_marks_remaining_results_as_failed(self):
        with patch.object(additional.time, "monotonic", side_effect=[0] + [151] * 8), patch.object(additional.subprocess, "run") as run, contextlib.redirect_stdout(io.StringIO()) as output:
            additional.run(CONFIG, collect_only=True)
        run.assert_not_called()
        self.assertTrue(all(s["failure"] == "timeout" for s in json.loads(output.getvalue())["sensors"]))

    def test_configuration_requires_distinct_helpers_for_all_ids(self):
        with self.assertRaises(ValueError):
            additional.run({"version": 1, "shortcuts": {s: "same" for s in additional.IDS}})


if __name__ == "__main__": unittest.main()
