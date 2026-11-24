import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("book_desktop", Path(__file__).resolve().parents[1] / "scripts/book-desktop.py")
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


class DesktopTests(unittest.TestCase):
    def test_legacy_selection_keeps_its_folder_until_picker_selects_another_book(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(desktop, "STATE", Path(directory)):
            root = Path(directory)
            config = {"root": directory, "books": [
                {"id": name, "source": str(root / (name + ".pdf"))} for name in ("first", "second")
            ]}
            (root / "active").write_text("second\n")
            self.assertEqual(desktop.selected_book(config)["folder"], root / "second")
            source = root / "another.epub"
            (root / "selected.json").write_text(json.dumps(str(source)))
            chosen = desktop.selected_book(config)
            self.assertEqual(chosen["source"], source)
            self.assertEqual(chosen["folder"], desktop.selected_book(config, source)["folder"])

    def test_failed_stop_can_retry_and_skips_reused_window_address(self):
        reader = {"address": "0x10", "pid": 1}
        chat = {"address": "0x20", "pid": 2}
        state = {"windows": [{"reader": reader}, {"codex": chat}]}
        clients = [reader, {**chat, "pid": 3}]
        def hypr(command, **kwargs):
            return {"activeworkspace": {"id": 1}, "clients": clients, "reload": ""}[command]
        with tempfile.TemporaryDirectory() as directory, patch.object(desktop, "STATE", Path(directory)), \
             patch.object(desktop, "hypr", side_effect=hypr), patch.object(desktop, "dispatch") as close:
            rules = Path(directory) / "enabled.lua"
            rules.touch()
            desktop.save_state(state)
            with patch.object(desktop.time, "monotonic", side_effect=[0, 9]), self.assertRaises(RuntimeError):
                desktop.down(state)
            close.assert_called_once_with('hl.dsp.window.close({ window = "address:0x10" })')
            self.assertTrue(rules.exists())
            self.assertEqual(json.loads((Path(directory) / "windows.json").read_text()), state)
            clients.remove(reader)
            desktop.down(state)
            self.assertEqual(close.call_count, 1)
            self.assertFalse(rules.exists())
            self.assertFalse((Path(directory) / "windows.json").exists())


if __name__ == "__main__":
    unittest.main()
