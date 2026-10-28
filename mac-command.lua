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
local function bind(keys, description, action, replaces)
  if disabled[keys] then return end
  hl.unbind(keys)
  for _, alias in ipairs(replaces or {}) do hl.unbind(alias) end
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
  if keyboard == "pc" then table.insert(options, "altwin:swap_lalt_lwin") end
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

local function translate(keys, description, normal, in_terminal, replaces)
  bind(keys, description, function()
    send((terminal() and in_terminal) or normal)
  end, replaces)
end

if settings.navigation ~= false then
  for _, shift in ipairs({ false, true }) do
    local prefix = shift and "SHIFT + " or ""
    local selection = shift and "SHIFT" or ""
    local word = shift and "CTRL + SHIFT" or "CTRL"
    local terminal_start = shift and {{"SHIFT", "Home"}} or {{"CTRL", "A"}}
    local terminal_end = shift and {{"SHIFT", "End"}} or {{"CTRL", "E"}}
    translate(prefix .. "SUPER + LEFT", "Line start", {{selection, "Home"}}, terminal_start)
    translate(prefix .. "SUPER + RIGHT", "Line end", {{selection, "End"}}, terminal_end)
    translate(prefix .. "SUPER + UP", "Document start", {{word, "Home"}})
    translate(prefix .. "SUPER + DOWN", "Document end", {{word, "End"}})
    translate(prefix .. "ALT + LEFT", "Previous word", {{word, "Left"}})
    translate(prefix .. "ALT + RIGHT", "Next word", {{word, "Right"}})
  end
  translate("SUPER + BACKSPACE", "Delete to line start", {{"SHIFT", "Home"}, {"", "BackSpace"}}, {{"CTRL", "U"}})
  translate("ALT + BACKSPACE", "Delete previous word", {{"CTRL", "BackSpace"}}, {{"CTRL", "W"}})
  translate("ALT + DELETE", "Delete next word", {{"CTRL", "Delete"}}, {{"ALT", "D"}})
end

if settings.applications ~= false then
  for _, key in ipairs({ "A", "B", "D", "E", "I", "U", "G", "K", "L", "N", "O", "P", "Q", "R", "S", "T", "W", "Z" }) do
    translate("SUPER + " .. key, "App " .. key, {{"CTRL", key}})
  end
  for _, key in ipairs({ "F", "G", "N", "P", "S", "T", "W", "Z" }) do
    translate("SUPER + SHIFT + " .. key, "App Shift+" .. key, {{"CTRL + SHIFT", key}})
  end
  translate("SUPER + comma", "App preferences", {{"CTRL", "comma"}})
  local zoom_shortcuts = {
    { "SUPER + minus", "CTRL", "minus", { "SUPER + code:20" } },
    { "SUPER + equal", "CTRL", "equal", { "SUPER + code:21" } },
    { "SUPER + SHIFT + equal", "CTRL + SHIFT", "equal", { "SUPER + SHIFT + code:21" } },
    { "SUPER + 0", "CTRL", "0" },
  }
  for _, shortcut in ipairs(zoom_shortcuts) do
    translate(shortcut[1], "App zoom", {{shortcut[2], shortcut[3]}}, nil, shortcut[4])
  end
end

if settings.terminal_clipboard ~= false then
  translate("SUPER + C", "Copy", {{"CTRL", "C"}}, {{"CTRL + SHIFT", "C"}})
  bind("SUPER + V", "Paste text or image", function()
    if terminal() then
      local command = os.getenv("HOME") .. "/.local/bin/omarchy-mac-command"
      hl.exec_cmd(o.shell_quote(command) .. " paste --window " .. o.shell_quote(hl.get_active_window().address))
    else
      send({{"CTRL", "V"}})
    end
  end)
  translate("SUPER + X", "Cut", {{"CTRL", "X"}})
  translate("SUPER + SHIFT + C", "Copy (alternate)", {{"CTRL + SHIFT", "C"}}, {{"CTRL + SHIFT", "C"}})
  translate("SUPER + SHIFT + V", "Paste (alternate)", {{"CTRL + SHIFT", "V"}}, {{"CTRL + SHIFT", "V"}})
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
  bind("SUPER + TAB", "Next app", function() switch_app(1) end)
  bind("SUPER + SHIFT + TAB", "Previous app", function() switch_app(-1) end)
end

if settings.desktop ~= false then
  bind("SUPER + SPACE", "Launcher", settings.launcher or "omarchy-menu toggle")
  if o.cmd_present("omasnap") then
    bind("SUPER + ALT + code:13", "Screenshot (Omasnap)", "omasnap")
  else
    bind("SUPER + ALT + code:13", "Screenshot", "omarchy-capture-screenshot")
  end
end

-- A one-shot desktop layer keeps window actions away from app shortcuts.
if settings.desktop_layer ~= false then
  bind(settings.desktop_prefix or "SUPER + ESCAPE", "Desktop layer", hl.dsp.submap("mac-command-desktop"))
  hl.define_submap("mac-command-desktop", "reset", function()
    local actions = {
      { "F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }) },
      { "T", "Floating", hl.dsp.window.float({ action = "toggle" }) },
      { "W", "Close window", hl.dsp.window.close() },
      { "S", "Scratchpad", hl.dsp.workspace.toggle_special("scratchpad") },
      { "L", "Workspace layout", "omarchy-hyprland-workspace-layout-toggle" },
      { "G", "Window grouping", hl.dsp.group.toggle() },
      { "P", "Pseudo window", hl.dsp.window.pseudo() },
      { "O", "Pop window out", "omarchy-hyprland-window-pop" },
      { "K", "Keybindings", "omarchy-menu-keybindings" },
      { "TAB", "Next workspace", hl.dsp.focus({ workspace = "e+1" }) },
      { "SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }) },
      { "BACKSPACE", "Transparency", "omarchy-hyprland-window-transparency-toggle" },
      { "comma", "Dismiss notification", "omarchy-shell notifications dismissOne" },
      { "ESCAPE", "System menu", "omarchy-menu toggle system" },
      { "minus", "Resize narrower", hl.dsp.window.resize({ x = -100, y = 0, relative = true }) },
      { "equal", "Resize wider", hl.dsp.window.resize({ x = 100, y = 0, relative = true }) },
    }
    for _, direction in ipairs({ {"LEFT", "l"}, {"RIGHT", "r"}, {"UP", "u"}, {"DOWN", "d"} }) do
      table.insert(actions, { direction[1], "Focus window", hl.dsp.focus({ direction = direction[2] }) })
      table.insert(actions, { "SHIFT + " .. direction[1], "Swap window", hl.dsp.window.swap({ direction = direction[2] }) })
    end
    for _, action in ipairs(actions) do
      bind(action[1], action[2], action[3])
    end
    for keys, action in pairs(settings.desktop_shortcuts or {}) do
      bind(keys, "Custom desktop action", action)
    end
    bind("catchall", "Leave desktop layer", hl.dsp.submap("reset"))
  end)
end
