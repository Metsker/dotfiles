# Dolphin service menu: report the pixel dimensions of the selected images.
# Dolphin itself only ever reads dimensions back out of baloo's index, so with no
# indexer running this is the way to get them without one.

lines=""
for file in "$@"; do
  # The [0] frame selector keeps animations and multi-page files to a single line.
  size="$(identify -format '%wx%h' "${file}[0]" 2>/dev/null || true)"
  [ -n "$size" ] || size="not an image"
  lines="$lines$(basename "$file"): $size"$'\n'
done

notify-send --app-name=Dolphin --icon=image-x-generic "Image size" "${lines%$'\n'}"
