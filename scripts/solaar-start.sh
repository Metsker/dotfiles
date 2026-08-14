# Start Solaar only once the mouse is bound to logitech-hidpp-device; if Solaar is already running when
# that bind happens its listener thread dies mid apply_all_settings and no saved setting is pushed.
bound() {
  set -- /sys/bus/hid/drivers/logitech-hidpp-device/*/hidraw/hidraw*
  [ -e "$1" ]
}

# ponytail: give up after 2 min so the headset is still managed when the mouse stays off; a mouse that
# connects later in the session still hits the upstream crash, fix that by patching Solaar if it bites.
n=0
while [ "$n" -lt 60 ] && ! bound; do
  n=$((n + 1))
  sleep 2
done

exec solaar --window=hide
