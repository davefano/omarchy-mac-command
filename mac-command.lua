-- Mac Command: loaded after Omarchy and personal Hyprland settings.
local config_home = os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config"
local settings_path = config_home .. "/omarchy/mac-command.lua"
local settings = {}
local file = io.open(settings_path, "r")
if file then
  file:close()
  settings = dofile(settings_path)
  assert(type(settings) == "table", "mac-command.lua settings must return a table")
end
if settings.enabled == false then return end

local disabled = {}
for _, shortcut in ipairs(settings.disabled_shortcuts or {}) do disabled[shortcut] = true end
local function bind(keys, description, action)
  if disabled[keys] then return end
  hl.unbind(keys)
  o.bind(keys, "Mac Command: " .. description, action)
end

if settings.keyboard ~= false then
  local conflicting = {
    ["altwin:swap_lalt_lwin"] = true, ["altwin:swap_alt_win"] = true,
    ["ctrl:swap_lalt_lctl"] = true, ["ctrl:swap_lwin_lctl"] = true,
    ["ctrl:swap_lalt_lctl_lwin"] = true,
  }
  local options = {}
  for option in (hl.get_config("input:kb_options") or ""):gmatch("[^,]+") do
    if not conflicting[option] then table.insert(options, option) end
  end
  local keyboard = settings.keyboard or "pc"
  assert(keyboard == "pc" or keyboard == "apple", "Mac Command keyboard must be pc, apple, or false")
  table.insert(options, keyboard == "apple" and "ctrl:swap_lwin_lctl" or "ctrl:swap_lalt_lctl_lwin")
  hl.config({ input = { kb_options = table.concat(options, ",") } })
end

local function terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  for _, class in ipairs(settings.terminal_classes or {}) do
    if window.class == class then return true end
  end
  return false
end

-- Match Omarchy's clipboard implementation: explicit modifier states go straight
-- to the surface, avoiding recursive bindings and physically held modifiers.
local function send(sequence, index)
  index = index or 1
  local chord = sequence[index]
  hl.dispatch(hl.dsp.send_key_state({ mods = chord[1], key = chord[2], state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = chord[1], key = chord[2], state = "up" }))
    if sequence[index + 1] then send(sequence, index + 1) end
  end, { timeout = 20, type = "oneshot" })
end

local function translate(keys, description, normal, in_terminal)
  bind(keys, description, function()
    send((terminal() and in_terminal) or normal)
  end)
end

if settings.navigation ~= false then
  for _, shift in ipairs({ false, true }) do
    local prefix = shift and "SHIFT + " or ""
    local selection = shift and "SHIFT" or ""
    local word = shift and "CTRL + SHIFT" or "CTRL"
    local terminal_start = shift and {{"SHIFT", "Home"}} or {{"CTRL", "A"}}
    local terminal_end = shift and {{"SHIFT", "End"}} or {{"CTRL", "E"}}
    translate(prefix .. "CTRL + LEFT", "Line start", {{selection, "Home"}}, terminal_start)
    translate(prefix .. "CTRL + RIGHT", "Line end", {{selection, "End"}}, terminal_end)
    translate(prefix .. "CTRL + UP", "Document start", {{word, "Home"}})
    translate(prefix .. "CTRL + DOWN", "Document end", {{word, "End"}})
    translate(prefix .. "ALT + LEFT", "Previous word", {{word, "Left"}})
    translate(prefix .. "ALT + RIGHT", "Next word", {{word, "Right"}})
  end
  translate("CTRL + BACKSPACE", "Delete to line start", {{"SHIFT", "Home"}, {"", "BackSpace"}}, {{"CTRL", "U"}})
  translate("ALT + BACKSPACE", "Delete previous word", {{"CTRL", "BackSpace"}}, {{"CTRL", "W"}})
  translate("ALT + DELETE", "Delete next word", {{"CTRL", "Delete"}}, {{"ALT", "D"}})
end

if settings.terminal_clipboard ~= false then
  translate("CTRL + C", "Copy", {{"CTRL", "C"}}, {{"CTRL + SHIFT", "C"}})
  translate("CTRL + V", "Paste", {{"CTRL", "V"}}, {{"CTRL + SHIFT", "V"}})
  -- Physical far-left Ctrl sends Super. Preserve Ctrl+C's terminal meaning there.
  translate("SUPER + C", "Terminal interrupt / universal copy", {{"CTRL", "C"}})
end

local function switch_app(direction)
  local active = hl.get_active_window()
  local apps = {}
  for _, window in ipairs(hl.get_windows()) do
    if window.mapped and not window.hidden and window.workspace and window.workspace.id > 0 then
      local key = window.class ~= "" and window.class or window.address
      local old = apps[key]
      if not old or window.focus_history_id < old.focus_history_id then apps[key] = window end
    end
  end
  local keys = {}
  for key in pairs(apps) do table.insert(keys, key) end
  table.sort(keys)
  if #keys == 0 then return end
  local current = 0
  if active then
    local class = active.class ~= "" and active.class or active.address
    for index, key in ipairs(keys) do if key == class then current = index end end
  end
  local target = apps[keys[((current - 1 + direction) % #keys) + 1]]
  hl.dispatch(hl.dsp.focus({ window = target }))
  hl.dispatch(hl.dsp.window.alter_zorder({ window = target, mode = "top" }))
end
if settings.app_switching ~= false then
  bind("CTRL + TAB", "Next app", function() switch_app(1) end)
  bind("CTRL + SHIFT + TAB", "Previous app", function() switch_app(-1) end)
end

if settings.desktop ~= false then
  bind("CTRL + SPACE", "Launcher", settings.launcher or "omarchy-menu toggle")
  if o.cmd_present("omasnap") then
    bind("CTRL + ALT + code:13", "Screenshot (Omasnap)", "omasnap")
  else
    bind("CTRL + ALT + code:13", "Screenshot", "omarchy-capture-screenshot")
  end
end
