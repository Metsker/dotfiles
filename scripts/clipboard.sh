action=${1:?usage: clipboard copy|paste}
case "$action" in
  copy) key=c ;;
  paste) key=v ;;
  *) echo "usage: clipboard copy|paste" >&2; exit 1 ;;
esac

# wminfo answers for whichever compositor is up: a process name where the IPC carries a pid,
# an app id where it does not - which is why the case below also lists the appids the
# autostarted terminals are renamed to.
name="$(wminfo focused-name)"

case "$name" in
  herdr)
    wtype -M ctrl -M shift -k "$key" -m shift -m ctrl ;;
  foot | footclient | alacritty | kitty | wezterm | ghostty | xterm | st | monstar | *term*)
    wtype -M ctrl -M shift -k "$key" -m shift -m ctrl ;;
  *)
    wtype -M ctrl -k "$key" -m ctrl ;;
esac
