--!nonstrict
-- Bar widget: one button toggling the tunnel, drawn from what the watcher publishes.

-- Nothing here polls: the watcher service owns the state and this only redraws.
local TICK_INTERVAL = 60000

local UP_GLYPH = noctalia.getConfig("up_glyph")
local DOWN_GLYPH = noctalia.getConfig("down_glyph")
local SHOW_LABEL = noctalia.getConfig("show_label")

local tunnel = noctalia.state.get("tunnel")

local function render()
	local up = tunnel ~= nil and tunnel.up
	local busy = tunnel ~= nil and tunnel.busy
	local name = tunnel and tunnel.interface or ""
	if busy then
		barWidget.setGlyph("loader-2")
		barWidget.setGlyphColor("on_surface")
		barWidget.setTooltip(noctalia.tr("tooltip.busy", { interface = name }))
	else
		barWidget.setGlyph(up and UP_GLYPH or DOWN_GLYPH)
		barWidget.setGlyphColor(up and "primary" or "on_surface")
		barWidget.setTooltip(noctalia.tr(up and "tooltip.up" or "tooltip.down", { interface = name }))
	end
	barWidget.setText(SHOW_LABEL and name or "")
end

noctalia.state.watch("tunnel", function(value)
	tunnel = value
	render()
end)

-- A bar that reloads has missed the publish that put the tunnel where it is, so
-- re-read the value rather than waiting for it to change again.
function update()
	noctalia.setUpdateInterval(TICK_INTERVAL)
	tunnel = noctalia.state.get("tunnel")
	render()
end

function onClick()
	-- The service refuses this too; refusing it here is what keeps the click from
	-- reading as a press that did nothing.
	if tunnel and tunnel.busy then
		return
	end
	noctalia.state.set("command", { action = "toggle", at = noctalia.nowMs() })
end

-- Draw before the first tick, or the widget shows its manifest glyph until then.
render()
