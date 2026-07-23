local general = {
  gaps_in     = 4,
  gaps_out    = 8,
  border_size = 2,
  layout      = "scrolling",
}

hl.config({
  general = general,
  decoration = {
    rounding = 0,
    blur   = { enabled = true, size = 3, passes = 2, vibrancy = 0.1696 },
    shadow = { enabled = true, range = 4, render_power = 3 },
  },
  animations = { enabled = true },
  scrolling = {
    column_width             = 0.5,
    focus_fit_method         = 1,
    fullscreen_on_one_column = true,
    direction                = "right",
  },
  misc = {
    disable_hyprland_logo   = true,
    force_default_wallpaper = 0,
    focus_on_activate       = true,
  },
})

hl.curve("easy", { type = "spring", mass = 1, stiffness = 878.5, dampening = 59.29 })
-- Snappier animations: speeds well below Hyprland's defaults (speed is in ds, 1ds = 100ms).
-- hl.curve("snappy", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.animation({ leaf = "windows",    enabled = true, speed = 3,   spring = "easy" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2,   spring = "easy" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.2, spring = "easy" })
hl.animation({ leaf = "layers",     enabled = true, speed = 2,   spring = "easy" })
