import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "trim-shortcuts-widget-renderer.sh"
RENDERER = "/System/Library/CoreServices/WidgetRenderer_Activities.app/Contents/MacOS/WidgetRenderer_Activities"


class WidgetRendererGuardTests(unittest.TestCase):
    def run_guard(self, rss_kb, threshold_kb="512000"):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "guard.log"
            environment = {
                **os.environ,
                "CLIMATEENGINE_WIDGET_RENDERER_THRESHOLD_KB": threshold_kb,
                "CLIMATEENGINE_WIDGET_RENDERER_LOG": str(log),
                "CLIMATEENGINE_WIDGET_RENDERER_SNAPSHOT": f"123 {rss_kb} {RENDERER}",
                "CLIMATEENGINE_WIDGET_RENDERER_DRY_RUN": "1",
                "CLIMATEENGINE_SHORTCUTS_ACTIVE": "0",
            }
            result = subprocess.run(
                [str(SCRIPT)], capture_output=True, text=True,
                env=environment, timeout=5, check=False,
            )
            return result, log.read_text() if log.exists() else ""

    def test_renderer_below_threshold_is_left_running(self):
        result, log = self.run_guard(511999)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(log, "")

    def test_renderer_above_threshold_would_restart(self):
        result, log = self.run_guard(512000)
        self.assertEqual(result.returncode, 0)
        self.assertIn("WOULD_RESTART pid=123 rss_kb=512000", log)

    def test_invalid_threshold_is_ignored_safely(self):
        result, log = self.run_guard(900000, threshold_kb="invalid")
        self.assertEqual(result.returncode, 0)
        self.assertIn("SKIP invalid threshold=invalid", log)


if __name__ == "__main__":
    unittest.main()
