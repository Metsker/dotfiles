--!nonstrict
-- Bar widget: the focused window's title, toggled to its app id on click. It only draws -
-- the watcher service owns the stream, the float rules and the icon lookups.

local MODES = {
	{ key = "title", glyph = noctalia.getConfig("title_glyph") },
	{ key = "appid", glyph = noctalia.getConfig("appid_glyph") },
}

-- Read once: the host rebuilds the widget when a setting changes, so the script
-- re-runs with the new value rather than needing a getConfig per render.
local LIMIT = noctalia.getConfig("max_length")
local USE_ICON = noctalia.getConfig("app_icon")

-- Nothing here polls: the watcher service owns the stream and this only redraws.
local TICK_INTERVAL = 60000

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
local window = noctalia.state.get("window")

-- Byte-wise sub would cut a Cyrillic or emoji title mid-character.
local function clip(value)
	local count = utf8.len(value)
	if not count or count <= LIMIT then
		return value
	end
	return string.sub(value, 1, utf8.offset(value, LIMIT - 2) - 1) .. "..."
end

local function current()
	return window and window[MODES[mode].key] or ""
end

local function render()
	if not (window and window.focused) then
		barWidget.clearTooltip()
		barWidget.setVisible(false)
		return
	end
	local value = current()
	barWidget.setVisible(true)
	-- The service resolved the icon once for the whole shell; the glyph stays the fallback
	-- for an app id no desktop entry and no icon theme matched.
	if USE_ICON and window.icon then
		-- No size: the default is the glyph's own, so the widget keeps its height.
		barWidget.setImage(window.icon)
	else
		barWidget.setGlyph(MODES[mode].glyph)
	end
	barWidget.setText(clip(value))
	-- Untruncated, so a clipped title is still readable on hover, and naming the float rule
	-- because the rule is otherwise invisible until the next window opens.
	barWidget.setTooltip(window.floating and (value .. "\n" .. noctalia.tr("tooltip.floating")) or value)
end

noctalia.state.watch("window", function(value)
	window = value
	render()
end)

noctalia.state.watch("mode", function(value)
	-- The setter is notified too, so the clicked bar lands here having already rendered.
	if MODES[value] and value ~= mode then
		mode = value
		render()
	end
end)

-- A bar that reloads mid-session has missed the focus change that put the window where it is,
-- so re-read the published value rather than waiting for the next one.
function update()
	noctalia.setUpdateInterval(TICK_INTERVAL)
	window = noctalia.state.get("window")
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
		noctalia.notify(noctalia.tr("notify.copied"), value)
	end
end

-- Asking for the rule rather than writing it keeps one right-click to one write, however many
-- bars carry the widget; the shown value rides along because only this bar knows which of the
-- two names it is displaying.
function onRightClick()
	if not (window and window.focused) then
		return
	end
	local value = current()
	noctalia.state.set("command", {
		action = "float-rule",
		appid = window.appid,
		title = window.title,
		label = value ~= "" and value or window.title,
		at = noctalia.nowMs(),
	})
end

-- Hide before the first tick, or the widget shows its manifest glyph until then.
render()
