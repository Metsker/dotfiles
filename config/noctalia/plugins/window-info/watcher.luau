--!nonstrict
-- Headless service: one focus stream for the whole shell, republished through plugin state,
-- so every bar's widget draws the same window without a stream or a lookup of its own.

-- The stream carries every focus change, so the tick exists to notice that the stream itself
-- died, which a compositor restart is enough to do, and to re-read the float rules, which
-- nothing announces.
local RESYNC_INTERVAL = 15000

local client = nil
-- The compositor's own float rules as wminfo reports them: one rule per app id, carrying every
-- title floated under it. An empty app id is the rule for windows that set none.
local rules = {}
-- appIconPath scans the filesystem on a miss and the host caches nothing, so resolving per focus
-- change is what blew the widget's CPU budget until the shell disabled it. One lookup per app id,
-- misses included: false is the answer "no desktop entry and no themed icon".
local icons = {}
local last = nil
local watching = false
local writing = false

-- A rule names both the app id and the title, so it floats the window it was read off and no
-- other window of that app.
local function ruled(appid, title)
	for _, rule in ipairs(rules) do
		if rule.appid == appid then
			for _, listed in ipairs(rule.titles) do
				if listed == title then
					return true
				end
			end
		end
	end
	return false
end

local function icon(appid)
	if appid == "" then
		return nil
	end
	if icons[appid] == nil then
		icons[appid] = noctalia.appIconPath(appid) or false
	end
	return icons[appid] or nil
end

-- Everything the widget draws, resolved once here rather than once per bar: an empty desktop
-- publishes focused = false, which is what hides the widget.
local function publish()
	local payload = { focused = false }
	if client then
		local appid, title = client.appid or "", client.title or ""
		payload = {
			focused = true,
			title = title,
			appid = appid,
			icon = icon(appid),
			floating = ruled(appid, title),
		}
	end
	local encoded = noctalia.json.encode(payload)
	if encoded ~= last then
		last = encoded
		noctalia.state.set("window", payload)
	end
end

-- Cheap enough to re-read on the tick: it is one file the compositor's config dir already carries.
local function refreshRules(done)
	noctalia.runAsync("wminfo float-rules", function(result)
		if result.exitCode ~= 0 then
			return
		end
		local found = {}
		for line in string.gmatch(result.stdout, "[^\n]+") do
			local appid, rest = string.match(line, "^([^\t]*)\t(.*)$")
			if appid then
				local titles = {}
				-- A trailing empty field is a real title, so walk the separators rather than
				-- matching non-empty runs the way gmatch on "[^\t]+" would.
				for at in string.gmatch(rest .. "\t", "(.-)\t") do
					table.insert(titles, at)
				end
				table.insert(found, { appid = appid, titles = titles })
			end
		end
		rules = found
		publish()
		if done then
			done()
		end
	end)
end

-- The rule names the app id and the title together, whichever of the two the bar happens to be
-- showing, so it floats this window rather than everything sharing one of its two names. An argv
-- table rather than a command line, because a title is arbitrary text.
local function writeRule(request)
	-- A second press while the first write is in flight would race it on the same file.
	if writing then
		return
	end
	local appid, title = request.appid or "", request.title or ""
	-- The clicked bar names the window in the notification: only it knows which of the two
	-- values it is showing.
	local label = request.label
	if not label or label == "" then
		label = title
	end
	local before = ruled(appid, title)
	writing = true
	noctalia.runAsync({ "wminfo", "float-rule", appid, title }, function(result)
		writing = false
		if result.exitCode ~= 0 then
			noctalia.notifyError(noctalia.tr("notify.rule.failed"), label)
			return
		end
		refreshRules(function()
			local after = ruled(appid, title)
			if after == before then
				-- A compositor wminfo writes no rules for answers the query with nothing at all.
				noctalia.notifyError(noctalia.tr("notify.rule.unsupported"), label)
			else
				noctalia.notify(noctalia.tr(after and "notify.rule.added" or "notify.rule.removed"), label)
			end
		end)
	end)
end

-- The bars ask for the rule rather than writing it, so one right-click writes the file once
-- however many bars carry the widget.
noctalia.state.watch("command", function(value)
	if type(value) == "table" and value.action == "float-rule" then
		writeRule(value)
	end
end)

-- json.decode reports a bad payload as (nil, err) rather than raising, so an undecodable line
-- arrives here as nil and reads as "nothing focused", which is also what wminfo's null title means.
local function accept(data)
	client = (type(data) == "table" and data.title) and data or nil
	publish()
end

-- runStream never restarts a dead stream and gives the script no way to notice one, so the loop
-- restarts wminfo itself; the guard ends the loop once the shell holding the other end of the
-- pipe is gone.
local function watch()
	noctalia.runStream(
		'while kill -0 "$PPID" 2>/dev/null; do wminfo watch-focused-window; sleep 2; done',
		function(line)
			accept(noctalia.json.decode(line))
		end
	)
end

function update()
	noctalia.setUpdateInterval(RESYNC_INTERVAL)
	refreshRules()
	noctalia.runAsync("wminfo focused-window", function(result)
		-- Only a successful query is worth believing; a failed one would otherwise read as an
		-- empty desktop and hide the widget.
		if result.exitCode ~= 0 then
			return
		end
		-- An answer at all is what says the compositor has an IPC to watch: driftwm answers
		-- nothing, and the restart loop would respawn a command that exits at once, forever.
		if noctalia.string.trim(result.stdout) == "" then
			return
		end
		accept(noctalia.json.decode(result.stdout))
		if not watching then
			watching = true
			watch()
		end
	end)
end
