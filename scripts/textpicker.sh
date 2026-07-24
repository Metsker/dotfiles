tmp="$(mktemp --suffix=.png)"
cleanup() {
  rm -f "$tmp"
  return 0
}
trap cleanup EXIT

# Freeze first so the OCR captures a still frame, not content shifting under the selection.
wayfreeze --hide-cursor --after-freeze-cmd \
  "geometry=\$(slurp) && grim -g \"\$geometry\" '$tmp'; kill \$PPID" || true

[ -s "$tmp" ] || exit 0

text="$(tesseract "$tmp" stdout --oem 1 --psm 6 -l "${OCR_LANGS:-eng}" --dpi 300 -c preserve_interword_spaces=1 2>/dev/null)"

[ -n "$text" ] || exit 1

printf '%s' "$text" | wl-copy
notify-send "󰴑    Copied text from selection to clipboard"
