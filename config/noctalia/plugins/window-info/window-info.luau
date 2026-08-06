--!nonstrict
-- Bar widget: the focused window's title, toggled to its app id on click.

-- ponytail: fixed cap; make it a plugin setting if a bar ever wants a different width.
local LIMIT = 40
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

-- watch focusing-client emits a snapshot on connect + one JSON line per focus change.
noctalia.runStream("mmsg watch focusing-client", function(line)
	local ok, data = pcall(noctalia.json.decode, line)
	client = (ok and type(data) == "table" and data.title) and data or nil
	render()
end)

-- Only for the first paint and as a fallback if the stream ever dies; the stream
-- itself drives every real update.
function update()
	noctalia.setUpdateInterval(5000)
	render()
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
		noctalia.notify("Copied", value)
	end
end
