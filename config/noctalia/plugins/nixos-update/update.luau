--!nonstrict
-- Bar widget: visible only while the tracked channel has moved past the flake's pin.

local DAY_SECONDS = 86400
-- Nothing here polls: the checker service owns the request and this only redraws,
-- often enough that the age it prints does not go stale.
local TICK_INTERVAL = 3600000

local status = noctalia.state.get("update")

-- How old the pin is, which is the part worth reading at a glance; the two
-- revisions it is derived from are in the tooltip.
local function age()
	if not status.lastModified then
		return ""
	end
	local days = (noctalia.nowMs() / 1000 - status.lastModified) / DAY_SECONDS
	return string.format("%dd", math.max(math.floor(days), 0))
end

local function render()
	if not (status and status.ok and status.behind) then
		barWidget.clearTooltip()
		barWidget.setVisible(false)
		return
	end
	barWidget.setVisible(true)
	barWidget.setGlyph(noctalia.getConfig("glyph"))
	barWidget.setText(noctalia.getConfig("show_label") and age() or "")
	barWidget.setTooltip(noctalia.tr("tooltip.behind", {
		channel = status.channel,
		-- Short revisions: the tooltip is a glance, not something to copy out of.
		pinned = string.sub(status.pinned, 1, 7),
		head = string.sub(status.head, 1, 7),
	}))
end

noctalia.state.watch("update", function(value)
	status = value
	render()
end)

function update()
	noctalia.setUpdateInterval(TICK_INTERVAL)
	status = noctalia.state.get("update")
	render()
end

function onClick()
	noctalia.runInTerminal(noctalia.getConfig("update_command"))
end

-- Hide before the first tick, or the widget shows its manifest glyph until then.
render()
