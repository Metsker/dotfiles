local mod = "SUPER"

-- Session
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + Q",         hl.dsp.window.close())

-- Launchers
hl.bind(mod .. " + Return",         hl.dsp.exec_cmd("term"))
hl.bind(mod .. " + ALT + Return",   hl.dsp.exec_cmd("term -e herdr"))
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("zen-beta"))
hl.bind(mod .. " + SHIFT + F",      hl.dsp.exec_cmd("term -e yazi"))
hl.bind(mod .. " + space",          hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mod .. " + Escape",         hl.dsp.exec_cmd("noctalia msg panel-toggle session"))

-- Clipboard (mac-style; script is compositor-aware).
hl.bind(mod .. " + C",         hl.dsp.exec_cmd("clipboard copy"))
hl.bind(mod .. " + V",         hl.dsp.exec_cmd("clipboard paste"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))

-- Screenshots
hl.bind("Print",                 hl.dsp.exec_cmd("screenshot"))
hl.bind(mod .. " + Print",       hl.dsp.exec_cmd("colorpicker"))
hl.bind(mod .. " + ALT + Print", hl.dsp.exec_cmd("noctalia msg plugin noctalia/screen_recorder:service all toggle"))

-- Focus: left/right scroll between columns (centers, wraps); up/down within a column.
hl.bind(mod .. " + Left",  hl.dsp.layout("focus l"))
hl.bind(mod .. " + Right", hl.dsp.layout("focus r"))
hl.bind(mod .. " + h",     hl.dsp.layout("focus l"))
hl.bind(mod .. " + l",     hl.dsp.layout("focus r"))
hl.bind(mod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + Down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + k",     hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + j",     hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + Tab",   hl.dsp.window.cycle_next())

-- Move/swap: left/right swap columns; up/down swap within a column.
hl.bind(mod .. " + SHIFT + Left",  hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + Right", hl.dsp.layout("swapcol r"))
hl.bind(mod .. " + SHIFT + h",     hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + l",     hl.dsp.layout("swapcol r"))
hl.bind(mod .. " + SHIFT + Up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mod .. " + SHIFT + Down",  hl.dsp.window.swap({ direction = "down" }))
hl.bind(mod .. " + SHIFT + k",     hl.dsp.window.swap({ direction = "up" }))
hl.bind(mod .. " + SHIFT + j",     hl.dsp.window.swap({ direction = "down" }))

-- Window state
hl.bind(mod .. " + p", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + f", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + m", hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind(mod .. " + z", hl.dsp.workspace.toggle_special("magic")) -- scratchpad
hl.bind(mod .. " + r", hl.dsp.layout("colresize +conf"))         -- cycle column-width presets

-- Per-monitor tags: SUPER+N -> ws N (HDMI-A-2), SUPER+ALT+N -> ws 1N (DP-1).
-- SHIFT variants move the focused window instead of switching.
for i = 1, 9 do
  hl.bind(mod .. " + " .. i,               hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mod .. " + ALT + " .. i,         hl.dsp.focus({ workspace = tostring(i + 10) }))
  hl.bind(mod .. " + SHIFT + " .. i,       hl.dsp.window.move({ workspace = tostring(i) }))
  hl.bind(mod .. " + ALT + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i + 10) }))
end

-- Cycle workspaces on the focused monitor.
hl.bind(mod .. " + u",         hl.dsp.focus({ workspace = "-1", on_current_monitor = true }))
hl.bind(mod .. " + i",         hl.dsp.focus({ workspace = "+1", on_current_monitor = true }))
hl.bind(mod .. " + SHIFT + u", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mod .. " + SHIFT + i", hl.dsp.window.move({ workspace = "+1" }))

-- Monitors: HDMI-A-2 is left, DP-1 is right.
hl.bind(mod .. " + CTRL + h",     hl.dsp.focus({ monitor = "HDMI-A-2" }))
hl.bind(mod .. " + CTRL + l",     hl.dsp.focus({ monitor = "DP-1" }))
hl.bind(mod .. " + CTRL + Left",  hl.dsp.focus({ monitor = "HDMI-A-2" }))
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ monitor = "DP-1" }))
hl.bind(mod .. " + CTRL + SHIFT + h",     hl.dsp.window.move({ monitor = "HDMI-A-2" }))
hl.bind(mod .. " + CTRL + SHIFT + l",     hl.dsp.window.move({ monitor = "DP-1" }))
hl.bind(mod .. " + CTRL + SHIFT + Left",  hl.dsp.window.move({ monitor = "HDMI-A-2" }))
hl.bind(mod .. " + CTRL + SHIFT + Right", hl.dsp.window.move({ monitor = "DP-1" }))

-- Noctalia panels
hl.bind(mod .. " + s",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
hl.bind(mod .. " + t",     hl.dsp.exec_cmd("noctalia msg panel-toggle noctalia/timer:panel"))
hl.bind(mod .. " + comma", hl.dsp.exec_cmd("noctalia msg settings-toggle"))
hl.bind("ALT + Tab",       hl.dsp.exec_cmd("noctalia msg window-switcher"))

-- Media / brightness (locked = still active on the lock screen).
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0"), { locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-"),        { locked = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),         { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),       { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl --class=backlight set +10%"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class=backlight set 10%-"), { locked = true })

-- Mouse: Super+LMB move, Super+RMB resize.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- No native equivalent, dropped: toggleoverview (SUPER+o), switch_layout (SUPER+n).
