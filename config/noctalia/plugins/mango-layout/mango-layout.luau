--!nonstrict
-- Bar widget: MangoWC's current tiling-layout symbol (e.g. "S", "T"); click cycles it.

local GLYPH = "layout-columns"
local layout = ""

-- Read at load: stream callbacks run without a widget snapshot, so outputName() is nil in them.
local output = barWidget.outputName()

-- Layout of this bar's own output; an unknown output falls back to the first monitor.
local function activeLayout(data)
	for _, monitor in ipairs(data and data.all_tags or {}) do
		if not output or monitor.monitor == output then
			for _, tag in ipairs(monitor.tags or {}) do
				if tag.is_active then
					return tag.layout
				end
			end
		end
	end
	return nil
end

local function render()
	barWidget.setGlyph(GLYPH)
	barWidget.setText(layout)
end

-- watch all-tags emits a snapshot on connect + one JSON line per change; guard the decode.
noctalia.runStream("mmsg watch all-tags", function(line)
	local ok, data = pcall(noctalia.json.decode, line)
	if not ok then
		return
	end
	local current = activeLayout(data)
	if current and current ~= layout then
		layout = current
		render()
	end
end)

function update()
	noctalia.setUpdateInterval(3000)
	render()
end

function onClick()
	noctalia.togglePanel("metsker/mango-layout:picker")
end

function onRightClick()
	noctalia.runAsync("mmsg dispatch switch_layout")
end
