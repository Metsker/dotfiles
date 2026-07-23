hl.config({
  input = {
    kb_layout  = "us,ru",
    kb_options = "caps:escape,grp:ctrl_space_toggle",
    repeat_rate  = 25,
    repeat_delay = 600,
    follow_mouse = 1, -- sloppy focus
    touchpad = {
      natural_scroll       = true,
      tap_to_click         = true,
      tap_and_drag         = true,
      disable_while_typing = true,
    },
  },
  cursor = {
    inactive_timeout = 5, -- hide cursor after 5s idle
  },
})
