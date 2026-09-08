query=${1:?usage: wminfo boxes|cursorpos|focused-name|focused-window|watch-focused-window}

# The only script that names a compositor: the wayland tools and noctalia's window-info widget ask
# these questions and stay branch-free, so a new compositor is one more case block here and nothing else.
#
#   boxes                 window rectangles for slurp to snap to, one "x,y wxh label" per line
#   cursorpos             the pointer as "x y", empty where the compositor cannot report it
#   focused-name          the focused window's process name, or its app id where the IPC carries no pid
#   focused-window        the focused window as {"title":...,"appid":...}, once
#   watch-focused-window  that same object again on every focus change, until killed
#
# Both window queries exit nonzero when the IPC itself fails; null fields are an empty desktop.

# Match the process rather than the app id: a window renamed with --app-id still resolves.
pid_name() {
  pid=${1:-}
  if [ -n "$pid" ] && [ "$pid" != "-1" ] && [ -r "/proc/$pid/comm" ]; then
    read -r comm_name < "/proc/$pid/comm"
    printf '%s\n' "$comm_name"
  fi
}

case "${XDG_CURRENT_DESKTOP:-}" in
  mango)
    case "$query" in
      boxes)
        mmsg get all-clients 2>/dev/null \
          | jq -r '.clients[]
                   | select(.is_visible and (.is_minimized | not))
                   | "\(.x),\(.y) \(.width)x\(.height) \(.appid)"' 2>/dev/null || true ;;
      cursorpos)
        mmsg get cursorpos 2>/dev/null | jq -r '"\(.x|floor) \(.y|floor)"' 2>/dev/null || true ;;
      focused-name)
        pid_name "$(mmsg get focusing-client 2>/dev/null | jq -r '.pid // empty' 2>/dev/null || true)" ;;
      # Whatever mango sends for an empty desktop carries no title, and that maps to null fields.
      focused-window)
        mmsg get focusing-client | jq -c '{title, appid}' ;;
      watch-focused-window)
        mmsg watch focusing-client | jq -c --unbuffered '{title, appid}' ;;
    esac ;;
  umbriel)
    case "$query" in
      # Windows carry layout coordinates whatever workspace they sit on, so keep the visible ones.
      boxes)
        umbriel windows --json 2>/dev/null \
          | jq -r --argjson ws "$(umbriel workspaces --json 2>/dev/null || echo '[]')" \
              '($ws | map(select(.active) | .id)) as $visible
               | .[]
               | select(.workspace as $w | $visible | index($w))
               | "\(.x),\(.y) \(.w)x\(.h) \(.app_id)"' 2>/dev/null || true ;;
      # umbriel leaves the cursor out of a screencopy capture, so nothing has to park it.
      cursorpos) ;;
      # focused is set once per output; active marks the single window holding the keyboard.
      focused-name)
        pid_name "$(umbriel windows --json 2>/dev/null | jq -r '.[] | select(.active) | .pid // empty' 2>/dev/null || true)" ;;
      focused-window)
        umbriel windows --json | jq -c 'map(select(.active)) | (.[0] // {}) | {title, appid: .app_id}' ;;
      # The stream carries the whole window list per change, wrapped in an event envelope.
      watch-focused-window)
        umbriel subscribe windows \
          | jq -c --unbuffered '(.data // []) | map(select(.active)) | (.[0] // {}) | {title, appid: .app_id}' ;;
    esac ;;
  driftwm)
    case "$query" in
      # driftwm's IPC carries neither window boxes, the pointer, nor a focus event to watch.
      boxes | cursorpos | focused-window | watch-focused-window) ;;
      focused-name)
        driftwm msg focus --json 2>/dev/null | jq -r '.Ok.Focused.app_id // empty' 2>/dev/null || true ;;
    esac ;;
esac
