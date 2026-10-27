local bindings, sent, timers, configured, submap = { [":SUPER + F"] = "original-fullscreen" }, {}, {}, nil, ""
local window = { class = "browser", tags = {}, mapped = true, workspace = { id = 1 }, focus_history_id = 0, address = "0x1" }
local windows = { window }
local focused
local options = "compose:caps,shift:both_capslock_cancel,ctrl:swap_lalt_lctl_lwin"
local settings = {}
local function dispatcher(kind)
  return function(value) return { kind = kind, value = value } end
end
local hl = {
  get_config = function() return options end,
  config = function(value) configured = value; options = value.input.kb_options end,
  unbind = function(key) bindings[submap .. ":" .. key] = nil end,
  define_submap = function(name, reset, callback)
    assert(reset == "reset", "Desktop layer must be one-shot")
    submap = name
    callback()
    submap = ""
  end,
  get_active_window = function() return window end,
  get_windows = function() return windows end,
  timer = function(callback) table.insert(timers, callback) end,
  dispatch = function(value)
    if value.kind == "focus" then focused = value.value.window
    elseif value.kind == "raise" then return
    else table.insert(sent, value) end
  end,
  dsp = {
    send_key_state = function(value) return value end,
    focus = dispatcher("focus"), submap = dispatcher("submap"),
    workspace = { toggle_special = dispatcher("scratchpad") },
    group = { toggle = dispatcher("group") },
    window = {
      alter_zorder = dispatcher("raise"), fullscreen = dispatcher("fullscreen"),
      float = dispatcher("float"), close = dispatcher("close"), pseudo = dispatcher("pseudo"),
      resize = dispatcher("resize"), swap = dispatcher("swap"),
    },
  },
}
local env = setmetatable({
  hl = hl,
  o = {
    bind = function(key, _, action) bindings[submap .. ":" .. key] = action end,
    cmd_present = function() return true end,
  },
  io = { open = function() return { close = function() end } end },
  dofile = function() return settings end,
}, { __index = _G })
local function load(value)
  settings = value or {}
  assert(loadfile("mac-command.lua", "t", env))()
end
local function run(key)
  sent = {}
  assert(type(bindings[":" .. key]) == "function", "Missing callback: " .. key)
  bindings[":" .. key]()
  while #timers > 0 do table.remove(timers, 1)() end
end
local function expect(index, mods, key, state)
  local event = sent[index]
  assert(event and event.mods == mods and event.key == key and event.state == state,
    "Unexpected translated key at event " .. index)
end
load()
assert(options == "compose:caps,shift:both_capslock_cancel,altwin:swap_lalt_lwin")
run("SUPER + LEFT")
expect(1, "", "Home", "down")
expect(2, "", "Home", "up")
run("SHIFT + SUPER + RIGHT")
expect(1, "SHIFT", "End", "down")
run("ALT + LEFT")
expect(1, "CTRL", "Left", "down")
run("SUPER + BACKSPACE")
assert(#sent == 4)
expect(1, "SHIFT", "Home", "down")
expect(2, "SHIFT", "Home", "up")
expect(3, "", "BackSpace", "down")
expect(4, "", "BackSpace", "up")
run("SUPER + T")
expect(1, "CTRL", "T", "down")
run("SUPER + SHIFT + T")
expect(1, "CTRL + SHIFT", "T", "down")
assert(bindings[":SUPER + F"] == "original-fullscreen", "Command+F must preserve fullscreen")
assert(bindings[":CTRL + F"] == nil, "Control+F must reach the app for Find")
run("SUPER + C")
expect(1, "CTRL", "C", "down")
window.tags = { "terminal*" }
run("SUPER + C")
expect(1, "CTRL + SHIFT", "C", "down")
run("SUPER + V")
expect(1, "CTRL + SHIFT", "V", "down")
run("SUPER + LEFT")
expect(1, "CTRL", "A", "down")
run("SUPER + BACKSPACE")
expect(1, "CTRL", "U", "down")
assert(#sent == 2)
for key in pairs(bindings) do
  assert(not key:match("^:CTRL ") and not key:match("^:SHIFT %+ CTRL "), "Physical Control must stay native: " .. key)
end
window.tags = {}
local second = { class = "editor", tags = {}, mapped = true, workspace = { id = 2 }, focus_history_id = 1, address = "0x2" }
local hidden = { class = "hidden", mapped = true, hidden = true, workspace = { id = 3 } }
local older = { class = "editor", mapped = true, workspace = { id = 2 }, focus_history_id = 9, address = "0x3" }
windows = { window, older, second, hidden }
run("SUPER + TAB")
assert(focused == second, "Switching must choose the most recent window of the next app")
window = second
run("SUPER + TAB")
assert(focused.class == "browser", "App cycling must wrap")
run("SUPER + SHIFT + TAB")
assert(focused.class == "browser", "Reverse cycling must wrap")
assert(bindings[":SUPER + SPACE"] == "omarchy-menu toggle")
assert(bindings[":SUPER + ALT + code:13"] == "omasnap")
assert(bindings[":SUPER + ESCAPE"].value == "mac-command-desktop")
assert(bindings["mac-command-desktop:F"].kind == "fullscreen")
assert(bindings["mac-command-desktop:LEFT"].value.direction == "l")
assert(bindings["mac-command-desktop:catchall"].value == "reset")
load({ keyboard = "apple", desktop_shortcuts = { ["SHIFT + F"] = "custom-file-manager" } })
assert(options == "compose:caps,shift:both_capslock_cancel", "Apple must retain native modifiers")
assert(bindings["mac-command-desktop:SHIFT + F"] == "custom-file-manager")
-- A disabled app chord must preserve the binding underneath it, including
-- physical-keycode zoom bindings. Group toggles must also preserve defaults.
bindings = { [":SUPER + T"] = "original-floating", [":SUPER + code:21"] = "original-resize" }
load({ keyboard = false, disabled_shortcuts = { "SUPER + T", "SUPER + equal" }, desktop_layer = false })
assert(bindings[":SUPER + T"] == "original-floating")
assert(bindings[":SUPER + code:21"] == "original-resize")
assert(not bindings[":SUPER + ESCAPE"])
bindings = {}
load({ applications = false, navigation = false, terminal_clipboard = false, app_switching = false, desktop = false, desktop_layer = false })
assert(next(bindings) == nil)
load({ enabled = false })
assert(next(bindings) == nil)
load()
local count = 0
for _ in pairs(bindings) do count = count + 1 end
load()
local again = 0
for _ in pairs(bindings) do again = again + 1 end
assert(again == count, "Reload must not multiply bindings")
assert(options == "compose:caps,shift:both_capslock_cancel,altwin:swap_lalt_lwin")
print("Runtime checks passed: app routing, native Control, navigation, clipboard, app cycling, desktop layer, profiles, settings, reload")
