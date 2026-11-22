--!nonstrict
-- Headless service: one focus stream for the whole shell, republished through plugin state,
-- so every bar's widget draws the same window without a stream or a lookup of its own.

-- The shell reconnects the window stream itself, so the tick only re-reads the float rules,
-- which nothing announces.
local RULES_INTERVAL = 15000

local client = nil
-- The compositor's own float rules as wminfo reports them: one rule per app id, carrying every
-- title floated under it. An empty app id is the rule for windows that set none.
local rules = {}
-- appIconPath scans the filesystem on a miss and the host caches nothing, so resolving per focus
-- change is what blew the widget's CPU budget until the shell disabled it. One lookup per app id,
-- misses included: false is the answer "no desktop entry and no themed icon".
local icons = {}
local last = nil
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
				-- Undo is the same toggle again, so the context carries the request unchanged.
				noctalia.notify(noctalia.tr(after and "notify.rule.added" or "notify.rule.removed"), label, {
					actions = { { id = "undo", label = noctalia.tr("notify.rule.undo") } },
					onAction = "onRuleAction",
					context = noctalia.json.encode({ appid = appid, title = title, label = label }),
				})
			end
		end)
	end)
end

function onRuleAction(id, context)
	local request = noctalia.json.decode(context)
	if id == "undo" and type(request) == "table" then
		writeRule(request)
	end
end

-- The bars ask for the rule rather than writing it, so one right-click writes the file once
-- however many bars carry the widget.
noctalia.state.watch("command", function(value)
	if type(value) == "table" and value.action == "float-rule" then
		writeRule(value)
	end
end)

-- Umbriel sends the whole window list on every change, starting with a snapshot, and exactly one
-- window is active across all outputs; per-workspace focus is `focused`, which is not this.
local function onWindows(event, data)
	if event == "windows" and type(data) == "table" then
		client = nil
		for _, window in ipairs(data) do
			if window.active then
				client = { title = window.title or "", appid = window.app_id or "" }
				break
			end
		end
		publish()
	elseif event == "reset" then
		-- A fresh snapshot follows the reconnect; dropping the window without publishing spares
		-- the bar a blink.
		client = nil
	elseif event == "error" then
		noctalia.log("window stream rejected: " .. tostring(data))
	end
end

-- The event format is umbriel's own; on any other compositor the widget stays hidden.
if noctalia.compositor.name() == "umbriel" then
	noctalia.compositor.subscribe({ events = { "windows" } }, onWindows)
end

function update()
	noctalia.setUpdateInterval(RULES_INTERVAL)
	refreshRules()
end
