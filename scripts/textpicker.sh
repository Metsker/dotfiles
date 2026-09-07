tmp="$(mktemp --suffix=.png)"
full="$(mktemp --suffix=.ppm)"
geo="$(mktemp)"
cleanup() {
  rm -f "$tmp" "$full" "$geo"
  return 0
}
trap cleanup EXIT

# Same order as screenshot.sh: grab while the pointer is still parked or hidden, freeze afterwards.
# An arrow sitting on the text is one more thing for tesseract to misread.
pos="$(wminfo cursorpos)"
if [ -n "$pos" ]; then
  wlrctl pointer move 20000 20000
  sleep 0.1
  grim -t ppm "$full"
  wlrctl pointer move -20000 -20000
  wlrctl pointer move "${pos% *}" "${pos#* }"
else
  grim -t ppm "$full"
fi

# The freeze keeps content still while the region is drawn.
wayfreeze --hide-cursor --after-freeze-cmd "slurp > '$geo'; kill \$PPID" || true

read -r geometry < "$geo" || exit 0

# ponytail: same 0,0 layout-origin assumption as screenshot.sh.
offset="${geometry%% *}"
magick "$full" -crop "${geometry#* }+${offset%,*}+${offset#*,}" +repage "$tmp"

[ -s "$tmp" ] || exit 0

text="$(tesseract "$tmp" stdout --oem 1 --psm 6 -l "${OCR_LANGS:-eng}" --dpi 300 -c preserve_interword_spaces=1 2>/dev/null)"

[ -n "$text" ] || exit 1

printf '%s' "$text" | wl-copy
notify-send "󰴑    Copied text from selection to clipboard"
