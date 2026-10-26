#!/usr/bin/env python3
"""Verify physical Ctrl+V's callback reaches a disposable terminal as byte 0x16.

No clipboard contents are read or changed. The callback is invoked through Lua;
this check does not simulate a physical keyboard.
"""
import json
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import termios
import time
import tty

TITLE = "Mac Command Ctrl+V verification"


def receiver(path):
    saved = termios.tcgetattr(sys.stdin.fileno())
    try:
        tty.setraw(sys.stdin.fileno())
        path.with_suffix(".ready").touch()
        if not select.select([sys.stdin], [], [], 8)[0]:
            raise TimeoutError("No key reached the terminal")
        import os
        path.write_text(json.dumps(list(os.read(sys.stdin.fileno(), 64))))
    finally:
        termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, saved)


def check(command_image=False):
    if command_image:
        formats = subprocess.run(["wl-paste", "--list-types"], check=True,
                                 capture_output=True, text=True, timeout=2).stdout
        assert any(mime.startswith("image/") for mime in formats.splitlines()), "Copy an image first"
    shortcut = "CTRL + V" if command_image else "SUPER + V"
    with tempfile.TemporaryDirectory(prefix="mac-command-terminal-") as directory:
        result = Path(directory) / "result.json"
        process = subprocess.Popen(["foot", "--app-id=foot", "--title=" + TITLE,
                                    sys.executable, str(Path(__file__).resolve()),
                                    "--receiver", str(result)],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 6
            while not result.with_suffix(".ready").exists():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Test terminal did not start")
                time.sleep(0.05)
            code = '''local active = hl.get_active_window()
assert(active and active.title == "Mac Command Ctrl+V verification", "Test terminal lost focus")
local tagged = false
for _, tag in ipairs(active.tags or {}) do if tag:gsub("%*$", "") == "terminal" then tagged = true end end
assert(tagged, "Test terminal must have Omarchy's terminal tag")
local actions = {}
local env = setmetatable({
  o = { bind = function(key, _, action) actions[key] = action end, cmd_present = o.cmd_present, shell_quote = o.shell_quote },
  hl = setmetatable({ config = function() end, unbind = function() end }, { __index = hl }),
}, { __index = _G })
local data = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
assert(loadfile(data .. "/omarchy-mac-command/mac-command.lua", "t", env))()
assert(actions[SHORTCUT], "Missing paste shortcut")()'''.replace("SHORTCUT", json.dumps(shortcut))
            response = subprocess.run(["hyprctl", "eval", code], check=True,
                                      capture_output=True, text=True, timeout=5)
            assert "error" not in response.stdout.lower(), response.stdout
            process.wait(timeout=10)
            actual = json.loads(result.read_text())
            assert actual == [0x16], f"Expected Ctrl+V (22), received bytes {actual}"
            label = "Command+V with an image" if command_image else "Physical Ctrl+V"
            print(f"Live terminal check passed: {label} delivered byte 0x16 to foot")
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=3)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--receiver":
        receiver(Path(sys.argv[2]))
    else:
        check(command_image="--command-image" in sys.argv)
