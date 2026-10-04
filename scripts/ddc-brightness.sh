# Some scalers forget DDC brightness on power loss (the RTK on HDMI-A-3 boots at 30%), so the session carries it over.
state=${XDG_STATE_HOME:-$HOME/.local/state}/ddc-brightness

# One "<bus> <connector>" line per DDC monitor; the bus number can move between boots, the connector cannot.
displays() {
  ddcutil detect --brief | awk '
    /I2C bus:/ { bus = $NF; sub(/.*i2c-/, "", bus) }
    /DRM[ _]connector:/ { conn = $NF; sub(/^card[0-9]+-/, "", conn); print bus, conn }
  '
}

declare -A saved=()
if [ -f "$state" ]; then
  while read -r conn value; do
    saved[$conn]=$value
  done <"$state"
fi

case ${1-} in
  save)
    # A monitor that does not answer keeps its last saved value.
    while read -r bus conn; do
      value=$(ddcutil --bus "$bus" getvcp 10 --brief | awk '{ print $4 }') || continue
      if [[ $value =~ ^[0-9]+$ ]]; then
        saved[$conn]=$value
      fi
    done < <(displays)

    mkdir -p "$(dirname "$state")"
    tmp=$(mktemp "$state.XXXXXX")
    for conn in "${!saved[@]}"; do
      printf '%s %s\n' "$conn" "${saved[$conn]}"
    done >"$tmp"
    mv "$tmp" "$state"
    ;;
  restore)
    while read -r bus conn; do
      if [ -n "${saved[$conn]-}" ]; then
        ddcutil --bus "$bus" setvcp 10 "${saved[$conn]}" &
      fi
    done < <(displays)
    wait
    ;;
  *)
    echo "usage: ddc-brightness save|restore" >&2
    exit 2
    ;;
esac
