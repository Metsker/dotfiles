-- Monitors. DMS Settings > Displays rewrites this file, so edits made there land in the repo.
--
-- HDMI-A-2 (144Hz) is the left monitor at 0x0, DP-1 (75Hz) is right at 1920x0, and the
-- HDMI-A-3 touch panel sits under DP-1. Same layout as config/mango/monitors.conf.

hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@144", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-1", mode = "1920x1080@75", position = "1920x0", scale = 1 })
hl.monitor({ output = "HDMI-A-3", mode = "1920x1080@60", position = "1920x1080", scale = 1 })
