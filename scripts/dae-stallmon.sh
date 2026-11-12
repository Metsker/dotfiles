# Per-second packet counters for the tunnel to the dae node plus a 5 s latency probe, for diagnosing stalls.
node_host=${DAE_STALLMON_NODE:-metsker.dev}
dir=${LOGS_DIRECTORY:-/var/log/dae-stallmon}
table=dae_stallmon

node_ip=$(getent ahostsv4 "$node_host" | awk 'NR == 1 { print $1 }')
if [ -z "$node_ip" ]; then
	echo "cannot resolve $node_host" >&2
	exit 1
fi
wan=$(ip -4 route get "$node_ip" | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

log() { echo "$(date -u +%FT%T) $*" >>"$dir/$(date -u +%F).log"; }

setup() {
	nft -f - <<EOF
table inet $table
delete table inet $table
table inet $table {
	counter to_node {}
	counter from_node {}
	chain out {
		type filter hook output priority -300; policy accept;
		ip daddr $node_ip ip protocol udp counter name "to_node"
	}
	chain in {
		type filter hook input priority -300; policy accept;
		ip saddr $node_ip ip protocol udp counter name "from_node"
	}
}
EOF
	log "start node=$node_ip wan=$wan"
}

counter() { nft list counter inet "$table" "$1" 2>/dev/null | awk '/packets/ { print $2, $4 }'; }
wanstat() { awk -v d="$wan:" '$1 == d { print $3, $11 }' /proc/net/dev; }
ports() { ss -Huan dst "$node_ip" | awk '{ n = split($5, a, ":"); print a[n] }' | sort -u | paste -sd, -; }

probe() {
	local last_dump=0 t d now
	while true; do
		t=$(curl -sS -m 10 -o /dev/null -w '%{time_total}' https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null) || t=fail
		d=$(curl -sS -m 10 -o /dev/null -w '%{time_total}' https://ya.ru 2>/dev/null) || d=fail
		log "probe tunnel=$t direct=$d"
		now=$(date +%s)
		# A slow tunnel probe also saves where dae is blocked, at most once a minute.
		if { [ "$t" = fail ] || awk -v t="$t" 'BEGIN { exit !(t > 3) }'; } && [ $((now - last_dump)) -ge 60 ]; then
			curl -sS -m 5 -o "$dir/pprof-$(date -u +%FT%H%M%S).txt" 'http://127.0.0.1:6060/debug/pprof/goroutine?debug=1' 2>/dev/null || true
			last_dump=$now
		fi
		sleep 5
	done
}

mkdir -p "$dir"
setup
probe &

prev_to=$(counter to_node || true)
prev_from=$(counter from_node || true)
prev_wan=$(wanstat)
n=0
while sleep 1; do
	cur_to=$(counter to_node || true)
	cur_from=$(counter from_node || true)
	# A firewall reload flushes the ruleset, taking these counters with it.
	if [ -z "$cur_to" ] || [ -z "$cur_from" ]; then
		log "counters missing, recreating"
		setup
		prev_to=$(counter to_node || true)
		prev_from=$(counter from_node || true)
		continue
	fi
	cur_wan=$(wanstat)
	read -r tp tb <<<"$cur_to"
	read -r ptp ptb <<<"$prev_to"
	read -r fp fb <<<"$cur_from"
	read -r pfp pfb <<<"$prev_from"
	read -r wr wt <<<"$cur_wan"
	read -r pwr pwt <<<"$prev_wan"
	log "to=$((tp - ptp))p/$((tb - ptb))B from=$((fp - pfp))p/$((fb - pfb))B wan_rx=$((wr - pwr))p wan_tx=$((wt - pwt))p ports=$(ports)"
	prev_to=$cur_to
	prev_from=$cur_from
	prev_wan=$cur_wan
	n=$((n + 1))
	if [ $((n % 3600)) -eq 0 ]; then
		find "$dir" -type f -mtime +7 -delete
	fi
done
