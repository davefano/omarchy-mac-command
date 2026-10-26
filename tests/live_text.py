#!/usr/bin/env python3
"""Exercise the installed Lua callbacks against a disposable GTK text window."""
import json
import subprocess
import sys
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk


def hypr(*args):
    return subprocess.run(["hyprctl", *args], check=True, capture_output=True, text=True, timeout=5).stdout


bindings = json.loads(hypr("binds", "-j"))

def action(key, mods):
    candidates = [b for b in bindings if b["key"].upper() == key and b["modmask"] == mods
                  and b["description"].startswith("Mac Command:")]
    assert len(candidates) == 1, (key, mods, candidates)
    shortcut = {(4, "LEFT"): "CTRL + LEFT", (4, "RIGHT"): "CTRL + RIGHT",
                (5, "LEFT"): "SHIFT + CTRL + LEFT", (8, "LEFT"): "ALT + LEFT",
                (4, "BACKSPACE"): "CTRL + BACKSPACE"}[(mods, key)]
    # Capture the installed module's callbacks without registering bindings or
    # changing configuration. Execute its real dispatches against this window.
    code = r'''local active = hl.get_active_window()
assert(active and active.class == "local.maccommand.probe", "Test window lost focus")
local actions = {}
local env = setmetatable({
  o = { bind = function(key, _, action) actions[key] = action end, cmd_present = o.cmd_present },
  hl = setmetatable({ config = function() end, unbind = function() end }, { __index = hl }),
}, { __index = _G })
local data = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
assert(loadfile(data .. "/omarchy-mac-command/mac-command.lua", "t", env))()
actions[SHORTCUT]()'''.replace("SHORTCUT", json.dumps(shortcut))
    result = hypr("eval", code)
    assert "error" not in result.lower(), result


class Probe(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="local.maccommand.probe")
        self.connect("activate", self.activate)
        self.failure = None
        self.index = 0

    def activate(self, app):
        self.window = Gtk.ApplicationWindow(application=app, title="Mac Command verification")
        self.window.set_default_size(500, 150)
        self.view = Gtk.TextView()
        self.window.set_child(self.view)
        self.buffer = self.view.get_buffer()
        self.window.present()
        self.view.grab_focus()
        GLib.timeout_add(600, self.next_case)

    def next_case(self):
        self.cases = [
            ("LEFT", 4, 0, 0, "alpha beta gamma"),
            ("RIGHT", 4, 16, 16, "alpha beta gamma"),
            ("LEFT", 5, 0, 10, "alpha beta gamma"),
            ("LEFT", 8, 6, 6, "alpha beta gamma"),
            ("BACKSPACE", 4, 0, 0, " gamma"),
        ]
        if self.index == len(self.cases):
            print("Live GTK checks passed: line start/end, selection, word navigation, delete to line start")
            self.quit()
            return False
        self.buffer.set_text("alpha beta gamma")
        self.buffer.place_cursor(self.buffer.get_iter_at_offset(10))
        try:
            key, mods, *_ = self.cases[self.index]
            action(key, mods)
            GLib.timeout_add(180, self.check_case)
        except Exception as error:
            self.failure = error
            self.quit()
        return False

    def check_case(self):
        try:
            key, mods, start, end, text = self.cases[self.index]
            actual = self.buffer.get_text(self.buffer.get_start_iter(), self.buffer.get_end_iter(), True)
            selection = self.buffer.get_selection_bounds()
            if selection:
                bounds = tuple(i.get_offset() for i in selection)
            else:
                cursor = self.buffer.get_iter_at_mark(self.buffer.get_insert()).get_offset()
                bounds = (cursor, cursor)
            assert actual == text and bounds == (start, end), (key, mods, actual, bounds)
            self.index += 1
            GLib.idle_add(self.next_case)
        except Exception as error:
            self.failure = error
            self.quit()
        return False


app = Probe()
app.run([sys.argv[0]])
if app.failure:
    raise app.failure
