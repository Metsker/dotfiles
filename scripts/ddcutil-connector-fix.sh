# ddcutil pairs an i2c bus with a DRM connector by comparing the EDID the monitor answers
# with over i2c against the connector's EDID in sysfs, byte for byte. NVIDIA rewrites the
# product code in the copy it publishes for DisplayPort, so a DP monitor leaves `detect`
# with no connector line and noctalia's brightness service drops it.
# ponytail: when exactly one detected display and one connected output are left unpaired the
# pairing is forced, so fill it in. Drop once ddcutil stops demanding an exact byte match.

is_detect=false
for arg in "$@"; do
  if [ "$arg" = detect ]; then
    is_detect=true
  fi
done

if [ "$is_detect" = false ]; then
  exec "$DDCUTIL_REAL" "$@"
fi

status=0
out=$("$DDCUTIL_REAL" "$@") || status=$?

# Connectors ddcutil resolved on its own.
mapfile -t matched < <(grep -oE 'DRM[ _]connector: *card[^ ]+' <<<"$out" | awk '{ print $NF }')

# Outputs with a monitor on them, minus the ones already paired.
orphan_connectors=()
for path in /sys/class/drm/card*-*/status; do
  if [ "$(cat "$path")" != connected ]; then
    continue
  fi
  dir=${path%/status}
  connector=${dir##*/}
  for m in "${matched[@]}"; do
    if [ "$connector" = "$m" ]; then
      continue 2
    fi
  done
  orphan_connectors+=("$connector")
done

orphan_displays=$(awk 'BEGIN { RS = "" } /\/dev\/i2c-/ && !/DRM[ _]connector:/ { n++ } END { print n + 0 }' <<<"$out")

if [ "${#orphan_connectors[@]}" -ne 1 ] || [ "$orphan_displays" -ne 1 ]; then
  printf '%s\n' "$out"
  exit "$status"
fi

# `detect --brief` spells the label with a space, plain `detect` with an underscore.
label='DRM_connector:           '
if grep -q 'DRM connector:' <<<"$out"; then
  label='DRM connector:    '
fi

awk -v conn="${orphan_connectors[0]}" -v label="$label" '
  BEGIN { RS = ""; ORS = "\n\n" }
  /\/dev\/i2c-/ && !/DRM[ _]connector:/ {
    sub(/\/dev\/i2c-[0-9]+/, "&\n   " label conn)
  }
  { print }
' <<<"$out"

exit "$status"
