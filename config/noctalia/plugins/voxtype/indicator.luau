--!nonstrict
-- Bar widget: a microphone while voxtype records or transcribes, nothing when idle.

-- Only the states listed here are visible; anything else, "idle" included, hides
-- the widget. The value is the setting holding that state's glyph.
local GLYPHS = {
	recording = "recording_glyph",
	transcribing = "transcribing_glyph",
	error = "error_glyph",
}
-- Nothing here polls: the watcher service owns the stream and this only redraws.
local TICK_INTERVAL = 60000

local status = noctalia.state.get("status")

local function render()
	local setting = status and GLYPHS[status.class]
	if not setting then
		barWidget.clearTooltip()
		barWidget.setVisible(false)
		return
	end
	barWidget.setVisible(true)
	barWidget.setGlyph(noctalia.getConfig(setting))
	-- voxtype writes a tooltip per state already, so there is nothing to compose.
	barWidget.setTooltip(status.tooltip)
end

noctalia.state.watch("status", function(value)
	status = value
	render()
end)

-- A bar that reloads mid-dictation has missed the transition that put voxtype
-- where it is, so re-read the published value rather than waiting for the next one.
function update()
	noctalia.setUpdateInterval(TICK_INTERVAL)
	status = noctalia.state.get("status")
	render()
end

-- Hide before the first tick, or the widget shows its manifest glyph until then.
render()
