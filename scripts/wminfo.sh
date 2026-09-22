query=${1:?usage: wminfo boxes|cursorpos|focused-name|focused-window|watch-focused-window|float-rules|float-rule <appid> <title>}

# The only script that names a compositor: the wayland tools and noctalia's window-info widget ask
# these questions and stay branch-free, so a new compositor is one more case block here and nothing else.
#
#   boxes                 window rectangles for slurp to snap to, one "x,y wxh label" per line
#   cursorpos             the pointer as "x y", empty where the compositor cannot report it
#   focused-name          the focused window's process name, or its app id where the IPC carries no pid
#   focused-window        the focused window as {"title":...,"appid":...}, once
#   watch-focused-window  that same object again on every focus change, until killed
#   float-rules           the compositor's own float rules, one "appid<tab>title<tab>title..." per
#                         line, the app id first and every title floated under it after it
#   float-rule <appid> <title>  add that title to the app's rule and drop it where it is already
#                              there, the rule going with its last title, then match the focused
#                              window to the new state
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

tab=$(printf '\t')

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
      # mango's rules live in its own config language, which nothing here writes yet.
      float-rules | float-rule) ;;
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
      # The literals each pattern was built from are kept in the comment above its block, so the
      # rules read back without having to unescape a regex.
      float-rules)
        generated="${XDG_CONFIG_HOME:-$HOME/.config}/umbriel/float-rules.toml"
        if [ -f "$generated" ]; then
          sed -n "s/^# rule$tab//p" "$generated"
        fi ;;
      float-rule)
        appid=${2-}
        title=${3-}
        generated="${XDG_CONFIG_HOME:-$HOME/.config}/umbriel/float-rules.toml"
        current=""
        if [ -f "$generated" ]; then
          current=$(sed -n "s/^# rule$tab//p" "$generated")
        fi
        # One rule per app id, carrying every title floated under it: a window of an app that
        # already has a rule joins its title to that rule rather than opening a second one.
        kept=$(printf '%s\n' "$current" | jq -Rn -r --arg appid "$appid" --arg title "$title" '
          [inputs | select(length > 0) | split("\t") | {appid: .[0], titles: .[1:]}] as $rules
          | ([$rules | to_entries[] | select(.value.appid == $appid) | .key] | first) as $hit
          | (if $hit == null then $rules + [{appid: $appid, titles: [$title]}]
             else [$rules | to_entries[]
                   | if .key == $hit
                     then (.value | .titles = (if (.titles | index($title)) then .titles - [$title] else .titles + [$title] end))
                     else .value end]
             end)
          | map(select(.titles | length > 0))
          | .[] | ([.appid] + .titles) | join("\t")')
        {
          printf '# Generated by wminfo float-rule; umbriel reads it as an optional include.\n'
          printf '# Every block is one rule, and the comment above it holds the literals it was built from.\n'
          # Escape each literal into a regex first, then into a TOML basic string, so it survives both.
          printf '%s\n' "$kept" | jq -Rn -r '
            def rx: gsub("(?<c>[.^$*+?()\\[\\]{}|\\\\])"; "\\" + .c);
            def toml: gsub("\\\\"; "\\\\") | gsub("\""; "\\\"");
            inputs | select(length > 0) | split("\t") | . as $row
            | ($row[0]) as $appid | ($row[1:]) as $titles
            | "\n# rule\t" + ($row | join("\t")) + "\n[[window_rule]]"
              + (if $appid == "" then "" else "\nmatch.app_id = \"^" + ($appid | rx | toml) + "$\"" end)
              + "\nmatch.title = \"^"
              + (if ($titles | length) > 1
                 then "(" + ([$titles[] | rx | toml] | join("|")) + ")"
                 else ($titles[0] | rx | toml) end)
              + "$\"\ndefault_floating = true"'
        } > "$generated.new"
        mv "$generated.new" "$generated"
        # A written include is not a loaded one: umbriel picks the file up on reload, not on the write.
        umbriel msg config-reload > /dev/null
        # default_floating only lands at open time, so the window the rule was read off stays as it was.
        focused=$(umbriel windows --json | jq -c 'map(select(.active)) | (.[0] // {})')
        covered=$(printf '%s\n' "$kept" | jq -Rn -r --argjson window "$focused" '
          [inputs | select(length > 0) | split("\t")
           | select((.[0] == "" or .[0] == ($window.app_id // ""))
                    and (.[1:] | index($window.title // "")))] | length > 0 | tostring')
        if [ "$(printf '%s' "$focused" | jq -r --arg a "$appid" --arg t "$title" '((.app_id // "") == $a) and ((.title // "") == $t)')" = "true" ] \
          && [ "$(printf '%s' "$focused" | jq -r '.floating')" != "$covered" ]; then
          umbriel msg window-toggle-floating > /dev/null
        fi ;;
    esac ;;
esac
