# Mac Command for Omarchy

Use one Command key for Mac-style application shortcuts and Omarchy desktop
shortcuts. Physical Control stays Ctrl, including Ctrl+C in terminals. Runs in
Hyprland's Lua configuration without a keyboard daemon or root access.

## Install

Requires Omarchy with Lua-based Hyprland configuration (`hl`, `o.bind`, and
`hl.define_submap`), Python 3, and `hyprctl`.

```sh
./omarchy-mac-command install
```

The default is a PC keyboard. **On Apple keyboards**, set `keyboard = "apple"`
in `~/.config/omarchy/mac-command.lua`, then reload:

```sh
hyprctl reload
hyprctl configerrors
```

Installation preserves existing settings, backs up affected files, adds a marked
loader to `~/.config/hypr/hyprland.lua`, and reloads and validates Hyprland.
Re-run the install command after pulling or editing source files.

```sh
omarchy-mac-command status
omarchy-mac-command uninstall
```

Uninstall removes the plugin while keeping later personal edits, settings, and
backups. It refuses to guess if its managed loader has been edited.
`--no-reload` edits files without contacting the desktop, for offline preparation
and isolated tests.

This is a Hyprland configuration module with its own user-level installer.
`omarchy plugin add` installs shell plugins and cannot install it.

## Keyboard placement

| Physical key | PC profile | Apple profile |
|---|---|---|
| Key beside Space | Left Alt → Super (Command) | Command → Super (unchanged) |
| Left Control | Ctrl (unchanged) | Ctrl (unchanged) |
| Option-position key | Left Windows → Alt | Option → Alt (unchanged) |

Right-side modifiers stay unchanged. Existing Compose and Caps Lock options are
preserved; the previous plugin's left-side Ctrl/Alt/Super swaps are removed.
Profiles apply session-wide. Mixed keyboards need per-device settings; use
`keyboard = false` to manage modifiers yourself.

**Upgrade note:** earlier versions made Command send Ctrl and Control send Super.
This version uses Super for Command and leaves Control native. Update any
`disabled_shortcuts` entries from `CTRL` to `SUPER` when they refer to Command.
The installer preserves your existing settings rather than rewriting them.

## Command shortcuts

Command means the physical Command-position key, which sends Super. The plugin
explicitly translates the following app shortcuts into Linux Ctrl shortcuts;
menus inside applications will still show Ctrl.

| Shortcut | Behavior |
|---|---|
| Command+C / X / V | Copy / cut / paste |
| Command+B / D / E / I / U | App Ctrl equivalent: bold / bookmark / search / italic / underline where supported |
| Command+A / G / K | Select all / find next / app Ctrl+K |
| Command+F / Control+F | Omarchy fullscreen / native app Find |
| Command+L / N / O / P | Address bar / new / open / print |
| Command+Q / R / S / T / W | App Ctrl+Q / reload / save / new tab / close tab or document |
| Command+Z / Shift+Z | Undo / redo where supported |
| Command+Shift+F / G / N / P / S / T / W | App Ctrl+Shift equivalent, including reopen tab |
| Command+Shift+C / V | App Ctrl+Shift equivalent; terminal copy / paste |
| Command+comma | App Ctrl+comma, commonly preferences |
| Command+minus / equal / Shift+equal / 0 | App zoom out / in / in / reset |
| Command+Left / Right | Start / end of line |
| Command+Up / Down | Start / end of document |
| Option+Left / Right | Previous / next word |
| Shift with the navigation shortcuts | Extend selection |
| Command+Backspace | Delete to start of line |
| Option+Backspace / Delete | Delete previous / next word |
| Command+Tab / Shift+Tab | Next / previous running app |
| Command+Space | Omarchy menu |
| Command+Option+4 | Omasnap if available, otherwise Omarchy screenshot |

Applications retain their own interpretation of the translated Ctrl shortcuts.
For example, Ctrl+Q is an application request, not a forced window close.
Unknown Command chords retain the underlying Super behavior; this is an explicit
shortcut list, not a catch-all translation. Command+1–9 keeps Omarchy workspace
switching rather than browser tab selection. Command+Return still opens a
terminal. Command+period retains your underlying binding, such as dictation.

In Omarchy-tagged terminals, Command+C/V sends Ctrl+Shift+C/V. Command+Left/Right
uses Ctrl+A/E, Command+Backspace uses Ctrl+U, Option+Backspace uses Ctrl+W, and
Option+Delete uses Alt+D. Physical Control is not translated by this plugin:
Ctrl+C interrupts, Ctrl+D sends EOF, and Ctrl+Z suspends, subject to the app's own
behavior and any independent desktop bindings. Embedded editor terminals are not
detected separately. Terminal selection uses Shift+Home/End; shell editing modes
and TUIs can differ.

App switching groups normal windows by app ID across workspaces, cycles
alphabetically, and focuses each app's most recently used window. Hidden and
special-workspace windows are skipped. There is no visual switcher or MRU app
ordering.

## Desktop layer and conflicts

Mac app shortcuts take priority over conflicting Super shortcuts. For example,
Command+T opens a tab instead of toggling floating, and Command+arrows navigate
text instead of focusing windows. Command+F keeps Omarchy fullscreen; use
Control+F for Find.
Physical-keycode resize bindings on Command+minus/equal are replaced for zoom.

Press **Command+Escape, release both keys, then press**:

| Key in desktop layer | Action |
|---|---|
| F / T / W | Fullscreen / toggle floating / close whole window |
| S / L | Scratchpad / toggle workspace layout |
| G / P / O | Toggle grouping / pseudo window / pop window out |
| Arrow / Shift+arrow | Focus adjacent window / swap window |
| Tab / Shift+Tab | Next / previous workspace |
| minus / equal | Resize width by −100 / +100 |
| Backspace | Toggle transparency |
| comma | Dismiss notification |
| K | Show keybindings |
| Escape | System menu |
| Any other key | Cancel the layer (key is consumed) |

The layer exits after one action. Its prefix replaces Command+Escape's former
system-menu action; the system menu is available with Escape inside the layer.
The built-in layer contains window-management and desktop utility actions.
App launchers belong in `desktop_shortcuts`, so the plugin does not recreate
Omarchy app bindings you have disabled or replace your preferred launch commands.
Existing configured shortcuts, such as Flea below, continue to work.

**Upgrade note:** automatic layer launchers for file manager, editor, Signal,
calendar, Photos, Maps, and Omawrite have been removed. Add the launchers you want
to `desktop_shortcuts`; these are explicit choices independent of Omarchy's
preinstalled-app preference.

## Customize

Edit `~/.config/omarchy/mac-command.lua`, then run `hyprctl reload` and
`hyprctl configerrors`. Defaults are in [settings.lua](settings.lua).

```lua
return {
  keyboard = "apple",          -- "pc", "apple", or false
  applications = true,
  navigation = true,
  terminal_clipboard = true,
  app_switching = true,
  desktop = true,
  desktop_layer = true,
  desktop_prefix = "SUPER + ESCAPE",
  launcher = "omarchy-menu toggle",
  desktop_shortcuts = {
    ["SHIFT + F"] = { launch = "flea --gui" },
    ["SHIFT + N"] = { omarchy = "editor" },
  },
  disabled_shortcuts = {
    -- "SUPER + K",          -- Preserve the underlying desktop shortcut
  },
  terminal_classes = {},       -- Extra terminal app IDs
}
```

Set `enabled = false` to disable the module on reload. Set a group to false to
keep its underlying bindings. Individual disabled shortcuts use the exact strings
from [mac-command.lua](mac-command.lua). Disabled shortcuts preserve the binding
underneath; they do not create another mapping. Desktop-layer keys are matched
without the prefix, e.g. `"F"` disables the layer's fullscreen action.
Global shortcuts can overlap shortcuts in apps such as Figma; this module does
not distinguish browser tabs or URLs. Disable a translation when needed.

Source lives in this repository. Installation copies runtime files into
`${XDG_DATA_HOME:-~/.local/share}/omarchy-mac-command/`; source edits take effect
after running `./omarchy-mac-command install`. It does not edit packaged Omarchy
files. Settings, backups, and installation state stay outside the repository.
Both XDG configuration and data directories are supported.

## Screensaver fullscreen inheritance

If dismissing the screensaver makes the app underneath fullscreen, this is a
[known Omarchy focus-inheritance issue](https://github.com/omacom/omarchy/issues/13157).
A personal override in `~/.config/hypr/looknfeel.lua` prevents the transfer:

```lua
hl.config({ misc = { on_focus_under_fullscreen = 2 } })
```

Reload and validate with `hyprctl reload` and `hyprctl configerrors`. Switching
focus to another tiled window then exits fullscreen instead of passing fullscreen
to that window. This is an optional desktop setting; the plugin does not change it.

## Verify

```sh
python3 -m unittest discover -s tests -v
lua tests/runtime.lua
luac -p mac-command.lua
```

Installer tests use disposable homes. Runtime checks cover app translation,
native Control, navigation, clipboard, app switching, desktop-layer registration,
profiles, settings, alias replacement, and repeated loading. The registration
mock retains duplicate bindings so reload and override checks can detect them.
With the module installed:

```sh
python3 tests/live_text.py
```

The live check needs GTK 4 and Python GObject bindings. It opens a disposable GTK
text window and runs the installed callbacks against real text movement,
selection, and deletion. It does not simulate physical keyboard hardware.
Verify key placement and app-specific behavior in your own apps.
