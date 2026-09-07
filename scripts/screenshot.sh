save_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$save_dir"
outfile="$save_dir/$(date +%Y-%m-%d_%H-%M-%S).png"

tmp="$(mktemp --suffix=.png)"
full="$(mktemp --suffix=.ppm)"
boxes="$(mktemp)"
geo="$(mktemp)"
cleanup() {
  rm -f "$tmp" "$full" "$boxes" "$geo"
  return 0
}
trap cleanup EXIT

wminfo boxes > "$boxes"

# Take the picture now, not after the region is drawn. The NVIDIA blob leaves some outputs without a
# cursor plane, so the compositor composites the pointer into the framebuffer and every screencopy
# carries it: mango parks the pointer for this shot, umbriel hides it on the keypress that spawned
# the script (input.cursor.hide_when_typing). Neither survives the pointer moving to select, so
# wayfreeze is only the still backdrop and the saved pixels come from here, cropped. ppm skips the
# png encode, which keeps the grab near 70ms.
pos="$(wminfo cursorpos)"
if [ -n "$pos" ]; then
  # Park the pointer bottom-right, where the arrow renders off-screen, then put it back.
  wlrctl pointer move 20000 20000
  sleep 0.1
  grim -t ppm "$full"
  wlrctl pointer move -20000 -20000
  wlrctl pointer move "${pos% *}" "${pos#* }"
else
  grim -t ppm "$full"
fi

wayfreeze --hide-cursor --after-freeze-cmd "slurp -o < '$boxes' > '$geo'; kill \$PPID" || true

read -r geometry < "$geo" || exit 0

# ponytail: the crop assumes the output layout starts at 0,0, which is where grim's full-screen
# capture begins; a monitor placed left of or above the origin wants an origin query in wminfo.
offset="${geometry%% *}"
magick "$full" -crop "${geometry#* }+${offset%,*}+${offset#*,}" +repage "$tmp"

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
