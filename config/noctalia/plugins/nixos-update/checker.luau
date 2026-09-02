--!nonstrict
-- Headless service: compares the revision the flake pins for an input against the
-- head of a NixOS channel, and publishes the verdict to plugin state.

local CHANNELS = "https://channels.nixos.org/"
local last = nil

local function intervalMs()
	return (noctalia.getConfig("check_interval_minutes") or 60) * 60000
end

local function publish(payload)
	local encoded = noctalia.json.encode(payload)
	if encoded ~= last then
		last = encoded
		noctalia.state.set("update", payload)
	end
end

-- The root node's inputs map a name to the node holding that input's lock; an
-- input that only follows another maps to a path array, which owns no revision.
local function pinned()
	local raw = noctalia.readFile(noctalia.getConfig("flake_lock"))
	local lock = raw and noctalia.json.decode(raw)
	local nodes = lock and lock.nodes
	local root = nodes and lock.root and nodes[lock.root]
	local name = root and root.inputs and root.inputs[noctalia.getConfig("input")]
	local node = type(name) == "string" and nodes[name] or nil
	return node and node.locked or nil
end

local function check()
	local locked = pinned()
	if not (locked and locked.rev) then
		publish({ ok = false })
		return
	end
	local channel = noctalia.getConfig("channel")
	noctalia.http({
		url = CHANNELS .. channel .. "/git-revision",
		follow_redirects = true,
	}, function(response)
		-- ok reports the transport only, so a 404 from a misspelled channel still
		-- arrives here as a success and has to be rejected on the status.
		if not response.ok or response.status ~= 200 then
			publish({ ok = false })
			return
		end
		local head = noctalia.string.trim(response.body)
		publish({
			ok = true,
			behind = head ~= locked.rev,
			channel = channel,
			pinned = locked.rev,
			head = head,
			lastModified = locked.lastModified,
		})
	end)
end

function update()
	noctalia.setUpdateInterval(intervalMs())
	check()
end

-- Without this the host restarts the runtime on every settings edit; re-checking
-- in place is what makes a changed channel show up without waiting out a tick.
function onConfigChanged()
	noctalia.setUpdateInterval(intervalMs())
	check()
end
