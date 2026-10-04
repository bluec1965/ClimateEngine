import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("menubar_guard",
    Path(__file__).parents[2] / "Scripts/guard-menubar-memory.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class MenuBarGuardTests(unittest.TestCase):
    def test_units_and_top_change_markers(self):
        self.assertEqual(guard.memory_bytes("52G"), 52 * 1024 ** 3)
        self.assertEqual(guard.memory_bytes("23M+"), 23 * 1024 ** 2)
        self.assertEqual(guard.memory_bytes("0B"), 0)
        self.assertEqual(guard.memory_bytes("1.5G-"), int(1.5 * 1024 ** 3))

    def test_uses_compressed_inclusive_footprint(self):
        self.assertEqual(guard.read_footprint("PID MEM CMPRS\n649 52G 52G\n", 649),
                         (52 * 1024 ** 3, 52 * 1024 ** 3))
        with self.assertRaises(ValueError):
            guard.read_footprint("649 invalid 0B", 649)
        with self.assertRaises(ValueError):
            guard.read_footprint("650 52G 52G", 649)

    def test_threshold_and_restart_cooldown(self):
        self.assertFalse(guard.restart_needed(guard.THRESHOLD - 1, 1000, 0))
        self.assertTrue(guard.restart_needed(guard.THRESHOLD, 1000, 0))
        self.assertFalse(guard.restart_needed(52 * 1024 ** 3, 1000, 900))
