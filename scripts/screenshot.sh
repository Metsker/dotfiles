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

wayfreeze --hide-cursor --after-freeze-cmd \
  "geometry=\$(slurp -o < '$boxes') && grim -g \"\$geometry\" '$tmp'; kill \$PPID" || true

[ -s "$tmp" ] || exit 0

satty \
  --filename "$tmp" \
  --output-filename "$outfile" \
  --early-exit \
  --copy-command 'wl-copy --type image/png' \
  --save-after-copy
