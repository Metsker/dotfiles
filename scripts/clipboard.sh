action=${1:?usage: clipboard copy|paste}
case "$action" in
  copy) key=c ;;
  paste) key=v ;;
  *) echo "usage: clipboard copy|paste" >&2; exit 1 ;;
esac

# Match the process, not the appid: a window renamed with mango's --app-id still resolves.
# Shared by both desktop profiles, so ask whichever compositor is actually up.
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty' || true)
else
  pid=$(mmsg get focusing-client 2>/dev/null | jq -r '.pid // empty' || true)
fi
comm=""
if [ -n "$pid" ] && [ -r "/proc/$pid/comm" ]; then
  read -r comm < "/proc/$pid/comm"
fi

case "$comm" in
  foot | footclient | alacritty | kitty | wezterm | ghostty | xterm | st | monstar | *term*)
    wtype -M ctrl -M shift -k "$key" -m shift -m ctrl ;;
  *)
    wtype -M ctrl -k "$key" -m ctrl ;;
esac
