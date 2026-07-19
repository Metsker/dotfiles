wayfreeze --hide-cursor &
freeze_pid=$!

cleanup() {
  kill "$freeze_pid" 2>/dev/null || true
}
trap cleanup EXIT

hyprpicker -a -f hex
