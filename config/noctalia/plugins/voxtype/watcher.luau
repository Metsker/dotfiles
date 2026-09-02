--!nonstrict
-- Headless service: one voxtype status stream for the whole shell, republished
-- through plugin state so every bar's indicator reads the same value.

-- The stream carries every transition, so the tick only exists to notice that the
-- stream itself died, which a voxtype daemon restart is enough to do.
local RESYNC_INTERVAL = 15000
local last = nil

-- An unrecognizable payload reads as idle, which hides the indicator rather than
-- freezing it on whatever state it happened to be showing.
local function publish(data)
	local payload = { class = "idle" }
	if type(data) == "table" and data.class then
		payload = { class = data.class, tooltip = data.tooltip }
	end
	local encoded = noctalia.json.encode(payload)
	if encoded ~= last then
		last = encoded
		noctalia.state.set("status", payload)
	end
end

-- json.decode reports a bad payload as (nil, err) rather than raising, so a
-- truncated line arrives at publish as nil and needs no guard of its own.
local function accept(line)
	publish(noctalia.json.decode(line))
end

-- runStream never restarts a dead stream and gives the script no way to notice
-- one, so the loop restarts voxtype itself; the guard ends the loop once the
-- shell holding the other end of the pipe is gone.
noctalia.runStream(
	'while kill -0 "$PPID" 2>/dev/null; do voxtype status --follow --format json; sleep 2; done',
	accept
)

function update()
	noctalia.setUpdateInterval(RESYNC_INTERVAL)
	noctalia.runAsync("voxtype status --format json", function(result)
		-- Only a successful query is worth believing; a failed one would otherwise
		-- read as idle and hide an indicator that should be up.
		if result.exitCode == 0 then
			publish(noctalia.json.decode(result.stdout))
		end
	end)
end
