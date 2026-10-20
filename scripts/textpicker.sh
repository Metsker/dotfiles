tmp="$(mktemp --suffix=.png)"
full="$(mktemp --suffix=.ppm)"
geo="$(mktemp)"
cleanup() {
  rm -f "$tmp" "$full" "$geo"
  return 0
}
trap cleanup EXIT

# Same order as screenshot.sh: grab while the pointer is still hidden, freeze afterwards.
# An arrow sitting on the text is one more thing for tesseract to misread.
grim -t ppm "$full"

# The freeze keeps content still while the region is drawn.
wayfreeze --hide-cursor --after-freeze-cmd "slurp > '$geo'; kill \$PPID" || true

read -r geometry < "$geo" || exit 0

# Same logical-to-pixel mapping as screenshot.sh.
crop="$(wlr-randr --json | jq -r --arg g "$geometry" '
  map(select(.enabled)) as $o | ($o | map(.scale) | max) as $s
  | ($g | [scan("-?[0-9]+") | tonumber]) as [$x, $y, $w, $h]
  | [$x - ($o | map(.position.x) | min), $y - ($o | map(.position.y) | min)] as [$l, $t]
  | [$l, $t, $l + $w, $t + $h] | map(. * $s | round) as [$x0, $y0, $x1, $y1]
  | "\($x1 - $x0)x\($y1 - $y0)+\($x0)+\($y0)"')"
magick "$full" -crop "$crop" +repage "$tmp"

[ -s "$tmp" ] || exit 0

text="$(tesseract "$tmp" stdout --oem 1 --psm 6 -l "${OCR_LANGS:-eng}" --dpi 300 -c preserve_interword_spaces=1 2>/dev/null)"

[ -n "$text" ] || exit 1

printf '%s' "$text" | wl-copy
notify-send "󰴑    Copied text from selection to clipboard"
