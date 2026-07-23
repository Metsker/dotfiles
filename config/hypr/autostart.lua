-- Noctalia starts via its systemd user service on graphical-session.target (uwsm).
-- Session env (NIXOS_OZONE_WL, QT theme) lives in ~/.config/uwsm/env so services see it.
-- Apps launch as uwsm scopes for clean cgroup teardown on logout.
hl.on("hyprland.start", function()
  hl.exec_cmd("uwsm app -- AmneziaVPN --autostart")
  hl.exec_cmd("uwsm app -- openrgb --startminimized")
  hl.exec_cmd("uwsm app -- solaar --window=hide")
  hl.exec_cmd("uwsm app -- Telegram")
  hl.exec_cmd("uwsm app -- discord")
  hl.exec_cmd("uwsm app -- webapp https://music.youtube.com/")
  hl.exec_cmd("uwsm app -- webapp https://brain.metsker.dev")
end)
