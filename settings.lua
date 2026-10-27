-- Command sends Super; Control stays Ctrl. Use "apple" on an Apple keyboard.
-- Set any group to false, or list an exact binding in disabled_shortcuts.
return {
  enabled = true,
  keyboard = "pc",
  applications = true,
  navigation = true,
  terminal_clipboard = true,
  app_switching = true,
  desktop = true,
  desktop_layer = true,
  desktop_prefix = "SUPER + ESCAPE",
  launcher = "omarchy-menu toggle",
  desktop_shortcuts = {}, -- Overrides inside the one-shot desktop layer.
  disabled_shortcuts = {},
  terminal_classes = {}, -- Additional terminal app IDs, if Omarchy hasn't tagged them.
}
