# One bind for noctalia's screen_recorder: stop a running capture, otherwise ask
# which audio to include. The plugin reads audio_source from settings only at start,
# so the answer is written there and reloaded before the recording begins.
service() { noctalia msg plugin noctalia/screen_recorder:service all "$1"; }

if pgrep -x gpu-screen-recorder >/dev/null; then
  service stop
  exit 0
fi

answer=$(printf 'Desktop\nDesktop + mic\nSilent\n' | noctalia dmenu -p 'Record audio') || exit 0
case "$answer" in
  'Desktop') audio=default_output ;;
  'Desktop + mic') audio=both ;;
  'Silent') audio=none ;;
  *) exit 0 ;;
esac

settings="$HOME/.local/state/noctalia/settings.toml"
section='/^\[plugin_settings."noctalia\/screen_recorder"\]/'
# --follow-symlinks keeps home-manager's symlink chain intact instead of replacing it.
sed -i --follow-symlinks \
  -e "$section,/^\[/{/^audio_source/d}" \
  -e "${section}a audio_source = \"$audio\"" \
  "$settings"
noctalia msg config-reload
service start
