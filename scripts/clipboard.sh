action=${1:?usage: clipboard copy|paste}
case "$action" in
  copy) key=c ;;
  paste) key=v ;;
  *) echo "usage: clipboard copy|paste" >&2; exit 1 ;;
esac

# Shared by all three desktop profiles, so ask whichever compositor is actually up.
# mango and umbriel report the focused client's pid, so match the process: a window renamed with
# --app-id still resolves. driftwm's IPC carries no pid, so there it is the appid or nothing -
# which is why the case below also lists the appids the autostarted terminals are renamed to.
pid=""
case "${XDG_CURRENT_DESKTOP:-}" in
  driftwm)
    name=$(driftwm msg focus --json 2>/dev/null | jq -r '.Ok.Focused.app_id // empty' || true) ;;
  Umbriel)
    pid=$(umbriel windows --json 2>/dev/null | jq -r '.[] | select(.focused) | .pid // empty' || true) ;;
  *)
    pid=$(mmsg get focusing-client 2>/dev/null | jq -r '.pid // empty' || true) ;;
esac

if [ -n "$pid" ] && [ "$pid" != "-1" ] && [ -r "/proc/$pid/comm" ]; then
  read -r name < "/proc/$pid/comm"
fi
name=${name:-}

case "$name" in
  herdr)
    wtype -M ctrl -M shift -k "$key" -m shift -m ctrl ;;
  foot | footclient | alacritty | kitty | wezterm | ghostty | xterm | st | monstar | *term*)
    wtype -M ctrl -M shift -k "$key" -m shift -m ctrl ;;
  *)
    wtype -M ctrl -k "$key" -m ctrl ;;
esac
