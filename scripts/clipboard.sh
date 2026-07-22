action=${1:?usage: clipboard copy|paste}
case "$action" in
  copy) key=c ;;
  paste) key=v ;;
  *) echo "usage: clipboard copy|paste" >&2; exit 1 ;;
esac

appid=$(mmsg get focusing-client 2>/dev/null | jq -r '.appid // empty')

case "${appid,,}" in
  foot | footclient | alacritty | kitty | wezterm | org.wezfurlong.wezterm | ghostty | com.mitchellh.ghostty | xterm | st | dev.rockorager.monstar | *term*)
    wtype -M ctrl -M shift -k "$key" -m shift -m ctrl ;;
  *)
    wtype -M ctrl -k "$key" -m ctrl ;;
esac
