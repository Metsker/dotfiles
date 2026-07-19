--!nonstrict
-- Bar widget: MangoWC's current tiling-layout symbol (e.g. "S", "T"); click cycles it.

local GLYPH = "layout-columns"
local layout = ""

-- First active tag's layout symbol (one active tag per monitor; a bar shows one output).
local function activeLayout(data)
	for _, monitor in ipairs(data and data.all_tags or {}) do
		for _, tag in ipairs(monitor.tags or {}) do
			if tag.is_active then
				return tag.layout
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
	noctalia.runAsync("mmsg dispatch switch_layout")
end
