-- DMS user keybind overrides (edit via Control Center or dms; do not remove this header)
--
-- This is the whole personal Hyprland config. `dms setup` generates ~/.config/hypr/hyprland.lua
-- and the fragments beside it, none of which are tracked, and it requires this file last - so
-- everything that has to survive a regeneration lives here. Ported from config/mango/*.conf so
-- both desktop profiles behave the same; see that directory for the original of each section.

-- `dms setup` only appends require("dms.binds") and require("dms.binds-user") to hyprland.lua,
-- so the other generated fragments are pulled in here or they would never load - the monitor
-- layout in outputs.lua included, which is why Hyprland was auto-arranging the outputs.
require("dms.outputs")
require("dms.layout")
require("dms.colors")
require("dms.windowrules")

local mod = "SUPER"

-- Every bind below replaces one from the generated hyprland.lua, and Hyprland keeps both
-- otherwise. Unbinding a key that was never bound is a no-op, so this is safe to call blindly.
local function bind(keys, dispatcher, opts)
  hl.unbind(keys)
  hl.bind(keys, dispatcher, opts)
end

-- ---- Input (config/mango/input.conf) ----

hl.config({
  input = {
    kb_layout = "us,ru",
    kb_options = "caps:escape,grp:ctrl_space_toggle",
    repeat_rate = 25,
    repeat_delay = 600,
    follow_mouse = 1, -- sloppy focus
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      tap_and_drag = true,
      disable_while_typing = true,
    },
    -- Touchscreen: bind it to its own panel, otherwise touches span the whole output layout.
    touchdevice = { output = "HDMI-A-3" },
  },
  cursor = { inactive_timeout = 5 },
  misc = { focus_on_activate = true },
  -- mango pins every tag to right_tile, so master is the layout and the master area sits right.
  general = { layout = "master" },
  master = { orientation = "right", mfact = 0.5, new_status = "master", new_on_top = true },
})

-- ---- Workspaces (config/mango/monitors.conf + the tag binds in keybinds.conf) ----

-- mango gives every monitor its own tags 1-9, while Hyprland workspace ids are global, so the
-- monitor goes in the tens digit: 1-9 on HDMI-A-2, 11-19 on DP-1, 21-29 on the HDMI-A-3 panel.
-- persistent keeps empty ones in the DMS workspace indicator, the way mango shows empty tags.
local screens = {
  { monitor = "HDMI-A-2", base = 0, view = mod, move = mod .. " + SHIFT" },
  { monitor = "DP-1", base = 10, view = mod .. " + ALT", move = mod .. " + ALT + SHIFT" },
  { monitor = "HDMI-A-3", base = 20, view = mod .. " + ALT + CTRL", move = mod .. " + ALT + CTRL + SHIFT" },
}

for _, screen in ipairs(screens) do
  for tag = 1, 9 do
    local ws = tostring(screen.base + tag)
    hl.workspace_rule({
      workspace = ws,
      monitor = screen.monitor,
      default = tag == 1,
      persistent = true,
    })
    bind(screen.view .. " + " .. tag, hl.dsp.focus({ workspace = ws }))
    bind(screen.move .. " + " .. tag, hl.dsp.window.move({ workspace = ws }))
  end
end

-- ---- Window rules (config/mango/rules.conf) ----

for _, class in ipairs({ "com.gabm.satty", "mpv", "imv" }) do
  hl.window_rule({
    match = { class = class },
    float = true,
    size = { "monitor_w*0.75", "monitor_h*0.75" },
    center = true,
  })
end

hl.window_rule({ match = { class = "AmneziaVPN" }, float = true })
hl.window_rule({ match = { class = "engrampa" }, float = true })
hl.window_rule({ match = { title = "^Select Folder$" }, float = true })
-- Screen-share source picker: it has no class, so match the title.
hl.window_rule({ match = { title = "^Select what to share$" }, float = true })
hl.window_rule({ match = { class = "zen", title = "Library" }, float = true })
hl.window_rule({ match = { class = "org.telegram.desktop", title = "Media viewer" }, float = true })
-- RE2 has no lookahead, so mango's ^(?!Steam$) becomes Hyprland's negative: prefix.
hl.window_rule({ match = { class = "^[Ss]team$", title = "negative:^Steam$" }, float = true })

for _, title in ipairs({ "^[Rr]ename", "^[Ff]ile Operation Progress", "^[Cc]onfirm to replace files" }) do
  hl.window_rule({ match = { class = "thunar", title = title }, float = true })
end

-- Autostart apps open on their tag without pulling the view along (mango isopensilent).
local placements = {
  { class = "org.telegram.desktop", title = "negative:^Media viewer$", workspace = "12" },
  { class = "discord", workspace = "12" },
  { class = "^herdr$", workspace = "11" },
  { class = "notes\\.metsker\\.dev__brain", workspace = "14" },
  { class = "spotify", workspace = "21" },
}

for _, app in ipairs(placements) do
  hl.window_rule({
    match = { class = app.class, title = app.title },
    workspace = app.workspace .. " silent",
    no_initial_focus = true,
  })
end

-- Screenshot and picker overlays skip animation so they appear instantly.
for _, namespace in ipairs({ "selection", "wayfreeze", "hyprpicker" }) do
  hl.layer_rule({ match = { namespace = namespace }, no_anim = true })
end

-- ---- Autostart (config/mango/autostart.conf) ----

-- No `uwsm finalize` here: the hyprland-uwsm session entry already runs it, which is why
-- graphical-session.target comes up and DMS starts. Apps launch as uwsm scopes so logging
-- out tears their cgroups down cleanly.
hl.on("hyprland.start", function()
  -- nm-online: the session can start before the network is up, and connecting too early stalls 60s+.
  hl.exec_cmd("uwsm app -- sh -c 'nm-online -q -t 30; exec AmneziaVPN'")
  hl.exec_cmd("uwsm app -- openrgb-profile carrot")
  hl.exec_cmd("uwsm app -- solaar-start")
  hl.exec_cmd("uwsm app -- Telegram")
  hl.exec_cmd("uwsm app -- discord")
  hl.exec_cmd("uwsm app -- monstar --app-id herdr -e herdr")
  hl.exec_cmd("uwsm app -- webapp https://notes.metsker.dev/brain/")
  hl.exec_cmd("uwsm app -- spotify")
end)

-- ---- Keybinds (config/mango/keybinds.conf) ----

-- Session
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
bind(mod .. " + Q", hl.dsp.window.close())
bind(mod .. " + Escape", hl.dsp.exec_cmd("dms ipc call powermenu toggle"))
bind(mod .. " + CTRL + Escape", hl.dsp.exec_cmd("dms ipc call lock lock"))

-- Launchers
bind(mod .. " + Return", hl.dsp.exec_cmd("$TERMINAL"))
bind(mod .. " + ALT + Return", hl.dsp.exec_cmd("$TERMINAL -e herdr"))
bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("zen-beta"))
bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd("$TERMINAL -e yazi"))
bind(mod .. " + ALT + SHIFT + F", hl.dsp.exec_cmd("dolphin"))
bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("$TERMINAL --working-directory ~/dotfiles/ -e nvim modules/"))
-- mango's Super+Shift+M opens its own config; the counterpart here is the Hyprland one.
bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("$TERMINAL --working-directory ~/dotfiles/config/hypr/ -e nvim ."))
bind(mod .. " + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"), { description = "Default Launcher: Toggle" })

-- Clipboard (mac-style): the clipboard script sends Ctrl+C/V in apps, Ctrl+Shift+C/V in terminals.
bind(mod .. " + C", hl.dsp.exec_cmd("clipboard copy"))
bind(mod .. " + V", hl.dsp.exec_cmd("clipboard paste"))
bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))

-- Screenshots. mango's Super+Alt+Print has no counterpart: `record` drives noctalia's
-- screen_recorder plugin and DMS ships no equivalent.
bind("Print", hl.dsp.exec_cmd("screenshot"))
bind(mod .. " + Print", hl.dsp.exec_cmd("colorpicker"))
bind(mod .. " + CTRL + Print", hl.dsp.exec_cmd("textpicker"))

-- Focus and swap, arrows and hjkl alike (mango focusdir / exchange_client).
local directions = {
  { keys = { "h", "Left" }, direction = "left" },
  { keys = { "j", "Down" }, direction = "down" },
  { keys = { "k", "Up" }, direction = "up" },
  { keys = { "l", "Right" }, direction = "right" },
}

for _, dir in ipairs(directions) do
  for _, key in ipairs(dir.keys) do
    bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir.direction }))
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir.direction }))
    -- Monitors: l/r/u/d select the neighbour in that direction.
    bind(mod .. " + CTRL + " .. key, hl.dsp.focus({ monitor = dir.direction:sub(1, 1) }))
    bind(mod .. " + CTRL + SHIFT + " .. key, hl.dsp.window.move({ monitor = dir.direction:sub(1, 1) }))
  end
end

bind(mod .. " + Tab", hl.dsp.layout("cyclenext"))
bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), { repeating = true })
bind("ALT + Tab", hl.dsp.window.cycle_next(), { repeating = true })
bind("SHIFT + ALT + Tab", hl.dsp.window.cycle_next({ next = false }), { repeating = true })

-- Window state
bind(mod .. " + I", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind(mod .. " + ALT + P", hl.dsp.window.pin())
-- mango's toggle_scratchpad both stashes and restores; Hyprland needs the two halves apart.
bind(mod .. " + Z", hl.dsp.workspace.toggle_special("special"))
bind(mod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:special" }))

-- mango's switch_proportion_preset, mapped onto the master split ratio.
local presets, preset = { 0.5, 0.65, 0.75 }, 1
bind(mod .. " + R", function()
  preset = preset % #presets + 1
  hl.dispatch(hl.dsp.layout("mfact exact " .. presets[preset]))
end)

-- Cycle tags on the focused monitor (mango viewtoleft / viewtoright and their tag moves).
bind(mod .. " + P", hl.dsp.focus({ workspace = "m-1" }))
bind(mod .. " + N", hl.dsp.focus({ workspace = "m+1" }))
bind(mod .. " + SHIFT + P", hl.dsp.window.move({ workspace = "m-1" }))
bind(mod .. " + SHIFT + N", hl.dsp.window.move({ workspace = "m+1" }))

-- Shell panels
bind(mod .. " + O", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
bind(mod .. " + S", hl.dsp.exec_cmd("dms ipc call control-center toggle"))
bind(mod .. " + comma", hl.dsp.exec_cmd("dms ipc call settings toggle"))

-- Media and brightness, routed through DMS so its OSD shows. locked = still active while locked.
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement"), { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"), { locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("dms ipc call mic mute"), { locked = true })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement"), { locked = true, repeating = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })

-- Mouse: Super+LMB moves, Super+RMB resizes, and the wheel cycles tags on the focused
-- monitor - the generated config scrolls with e+1/e-1, which would hop between monitors.
bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "m-1" }))

-- Leftovers from the generated hyprland.lua that mango has no counterpart for. 0 would land
-- on workspace 10, which is outside the 1-9 / 11-19 / 21-29 scheme; E duplicates the file
-- manager already on Super+Alt+Shift+F.
for _, keys in ipairs({ mod .. " + 0", mod .. " + SHIFT + 0", mod .. " + E" }) do
  hl.unbind(keys)
end
