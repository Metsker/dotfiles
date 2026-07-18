local layout = ""

local function activeLayout(data)
	if not data or not data.all_tags then
		return nil
	end
	for _, mon in ipairs(data.all_tags) do
		for _, tag in ipairs(mon.tags or {}) do
			if tag.is_active then
				return tag.layout
			end
		end
	end
end

local function render()
	barWidget.setGlyph("layout-columns")
	barWidget.setText(layout)
end

noctalia.runStream("mmsg watch all-tags", function(line)
	local l = activeLayout(noctalia.json.decode(line))
	if l and l ~= layout then
		layout = l
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
