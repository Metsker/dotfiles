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
# carries it; umbriel hides it on the keypress that spawned the script (input.cursor.hide_when_typing).
# That does not survive the pointer moving to select, so wayfreeze is only the still backdrop and
# the saved pixels come from here, cropped. ppm skips the png encode, which keeps the grab near 70ms.
grim -t ppm "$full"

wayfreeze --hide-cursor --after-freeze-cmd "slurp -o < '$boxes' > '$geo'; kill \$PPID" || true

read -r geometry < "$geo" || exit 0

# slurp speaks logical coordinates; grim's grab is pixels at the largest output scale from the layout's corner.
crop="$(wlr-randr --json | jq -r --arg g "$geometry" '
  map(select(.enabled)) as $o | ($o | map(.scale) | max) as $s
  | ($g | [scan("-?[0-9]+") | tonumber]) as [$x, $y, $w, $h]
  | [$x - ($o | map(.position.x) | min), $y - ($o | map(.position.y) | min)] as [$l, $t]
  | [$l, $t, $l + $w, $t + $h] | map(. * $s | round) as [$x0, $y0, $x1, $y1]
  | "\($x1 - $x0)x\($y1 - $y0)+\($x0)+\($y0)"')"
magick "$full" -crop "$crop" +repage "$tmp"

[ -s "$tmp" ] || exit 0

wl-copy --type image/png < "$tmp"

# noctalia advertises the "actions" capability, so notify-send blocks and prints the clicked action's key.
action="$(notify-send -a screenshot -i "$tmp" -t 10000 \
  "Screenshot copied to clipboard" "Edit to annotate, or save it as is" -A "edit=Edit" -A "save=Save")"

# Capture lives only in $tmp; $outfile is written only by Save or by satty's save / save-as.
case "$action" in
  save)
    cp "$tmp" "$outfile"
    notify-send -a screenshot -i "$outfile" "Screenshot saved" "$outfile"
    ;;
  edit)
    satty \
      --filename "$tmp" \
      --output-filename "$outfile" \
      --early-exit \
      --copy-command 'wl-copy --type image/png'
    ;;
esac
