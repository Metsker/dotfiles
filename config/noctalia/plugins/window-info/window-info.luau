--!nonstrict
-- Bar widget: the focused window's title, toggled to its app id on click.

-- ponytail: fixed cap; make it a plugin setting if a bar ever wants a different width.
local LIMIT = 40
-- The watch stream carries every focus change, so the tick exists only to notice
-- that the stream itself died, which a mango restart is enough to do.
local RESYNC_INTERVAL = 15000
local MODES = {
	{ key = "title", glyph = "app-window" },
	{ key = "appid", glyph = "tag" },
}

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

local function render()
	if not client then
		barWidget.clearTooltip()
		barWidget.setVisible(false)
		return
	end
	local value = current()
	barWidget.setVisible(true)
	barWidget.setGlyph(MODES[mode].glyph)
	barWidget.setText(clip(value))
	-- Untruncated, so a clipped title is still readable on hover.
	barWidget.setTooltip(value)
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
-- undecodable line arrives here as nil and reads as "nothing focused".
local function accept(data)
	client = (type(data) == "table" and data.title) and data or nil
	render()
end

-- watch focusing-client emits a snapshot on connect + one JSON line per focus change.
noctalia.runStream("mmsg watch focusing-client", function(line)
	local data = noctalia.json.decode(line)
	accept(data)
end)

-- The host never restarts a dead stream and gives the script no way to notice one,
-- so the tick re-reads the same payload. Without it a mango restart freezes the
-- widget on whatever happened to be focused at the time.
function update()
	noctalia.setUpdateInterval(RESYNC_INTERVAL)
	render()
	noctalia.runAsync("mmsg get focusing-client", function(result)
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
