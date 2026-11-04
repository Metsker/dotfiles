--!nonstrict
-- Headless service: owns whether the keyboard is up and the one command that
-- changes it, so the tile only ever draws what this publishes.

-- Nothing announces the keyboard exiting, so it is polled; the read is one small
-- /proc file, and only while a keyboard this service started is believed alive.
local POLL_INTERVAL = 2000
local LAUNCH_TIMEOUT = 5000
-- Between the fork and the exec the child is still sh, so a poll landing in that
-- gap must not read it as a keyboard that already exited.
local EXEC_GRACE = 1000

local busy = false
local pid = nil
local launchedAt = 0
local last = nil

-- Read per call rather than once: onConfigChanged keeps the runtime alive across a
-- settings edit, so a value cached at load would outlive the setting it came from.
local function program()
	return noctalia.string.trim(noctalia.getConfig("program"))
end

-- The kernel keeps a process name as the basename cut to 15 bytes, so that is
-- what /proc/<pid>/comm is compared against.
local function processName()
	local base = string.match(program(), "[^/]+$") or ""
	return string.sub(base, 1, 15)
end

-- Persisted so a noctalia restart still knows which process to close, rather than
-- showing the tile off over a keyboard that is still on screen.
local function pidFile()
	local dir = noctalia.pluginDataDir()
	return dir and (dir .. "/pid") or nil
end

local function remember(value)
	pid = value
	local file = pidFile()
	if file == nil then
		return
	end
	if value then
		noctalia.writeFile(file, value)
	else
		noctalia.removeFile(file)
	end
end

-- The name check is what tells the keyboard from an unrelated process that has
-- since been given a recycled pid.
local function alive()
	if pid == nil then
		return false
	end
	local comm = noctalia.readFile("/proc/" .. pid .. "/comm")
	if comm == nil then
		return false
	end
	if noctalia.string.trim(comm) == processName() then
		return true
	end
	return noctalia.nowMs() - launchedAt < EXEC_GRACE
end

local function publish()
	local payload = { running = alive(), busy = busy }
	local encoded = noctalia.json.encode(payload)
	if encoded ~= last then
		last = encoded
		noctalia.state.set("keyboard", payload)
	end
end

local function launch()
	local prog = program()
	if not noctalia.commandExists(prog) then
		noctalia.notifyError(noctalia.tr("notify.missing", { program = prog }), "")
		return
	end
	busy = true
	publish()
	-- A shell string so the arguments setting can quote a value with spaces; the
	-- shell backgrounds the keyboard and exits at once, handing back its pid.
	local script = prog .. " " .. noctalia.getConfig("arguments") .. " </dev/null >/dev/null 2>&1 & echo $!"
	noctalia.runAsync(script, function(result)
		busy = false
		local found = string.match(result.stdout or "", "(%d+)%s*$")
		if found then
			launchedAt = noctalia.nowMs()
			remember(found)
		end
		publish()
	end, LAUNCH_TIMEOUT)
end

local function toggle()
	-- A second click while the launch is resolving would start a second keyboard.
	if busy then
		return
	end
	if alive() then
		-- By pid rather than by name, so only the keyboard this service started is closed.
		noctalia.runAsync({ "kill", pid })
		remember(nil)
		publish()
	else
		launch()
	end
end

-- The tile asks for a toggle rather than for a direction, so one drawn from a
-- stale publish cannot ask for the state the keyboard is already in.
noctalia.state.watch("command", function(value)
	if type(value) == "table" and value.action == "toggle" then
		toggle()
	end
end)

function update()
	noctalia.setUpdateInterval(POLL_INTERVAL)
	if pid ~= nil and not busy and not alive() then
		remember(nil)
	end
	publish()
end

function onConfigChanged()
	last = nil
	publish()
end

-- `noctalia msg plugin metsker/osk:watcher all toggle` drives the toggle with no
-- tile added, which is the only way to reach it from a terminal.
function onIpc(event)
	if event == "toggle" then
		toggle()
	end
end

local file = pidFile()
local saved = file and noctalia.readFile(file)
if saved then
	pid = noctalia.string.trim(saved)
	if not alive() then
		remember(nil)
	end
end
publish()
