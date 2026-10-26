-- Command is the key beside Space. Set keyboard = "apple" on an Apple keyboard.
-- Set any group to false, or list an exact binding in disabled_shortcuts.
return {
  enabled = true,
  keyboard = "pc",
  navigation = true,
  terminal_clipboard = true,
  app_switching = true,
  desktop = true,
  launcher = "omarchy-menu toggle",
  disabled_shortcuts = {},
  terminal_classes = {}, -- Additional terminal app IDs, if Omarchy hasn't tagged them.
}
