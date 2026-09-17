--!nonstrict
-- Headless service: owns the tunnel's state and the one command that changes it,
-- so the bar widget and the control-center tile cannot disagree about either.

-- Nothing pushes an interface change, so the state is polled; the read is one stat
-- of a sysfs path, which is cheap enough to do this often.
local POLL_INTERVAL = 3000
-- runAsync's own ceiling, and a password dialog is what the wait is spent on.
local COMMAND_TIMEOUT = 60000
-- pkexec's exit code for a dismissed or refused dialog, which is an answer rather
-- than a failure and must not raise a notification.
local NOT_AUTHORIZED = 126

local busy = false
local last = nil

-- Read per call rather than once: onConfigChanged keeps the runtime alive across a
-- settings edit, so a value cached at load would outlive the setting it came from.
local function iface()
	return noctalia.getConfig("interface")
end

-- The link exists exactly while the tunnel is up, so this is the state itself and
-- not a cache of one: a tunnel raised by a systemd unit at boot, or by AmneziaVPN's
-- own GUI, is seen here without anything having announced it.
local function isUp()
	return noctalia.fileExists("/sys/class/net/" .. iface())
end

local function publish()
	local payload = { up = isUp(), busy = busy, interface = iface() }
	local encoded = noctalia.json.encode(payload)
	if encoded ~= last then
		last = encoded
		noctalia.state.set("tunnel", payload)
	end
end

-- awg-quick reports the step it died on across several lines; the last one is the
-- error itself, and a notification has room for that and not for the rest.
local function lastLine(text)
	local found = ""
	for line in string.gmatch(text, "[^\n]+") do
		local trimmed = noctalia.string.trim(line)
		if trimmed ~= "" then
			found = trimmed
		end
	end
	return found
end

local function toggle()
	-- A second request while the dialog is open would stack another dialog behind it.
	if busy then
		return
	end
	local raising = not isUp()
	busy = true
	publish()
	-- An argv table rather than a command line: the interface, the conf path and the
	-- PATH are all settings, so none of them may reach a shell as text. env rather
	-- than awg-quick directly, because pkexec replaces the inherited PATH with the
	-- FHS bin directories, which hold nothing on NixOS, and awg-quick calls awg by
	-- bare name.
	local argv = {
		"pkexec",
		"/usr/bin/env",
		"PATH=" .. noctalia.getConfig("path"),
		"awg-quick",
		raising and "up" or "down",
		noctalia.getConfig("config_file"),
	}
	noctalia.runAsync(argv, function(result)
		busy = false
		publish()
		if result.exitCode == 0 or result.exitCode == NOT_AUTHORIZED then
			return
		end
		local key = raising and "notify.up_failed" or "notify.down_failed"
		noctalia.notifyError(noctalia.tr(key, { interface = iface() }), lastLine(result.stderr))
	end, COMMAND_TIMEOUT)
end

-- The surfaces ask for a toggle rather than for a direction, so a tile drawn from a
-- stale publish cannot ask for the state the tunnel is already in.
noctalia.state.watch("command", function(value)
	if type(value) == "table" and value.action == "toggle" then
		toggle()
	end
end)

function update()
	noctalia.setUpdateInterval(POLL_INTERVAL)
	publish()
end

-- Without this the host restarts the runtime on every settings edit; republishing in
-- place is what makes a changed interface name show up without waiting out a tick.
function onConfigChanged()
	last = nil
	publish()
end

-- `noctalia msg plugin metsker/vpn:watcher all toggle` drives the toggle with no
-- widget placed and no tile added, which is the only way to reach it from a terminal.
function onIpc(event)
	if event == "toggle" then
		toggle()
	end
end
