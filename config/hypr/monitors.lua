-- HDMI-A-2 (144Hz) is the left monitor at 0x0; DP-1 (75Hz) is right at 1920x0.
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@144", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1",     mode = "1920x1080@75",  position = "1920x0", scale = 1 })
