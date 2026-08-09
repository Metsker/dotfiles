# Apply an OpenRGB profile; the SDK server needs ~20s of detection at boot, before that it no-ops.
profile=${1:?usage: openrgb-profile <name>}

# ponytail: "^2:" is the last device index the profile touches, bump it if the hardware changes.
n=0
while [ "$n" -lt 30 ] && ! openrgb --client 127.0.0.1 -l | grep -q '^2:'; do
  n=$((n + 1))
  sleep 2
done

exec openrgb --startminimized --profile "$profile"
