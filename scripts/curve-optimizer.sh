# Sets each core's Curve Optimizer offset at runtime, one argument per core in core order,
# through ryzen_smu's MP1 mailbox, and reads every value back. Zen 3 (Vermeer) message IDs as
# ZenStates-Core lists them: 0x35 sets one core's margin, 0x48 reads it.
smu=/sys/kernel/ryzen_smu_drv

for _ in $(seq 50); do
  [ -e "$smu/version" ] && break
  sleep 0.1
done

le32() {
  printf '\\x%02x\\x%02x\\x%02x\\x%02x' $(($1 & 255)) $(($1 >> 8 & 255)) $(($1 >> 16 & 255)) $(($1 >> 24 & 255))
}

# The driver takes each file in a single write of its exact size, hence dd.
send() {
  { printf '%b' "$(le32 "$2")"; head -c 20 /dev/zero; } | dd of="$smu/smu_args" bs=24 count=1 iflag=fullblock status=none
  printf '%b' "$(le32 "$1")" | dd of="$smu/mp1_smu_cmd" bs=4 count=1 iflag=fullblock status=none
  status=$(od -An -tu4 -N4 "$smu/mp1_smu_cmd" | tr -d ' ')
  if [ "$status" != 1 ]; then
    echo "SMU message $1 failed with status $status" >&2
    exit 1
  fi
  od -An -tu4 -N4 "$smu/smu_args" | tr -d ' '
}

core=0
for value in "$@"; do
  if ((value < -30 || value > 30)); then
    echo "core $core: CO $value is outside -30..30" >&2
    exit 1
  fi
  mask=$((((core & 8) << 5 | (core & 7)) << 20))
  send 0x35 $((mask | (value & 0xFFFF))) >/dev/null
  got=$(send 0x48 "$mask")
  if ((got >= 1 << 31)); then
    got=$((got - (1 << 32)))
  elif ((got >= 0x8000 && got <= 0xFFFF)); then
    got=$((got - 0x10000))
  fi
  if [ "$got" != "$value" ]; then
    echo "core $core: set CO $value, read back $got" >&2
    exit 1
  fi
  echo "core $core: CO $value"
  core=$((core + 1))
done
