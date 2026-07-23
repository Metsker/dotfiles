-- Hyprland config entry point (native Lua, Hyprland >= 0.55).
-- Docs: https://wiki.hypr.land/Configuring/
require("monitors")
require("appearance")
require("input")
require("rules")
require("keybinds")
require("autostart")

-- For Noctalia Color templates
require("noctalia").apply_theme()
