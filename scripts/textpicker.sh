tmp="$(mktemp --suffix=.png)"
cleanup() {
  rm -f "$tmp"
  return 0
}
trap cleanup EXIT

# Same software-cursor workaround as screenshot.sh: park the pointer out of the shot so
# the arrow does not sit on top of the text tesseract has to read.
pos="$(mmsg get cursorpos | jq -r '"\(.x|floor) \(.y|floor)"' 2>/dev/null || true)"
park='wlrctl pointer move 20000 20000'
unpark="wlrctl pointer move -20000 -20000; wlrctl pointer move $pos"

eval "$park"
sleep 0.1

# Freeze first so the OCR captures a still frame, not content shifting under the selection.
wayfreeze --hide-cursor --before-freeze-cmd "$unpark" --after-freeze-cmd \
  "geometry=\$(slurp) && $park && sleep 0.1 \
   && grim -g \"\$geometry\" '$tmp'; $unpark; kill \$PPID" || true

[ -s "$tmp" ] || exit 0

text="$(tesseract "$tmp" stdout --oem 1 --psm 6 -l "${OCR_LANGS:-eng}" --dpi 300 -c preserve_interword_spaces=1 2>/dev/null)"

[ -n "$text" ] || exit 1

printf '%s' "$text" | wl-copy
notify-send "󰴑    Copied text from selection to clipboard"
