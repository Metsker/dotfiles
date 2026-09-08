--!nonstrict
-- Bar widget: the focused window's title, toggled to its app id on click.

-- The watch stream carries every focus change, so the tick exists only to notice
-- that the stream itself died, which a compositor restart is enough to do.
local RESYNC_INTERVAL = 15000
local MODES = {
	{ key = "title", glyph = noctalia.getConfig("title_glyph") },
	{ key = "appid", glyph = noctalia.getConfig("appid_glyph") },
}

-- Read once: the host rebuilds the widget when a setting changes, so the script
-- re-runs with the new value rather than needing a getConfig per render.
local LIMIT = noctalia.getConfig("max_length")
local USE_ICON = noctalia.getConfig("app_icon")

-- Every bar runs its own copy of this script, so the mode lives in the plugin's
-- shared state (mirrors it across bars live) backed by a file (survives a restart).
local dir = noctalia.pluginDataDir()
local STORE = dir and (dir .. "/mode")

local function stored()
	-- Shared state wins: a bar that started later must not undo a toggle made since.
	local shared = noctalia.state.get("mode")
	local value = shared or tonumber(STORE and noctalia.readFile(STORE) or "")
	return MODES[value] and value or 1
end

local mode = stored()
local client = nil
-- The compositor's own float rules as wminfo reports them: one rule per app id, carrying every
-- title floated under it. An empty app id is the rule for windows that set none.
local rules = {}

-- Byte-wise sub would cut a Cyrillic or emoji title mid-character.
local function clip(value)
	local count = utf8.len(value)
	if not count or count <= LIMIT then
		return value
	end
	return string.sub(value, 1, utf8.offset(value, LIMIT - 2) - 1) .. "..."
end

local function current()
	return client and client[MODES[mode].key] or ""
end

-- A rule names both the app id and the title, so it floats the window it was read off and no
-- other window of that app - the tooltip and the toggle both ask about this window alone.
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

local function render()
	if not client then
		barWidget.clearTooltip()
		barWidget.setVisible(false)
		return
	end
	local value = current()
	barWidget.setVisible(true)
	-- Resolving per render costs nothing: the host caches its icon lookups, and the
	-- glyph stays the fallback for an app id no desktop entry or icon theme matches.
	local icon = USE_ICON and client.appid and noctalia.appIconPath(client.appid)
	if icon then
		-- No size: the default is the glyph's own, so the widget keeps its height.
		barWidget.setImage(icon)
	else
		barWidget.setGlyph(MODES[mode].glyph)
	end
	barWidget.setText(clip(value))
	-- Untruncated, so a clipped title is still readable on hover, and naming the float rule
	-- because the rule is otherwise invisible until the next window opens.
	local floats = ruled(client.appid or "", client.title or "")
	barWidget.setTooltip(floats and (value .. "\n" .. noctalia.tr("tooltip.floating")) or value)
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
		render()
		if done then
			done()
		end
	end)
end

local function apply(value)
	-- The setter is notified too, so the clicked bar lands here having already rendered.
	if MODES[value] and value ~= mode then
		mode = value
		render()
	end
end

noctalia.state.watch("mode", apply)

-- json.decode reports a bad payload as (nil, err) rather than raising, so an
-- undecodable line arrives here as nil and reads as "nothing focused", which is
-- also what wminfo's null title means.
local function accept(data)
	client = (type(data) == "table" and data.title) and data or nil
	render()
end

-- wminfo is where the compositors are named: it turns whichever IPC is running
-- into {"title":…,"appid":…}, and answers neither query where there is no IPC to ask.
noctalia.runStream("wminfo watch-focused-window", function(line)
	local data = noctalia.json.decode(line)
	accept(data)
end)

-- The host never restarts a dead stream and gives the script no way to notice one,
-- so the tick re-reads the same payload. Without it a compositor restart freezes
-- the widget on whatever happened to be focused at the time.
function update()
	noctalia.setUpdateInterval(RESYNC_INTERVAL)
	render()
	refreshRules()
	noctalia.runAsync("wminfo focused-window", function(result)
		-- Only a successful query is worth believing; a failed one would otherwise
		-- read as an empty desktop and hide the widget.
		if result.exitCode == 0 then
			local data = noctalia.json.decode(result.stdout)
			accept(data)
		end
	end)
end

function onClick()
	local target = mode % #MODES + 1
	mode = target
	render()
	noctalia.state.set("mode", target)
	-- Only the clicked bar writes; the others learn through the state watch.
	if STORE then
		noctalia.writeFile(STORE, tostring(target))
	end
end

function onMiddleClick()
	local value = current()
	if value ~= "" then
		noctalia.copyToClipboard(value, "text/plain;charset=utf-8")
		noctalia.notify(noctalia.tr("notify.copied"), value)
	end
end

-- The rule names the app id and the title together, whichever of the two the widget happens to be
-- showing, so it floats this window rather than everything sharing one of its two names. A second
-- window of the same app joins its title to that rule instead of opening another. An argv table
-- rather than a command line, because a title is arbitrary text.
function onRightClick()
	if not client then
		return
	end
	local appid, title = client.appid or "", client.title or ""
	-- The shown value names the window in the notification, falling back to the title where the
	-- app id the widget is showing is the one the window never set.
	local value = current()
	if value == "" then
		value = title
	end
	local before = ruled(appid, title)
	noctalia.runAsync({ "wminfo", "float-rule", appid, title }, function(result)
		if result.exitCode ~= 0 then
			noctalia.notifyError(noctalia.tr("notify.rule.failed"), value)
			return
		end
		refreshRules(function()
			local after = ruled(appid, title)
			if after == before then
				-- A compositor wminfo writes no rules for answers the query with nothing at all.
				noctalia.notifyError(noctalia.tr("notify.rule.unsupported"), value)
			else
				noctalia.notify(noctalia.tr(after and "notify.rule.added" or "notify.rule.removed"), value)
			end
		end)
	end)
end
