-- Per-monitor "tags": workspaces 1-9 on HDMI-A-2, 11-19 on DP-1; persistent so
-- Noctalia keeps empty ones visible in its workspace indicator.
for i = 1, 9 do
  hl.workspace_rule({ workspace = tostring(i),      monitor = "HDMI-A-2", layout = "scrolling", persistent = true })
  hl.workspace_rule({ workspace = tostring(i + 9), 	monitor = "DP-1",     layout = "scrolling", persistent = true })
end

-- Floating media/utility windows at 75% size, centered.
for _, cls in ipairs({ "com.gabm.satty", "mpv", "imv" }) do
  hl.window_rule({ match = { class = cls }, float = true, size = "75% 75%", center = true })
end
hl.window_rule({ match = { class = "AmneziaVPN" }, float = true })

-- Screen-share source picker (empty class), match by title.
hl.window_rule({ match = { title = "^Select what to share$" }, float = true })

-- Noctalia settings window floats at a fixed size.
hl.window_rule({ match = { class = "dev.noctalia.Noctalia" }, float = true, size = { 1080, 920 } })

-- Autostart apps land on DP-1 workspaces without stealing focus (mango isopensilent).
hl.window_rule({ match = { class = "org.telegram.desktop" }, workspace = "12", no_initial_focus = true })
hl.window_rule({ match = { class = "discord" },              workspace = "12", no_initial_focus = true })
hl.window_rule({ match = { class = "music.youtube.com" },    workspace = "13", no_initial_focus = true })
hl.window_rule({ match = { class = "brain.metsker.dev" },    workspace = "14", no_initial_focus = true })

-- Steam popups float; the main "Steam" window tiles.
hl.window_rule({ match = { class = "steam", title = "^(?!Steam$).*" }, float = true })

-- Screenshot/picker overlays skip animation so they appear instantly.
for _, ns in ipairs({ "selection", "wayfreeze", "hyprpicker" }) do
  hl.layer_rule({ match = { namespace = ns }, no_anim = true })
end

-- Blur Noctalia's shell surfaces; skip layer anims so they don't fight Noctalia's own.
hl.layer_rule({
  name = "noctalia",
  match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
  no_anim = true,
  ignore_alpha = 0.5,
  blur = true,
  blur_popups = true,
})
