# Mac Command for Omarchy

Use the key beside Space as Command for application shortcuts, with Mac-style
text navigation, terminal clipboard shortcuts, app switching, and a launcher.
Runs entirely in Hyprland's Lua configuration. No keyboard daemon, root access,
background process, or extra runtime dependency.

## Install

Requires Omarchy with Lua-based Hyprland configuration (`hl` and `o.bind`),
Python 3, and `hyprctl`. Older `.conf`-based Omarchy releases are unsupported.

```sh
./omarchy-mac-command install
```

Re-run that command after pulling changes. Installation preserves your settings,
backs up affected files, adds a marked loader to `~/.config/hypr/hyprland.lua`,
and reloads and validates Hyprland. The installed command is available as:

```sh
omarchy-mac-command status
omarchy-mac-command uninstall
```

Uninstall restores the previous mappings while keeping later personal edits,
settings, and backups. If the managed loader was edited, it refuses to guess
what to remove. `--no-reload` edits files without contacting the desktop; use it
only when preparing an offline installation or running isolated tests.

This is a **Hyprland configuration plugin**, installed with the command above.
Omarchy's `omarchy plugin add` currently installs Quickshell UI/service plugins
and deliberately does not execute installation hooks. It cannot install keyboard
configuration modules, so this package uses its own user-level installer.

## Keyboard placement

On a standard PC laptop keyboard, the default `keyboard = "pc"` profile is:

| Physical key | Sends | Purpose |
|---|---|---|
| Left Alt, beside Space | Ctrl | Command for app shortcuts |
| Far-left Ctrl | Super | Omarchy desktop shortcuts |
| Left Windows-logo key | Alt | Option |

Right-side modifiers stay unchanged. Existing Compose and Caps Lock options are
preserved; conflicting left-side Ctrl/Alt/Super swaps are replaced. The installer
also migrates the exact standalone remap and two aliases from the initial trial
into this package, restoring them on uninstall.

For an Apple keyboard, set `keyboard = "apple"`: left Command sends Ctrl and
left Control sends Super, with Option unchanged. These profiles apply to all
keyboards in the session; mixed PC and Apple keyboards need per-device settings.
Set `keyboard = false` to keep your own modifier configuration.

## Shortcuts

“Command” below means the key beside Space, which sends Ctrl. “Option” means
Alt. The names in application menus will still show Ctrl.

| Shortcut | Behavior |
|---|---|
| Command+C / X / V | Copy / cut / paste; terminal copy/paste adapted below |
| Command+Z / Shift+Z | Native application undo / redo, where supported |
| Command+A / F / S | Native select all / find / save |
| Command+T / Shift+T / W | Native browser new tab / reopen tab / close tab |
| Command+L / R | Native browser address bar / reload |
| Command+plus / minus / 0 | Native browser zoom in / out / reset |
| Command+Left / Right | Start / end of line |
| Command+Up / Down | Start / end of document |
| Option+Left / Right | Previous / next word |
| Shift with the navigation shortcuts above | Extend selection |
| Command+Backspace | Delete from cursor to start of line |
| Option+Backspace / Delete | Delete previous / next word |
| Command+Tab / Shift+Tab | Next / previous running app |
| Command+Space | Launcher (default: Omarchy menu) |
| Command+Option+4 | Omasnap, if installed; otherwise Omarchy screenshot |

Native shortcuts in the first seven rows retain each application's behavior;
this plugin does not force applications to support commands they lack.

In terminals tagged by Omarchy, Command+C/V sends Ctrl+Shift+C/V. The physical
far-left Ctrl+C sends an interrupt again (overriding Omarchy's universal copy for
that chord). Command+Left/Right uses Ctrl+A/E and Command+Backspace uses Ctrl+U,
which suit typical shell prompts. Option+Backspace sends Ctrl+W and Option+Delete
sends Alt+D. Shell editing modes, TUIs, and terminal selection differ; selection
uses Shift+Home/End and terminal-specific behavior still applies. Embedded
terminals inside editors are not detected separately from their parent app.

App switching groups normal windows by application ID across workspaces and
cycles alphabetically, focusing the most recently used window of each app. It
skips hidden and special-workspace windows. This first version has no visual
switcher, MRU app ordering, or macOS-style application grouping beyond app IDs.
Command+Tab takes over native Ctrl+Tab; browsers generally also offer Ctrl+PageUp
and Ctrl+PageDown for tab switching.

Original Super shortcuts remain available. These new shortcuts are global, so
an app such as Figma may lose an overlapping Ctrl or Alt shortcut. Disable an
individual mapping or its group when that happens. This plugin does not inspect
browser URLs or distinguish Figma from other tabs.

## Customize and iterate

Edit `~/.config/omarchy/mac-command.lua`, then run `hyprctl reload` and
`hyprctl configerrors`. Defaults are in [settings.lua](settings.lua).

```lua
return {
  keyboard = "pc",              -- "pc", "apple", or false
  navigation = true,
  terminal_clipboard = true,
  app_switching = true,
  desktop = true,
  launcher = "omarchy-menu toggle",
  disabled_shortcuts = {
    -- "CTRL + TAB",             -- Keep native browser Ctrl+Tab
    -- "SHIFT + CTRL + LEFT",    -- Keep an app's own selection shortcut
  },
  terminal_classes = {},         -- Extra terminal app IDs
}
```

Set `enabled = false` to disable the whole plugin on the next reload. Disabling
returns to the configuration underneath the plugin; uninstall restores the
pre-install experimental mappings as well. The installed module loads last and
explicitly replaces its listed shortcuts. Use the exact strings from
[mac-command.lua](mac-command.lua) for `disabled_shortcuts`.

Source lives in this Git repo. Install copies runtime files into
`${XDG_DATA_HOME:-~/.local/share}/omarchy-mac-command/`, so source edits take effect
after re-running `./omarchy-mac-command install`. It does not write to packaged
Omarchy files. Backups and installation state stay in that data directory and
are never committed. Both XDG configuration and data directories are supported.

## Verify

```sh
python3 -m unittest discover -s tests -v
XDG_CONFIG_HOME="$(mktemp -d)" lua tests/runtime.lua
luac -p mac-command.lua
```

Installer tests use disposable home directories. Lua tests cover emitted key
sequences, terminal handling, app cycling, and repeat loading. With the plugin
installed in an active session, this opens a temporary GTK text window and
executes the installed translation callbacks against it:

```sh
python3 tests/live_text.py
```

The live check needs GTK 4 and Python GObject bindings. It verifies real text
movement, selection, and deletion through Hyprland's synthetic key dispatches;
it does not simulate physical keyboard hardware. Verify physical key placement
and app-specific behavior by using the shortcuts in your own apps.

Implementation follows the installed Omarchy clipboard module's split key-down
and key-up dispatches, and Hyprland's [Lua dispatch API](https://wiki.hypr.land/configuring/core/dispatchers/).
