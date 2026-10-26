local bindings, sent, timers, configured = {}, {}, {}, nil
local window = { class = "browser", tags = {}, mapped = true, workspace = { id = 1 }, focus_history_id = 0, address = "0x1" }
local windows = { window }
local focused
local launched
hl = {
  exec_cmd = function(command) launched = command end,
  get_config = function() return "compose:caps,shift:both_capslock_cancel,altwin:swap_lalt_lwin" end,
  config = function(value) configured = value end,
  unbind = function(key) bindings[key] = nil end,
  get_active_window = function() return window end,
  get_windows = function() return windows end,
  timer = function(callback) table.insert(timers, callback) end,
  dispatch = function(value)
    if value.focus then focused = value.focus.window
    elseif value.raise then return
    else table.insert(sent, value) end
  end,
  dsp = {
    send_key_state = function(value) return value end,
    focus = function(value) return { focus = value } end,
    window = { alter_zorder = function(value) return { raise = value } end },
  },
}
o = {
  bind = function(key, description, action) bindings[key] = action end,
  cmd_present = function() return true end,
  shell_quote = function(value) return "\'" .. value .. "\'" end,
}
dofile("mac-command.lua")
assert(configured.input.kb_options == "compose:caps,shift:both_capslock_cancel,ctrl:swap_lalt_lctl_lwin")
local function run(key)
  sent = {}
  assert(bindings[key], "Missing shortcut: " .. key)()
  while #timers > 0 do table.remove(timers, 1)() end
end
local function expect(index, mods, key, state)
  local event = sent[index]
  assert(event and event.mods == mods and event.key == key and event.state == state,
    "Unexpected translated key at event " .. index)
end
run("CTRL + LEFT")
expect(1, "", "Home", "down")
expect(2, "", "Home", "up")
run("SHIFT + CTRL + RIGHT")
expect(1, "SHIFT", "End", "down")
run("ALT + LEFT")
expect(1, "CTRL", "Left", "down")
run("CTRL + BACKSPACE")
assert(#sent == 4)
expect(1, "SHIFT", "Home", "down")
expect(2, "SHIFT", "Home", "up")
expect(3, "", "BackSpace", "down")
expect(4, "", "BackSpace", "up")
run("CTRL + C")
expect(1, "CTRL", "C", "down")
window.tags = { "terminal*" }
run("CTRL + C")
expect(1, "CTRL + SHIFT", "C", "down")
run("CTRL + V")
assert(#sent == 0, "Terminal paste must not query Wayland inside the compositor")
assert(launched:find(" paste --window '0x1'", 1, true), "Terminal paste must launch the focus-scoped helper")
window.tags = {}
launched = nil
run("CTRL + V")
expect(1, "CTRL", "V", "down")
assert(not launched, "GUI paste must not inspect the clipboard")
window.tags = { "terminal*" }
run("SUPER + C")
expect(1, "CTRL", "C", "down")
-- The physical Ctrl key sends Super; Codex must receive literal Ctrl+V.
run("SUPER + V")
expect(1, "CTRL", "V", "down")
expect(2, "CTRL", "V", "up")
run("CTRL + LEFT")
expect(1, "CTRL", "A", "down")
run("CTRL + BACKSPACE")
expect(1, "CTRL", "U", "down")
assert(#sent == 2)
window.tags = {}
local second = { class = "editor", tags = {}, mapped = true, workspace = { id = 2 }, focus_history_id = 1, address = "0x2" }
local hidden = { class = "hidden", mapped = true, hidden = true, workspace = { id = 3 } }
local older = { class = "editor", mapped = true, workspace = { id = 2 }, focus_history_id = 9, address = "0x3" }
windows = { window, older, second, hidden }
run("CTRL + TAB")
assert(focused == second, "Switching must choose the most recent window of the next app")
window = second
run("CTRL + TAB")
assert(focused.class == "browser", "App cycling must wrap")
run("CTRL + SHIFT + TAB")
assert(focused.class == "browser", "Reverse cycling must wrap")
assert(bindings["CTRL + SPACE"] == "omarchy-menu toggle")
assert(bindings["CTRL + ALT + code:13"] == "omasnap")
-- Loading again must not multiply callbacks or modifier options.
dofile("mac-command.lua")
local count = 0
for _ in pairs(bindings) do count = count + 1 end
assert(count == 23, "Unexpected number of bindings: " .. count)
print("Runtime checks passed (navigation, sequences, terminal clipboard, app cycling, reload)")
