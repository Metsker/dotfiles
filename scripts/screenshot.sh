save_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$save_dir"
outfile="$save_dir/$(date +%Y-%m-%d_%H-%M-%S).png"

tmp="$(mktemp --suffix=.png)"
boxes="$(mktemp)"
cleanup() {
  rm -f "$tmp" "$boxes"
  return 0
}
trap cleanup EXIT

mmsg get all-clients 2>/dev/null \
  | jq -r '.clients[]
           | select(.is_visible and (.is_minimized | not))
           | "\(.x),\(.y) \(.width)x\(.height) \(.appid)"' 2>/dev/null > "$boxes" || true

# Workaround: wlroots falls back to a software cursor on the NVIDIA blob and bakes it
# into the framebuffer, and screencopy's overlay_cursor can only add a cursor, never
# remove one - so grim -c and wayfreeze --hide-cursor are both no-ops here. Park the
# pointer bottom-right instead, where the arrow renders off-screen. Two captures need
# it: wayfreeze's still frame, and grim's shot of the live pointer over that frame.
# Proper fix would be a compositor-side screenshot rendered from the scene graph.
pos="$(mmsg get cursorpos | jq -r '"\(.x|floor) \(.y|floor)"' 2>/dev/null || true)"
park='wlrctl pointer move 20000 20000'
unpark="wlrctl pointer move -20000 -20000; wlrctl pointer move $pos"

# wayfreeze runs --before-freeze-cmd after it has grabbed the frame, so park out here
# and let that hook put the pointer back before the frozen overlay is shown.
eval "$park"
sleep 0.1

wayfreeze --hide-cursor --before-freeze-cmd "$unpark" --after-freeze-cmd \
  "geometry=\$(slurp -o < '$boxes') && $park && sleep 0.1 \
   && grim -g \"\$geometry\" '$tmp'; $unpark; kill \$PPID" || true

[ -s "$tmp" ] || exit 0

wl-copy --type image/png < "$tmp"

# noctalia advertises the "actions" capability, so notify-send blocks and prints
# the action key when the Edit button is clicked; only then do we open satty.
action="$(notify-send -a screenshot -i "$tmp" -t 10000 \
  "Screenshot copied to clipboard" "Click Edit to annotate / save" -A "edit=Edit")"

# Capture lives only in $tmp; satty writes $outfile solely via its save / save-as.
[ "$action" = "edit" ] && satty \
  --filename "$tmp" \
  --output-filename "$outfile" \
  --early-exit \
  --copy-command 'wl-copy --type image/png'
