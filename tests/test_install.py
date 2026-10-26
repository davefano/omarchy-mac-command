import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("installer", str(ROOT / "omarchy-mac-command"))
spec = importlib.util.spec_from_loader(loader.name, loader)
installer = importlib.util.module_from_spec(spec)
loader.exec_module(installer)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / "config"),
                        XDG_DATA_HOME=str(self.home / "data"))
        self.config = self.home / "config/hypr"
        self.config.mkdir(parents=True)
        (self.config / "hyprland.lua").write_text('require("default.hypr.omarchy")\n')
        (self.config / "input.lua").write_text('hl.config({input={kb_options="compose:caps,ctrl:swap_lalt_lctl_lwin"}})\n')
        (self.config / "bindings.lua").write_text('-- personal bindings\n' + installer.ALIASES)

    def tearDown(self):
        self.temp.cleanup()

    def call(self, action, success=True):
        result = subprocess.run([str(ROOT / "omarchy-mac-command"), action, "--no-reload"],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        return result.stdout

    def test_install_repeat_and_uninstall_preserve_personal_changes(self):
        self.call("install")
        main = self.config / "hyprland.lua"
        installed = main.read_text()
        self.assertEqual(installed.count(installer.BEGIN), 1)
        self.assertNotIn(installer.ALIASES, (self.config / "bindings.lua").read_text())
        self.assertNotIn("ctrl:swap_lalt_lctl_lwin", (self.config / "input.lua").read_text())
        settings = self.home / "config/omarchy/mac-command.lua"
        settings.write_text("return {navigation=false}\n")
        self.call("install")
        self.assertEqual(main.read_text(), installed)
        self.assertEqual(settings.read_text(), "return {navigation=false}\n")
        main.write_text(main.read_text() + "-- later personal change\n")
        bindings = self.config / "bindings.lua"
        bindings.write_text(bindings.read_text() + "-- another personal change\n")
        self.call("uninstall")
        self.assertNotIn(installer.BEGIN, main.read_text())
        self.assertIn("later personal change", main.read_text())
        self.assertIn("another personal change", bindings.read_text())
        self.assertIn(installer.ALIASES, bindings.read_text())
        self.assertIn("ctrl:swap_lalt_lctl_lwin", (self.config / "input.lua").read_text())
        self.call("uninstall")
        self.call("install")
        self.assertIn("Installed", self.call("status"))

    def test_refuse_edited_loader_without_touching_other_files(self):
        self.call("install")
        main = self.config / "hyprland.lua"
        main.write_text(main.read_text().replace("dofile(data", "print(data"))
        input_before = (self.config / "input.lua").read_text()
        self.call("uninstall", success=False)
        self.assertEqual(input_before, (self.config / "input.lua").read_text())

    def test_refuse_unrelated_launcher(self):
        launcher = self.home / ".local/bin/omarchy-mac-command"
        launcher.parent.mkdir(parents=True)
        launcher.write_text("unrelated")
        self.call("install", success=False)
        self.assertEqual(launcher.read_text(), "unrelated")
        self.assertFalse((self.home / "data/omarchy-mac-command/install-state.json").exists())
        self.assertNotIn(installer.BEGIN, (self.config / "hyprland.lua").read_text())

    def test_failed_reload_restores_previous_mappings(self):
        fakebin = self.home / "fakebin"
        fakebin.mkdir()
        fake = fakebin / "hyprctl"
        fake.write_text("#!/bin/sh\nif [ \"$1\" = configerrors ]; then exit 0; fi\n"
                        "if [ ! -f \"$HOME/failed-once\" ]; then touch \"$HOME/failed-once\"; exit 1; fi\n")
        fake.chmod(0o755)
        env = dict(self.env, PATH=str(fakebin) + os.pathsep + os.environ["PATH"])
        result = subprocess.run([str(ROOT / "omarchy-mac-command"), "install"],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(installer.BEGIN, (self.config / "hyprland.lua").read_text())
        self.assertIn(installer.ALIASES, (self.config / "bindings.lua").read_text())
        self.assertIn("ctrl:swap_lalt_lctl_lwin", (self.config / "input.lua").read_text())

    def test_clean_install_without_experiment(self):
        (self.config / "input.lua").unlink()
        (self.config / "bindings.lua").write_text("-- untouched\n")
        self.call("install")
        self.call("uninstall")
        self.assertEqual((self.config / "bindings.lua").read_text(), "-- untouched\n")


if __name__ == "__main__":
    unittest.main()
