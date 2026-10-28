local bindings, sent, timers, configured, submap = {
  { scope = "", keys = "SUPER + F", action = "original-fullscreen" },
  { scope = "", keys = "CTRL + F", action = "native-find" },
  { scope = "", keys = "SUPER + code:20", action = "resize-left" },
  { scope = "", keys = "SUPER + code:21", action = "resize-right" },
  { scope = "", keys = "SHIFT + SUPER + code:21", action = "resize-up" },
}, {}, {}, nil, ""
local function chord(keys)
  local parts = {}
  for part in keys:gmatch("[^+]+") do
    table.insert(parts, part:match("^%s*(.-)%s*$"):upper())
  end
  local key = table.remove(parts)
  table.sort(parts)
  return table.concat(parts, "+") .. ":" .. key
end
local function binding(id)
  local scope, keys = id:match("^(.-):(.*)$")
  local action
  for _, record in ipairs(bindings) do
    if record.scope == scope and chord(record.keys) == chord(keys) then
      assert(action == nil, "Duplicate registration: " .. id)
      action = record.action
    end
  end
  return action
end
local function assert_unique()
  for _, record in ipairs(bindings) do binding(record.scope .. ":" .. record.keys) end
end
local window = { class = "browser", tags = {}, mapped = true, workspace = { id = 1 }, focus_history_id = 0, address = "0x1" }
local windows = { window }
local focused
local launched
local options = "compose:caps,shift:both_capslock_cancel,ctrl:swap_lalt_lctl_lwin"
local settings = {}
local function dispatcher(kind)
  return function(value) return { kind = kind, value = value } end
end
local hl = {
  exec_cmd = function(command) launched = command end,
  get_config = function() return options end,
  config = function(value) configured = value; options = value.input.kb_options end,
  unbind = function(key)
    for i = #bindings, 1, -1 do
      if bindings[i].scope == submap and chord(bindings[i].keys) == chord(key) then
        table.remove(bindings, i)
      end
    end
  end,
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
    bind = function(key, _, action)
      table.insert(bindings, { scope = submap, keys = key, action = action })
    end,
    cmd_present = function() return true end,
    shell_quote = function(value) return "'" .. value .. "'" end,
  },
  io = { open = function() return { close = function() end } end },
  dofile = function() return settings end,
}, { __index = _G })
local function load(value)
  settings = value or {}
  assert(loadfile("mac-command.lua", "t", env))()
  assert_unique()
end
local function run(key)
  sent = {}
  launched = nil
  assert(type(binding(":" .. key)) == "function", "Missing callback: " .. key)
  binding(":" .. key)()
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
assert(binding(":SUPER + F") == "original-fullscreen", "Command+F must preserve fullscreen")
assert(binding(":CTRL + F") == "native-find", "Control+F must retain its original behavior")
assert(not binding(":SUPER + code:20") and not binding(":SUPER + code:21"))
assert(not binding(":SUPER + SHIFT + code:21"), "Shifted zoom must remove its physical alias")
run("SUPER + equal")
expect(1, "CTRL", "equal", "down")
run("SUPER + SHIFT + equal")
expect(1, "CTRL + SHIFT", "equal", "down")
run("SUPER + C")
expect(1, "CTRL", "C", "down")
run("SUPER + V")
expect(1, "CTRL", "V", "down")
assert(not launched, "GUI paste must not inspect the clipboard")
window.tags = { "terminal*" }
run("SUPER + C")
expect(1, "CTRL + SHIFT", "C", "down")
run("SUPER + V")
assert(#sent == 0, "Terminal paste must query Wayland outside the compositor")
assert(launched:find(" paste --window '0x1'", 1, true), "Terminal paste must launch the focus-scoped helper")
run("SUPER + SHIFT + V")
expect(1, "CTRL + SHIFT", "V", "down")
expect(2, "CTRL + SHIFT", "V", "up")
run("SUPER + LEFT")
expect(1, "CTRL", "A", "down")
run("SUPER + BACKSPACE")
expect(1, "CTRL", "U", "down")
assert(#sent == 2)
assert(binding(":CTRL + F") == "native-find")
for _, record in ipairs(bindings) do
  if record.scope == "" and record.action ~= "native-find" then
    assert(not record.keys:match("^CTRL ") and not record.keys:match("^SHIFT %+ CTRL "),
      "Physical Control must stay native: " .. record.keys)
  end
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
assert(binding(":SUPER + SPACE") == "omarchy-menu toggle")
assert(binding(":SUPER + ALT + code:13") == "omasnap")
assert(binding(":SUPER + ESCAPE").value == "mac-command-desktop")
assert(binding("mac-command-desktop:F").kind == "fullscreen")
assert(binding("mac-command-desktop:LEFT").value.direction == "l")
assert(binding("mac-command-desktop:catchall").value == "reset")
for _, key in ipairs({ "F", "G", "N", "P", "S", "W", "C" }) do
  assert(not binding("mac-command-desktop:SHIFT + " .. key), "App launchers must be explicit settings")
end
load({ keyboard = "apple", desktop_shortcuts = { ["F"] = "custom-fullscreen", ["SHIFT + F"] = "custom-file-manager" } })
assert(binding("mac-command-desktop:F") == "custom-fullscreen", "Custom action must replace the built-in")
assert(options == "compose:caps,shift:both_capslock_cancel", "Apple must retain native modifiers")
assert(binding("mac-command-desktop:SHIFT + F") == "custom-file-manager")
-- A disabled app chord must preserve the binding underneath it, including
-- physical-keycode zoom bindings. Group toggles must also preserve defaults.
bindings = {
  { scope = "", keys = "SUPER + T", action = "original-floating" },
  { scope = "", keys = "SUPER + equal", action = "original-equal" },
  { scope = "", keys = "SUPER + code:21", action = "original-resize" },
  { scope = "", keys = "SHIFT + SUPER + code:21", action = "original-shift-resize" },
}
load({ keyboard = false, disabled_shortcuts = { "SUPER + T", "SUPER + equal", "SUPER + SHIFT + equal" }, desktop_layer = false })
assert(binding(":SUPER + T") == "original-floating")
assert(binding(":SUPER + code:21") == "original-resize")
assert(binding(":SUPER + equal") == "original-equal")
assert(binding(":SHIFT + SUPER + code:21") == "original-shift-resize")
assert(not binding(":SUPER + ESCAPE"))
bindings = {}
load({ applications = false, navigation = false, terminal_clipboard = false, app_switching = false, desktop = false, desktop_layer = false })
assert(next(bindings) == nil)
load({ enabled = false })
assert(next(bindings) == nil)
load()
local count = #bindings
load()
assert(#bindings == count, "Reload must not multiply registrations")
assert(options == "compose:caps,shift:both_capslock_cancel,altwin:swap_lalt_lwin")
print("Runtime checks passed: app routing, native Control, navigation, clipboard, app cycling, desktop layer, profiles, settings, reload")
