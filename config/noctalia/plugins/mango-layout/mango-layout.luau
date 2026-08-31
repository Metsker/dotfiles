--!nonstrict
-- Bar widget: MangoWC's current tiling-layout symbol (e.g. "S", "T"); click cycles it.

local GLYPH = "layout-columns"
-- The watch stream carries every change, so the tick exists only to notice that
-- the stream itself died, which a mango restart is enough to do.
local RESYNC_INTERVAL = 15000
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

-- json.decode reports a bad payload as (nil, err) rather than raising, and
-- activeLayout reads a nil payload as "no active tag", so neither needs a guard.
local function accept(data)
	local current = activeLayout(data)
	if current and current ~= layout then
		layout = current
		render()
	end
end

-- watch all-tags emits a snapshot on connect + one JSON line per change.
noctalia.runStream("mmsg watch all-tags", function(line)
	local data = noctalia.json.decode(line)
	accept(data)
end)

-- The host never restarts a dead stream and gives the script no way to notice one,
-- so the tick re-reads the same payload. Without it a mango restart freezes the
-- widget on whatever layout was active at the time.
function update()
	noctalia.setUpdateInterval(RESYNC_INTERVAL)
	render()
	noctalia.runAsync("mmsg get all-tags", function(result)
		if result.exitCode == 0 then
			local data = noctalia.json.decode(result.stdout)
			accept(data)
		end
	end)
end

function onClick()
	noctalia.togglePanel("metsker/mango-layout:picker")
end

function onRightClick()
	noctalia.runAsync("mmsg dispatch switch_layout")
end
