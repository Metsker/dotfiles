--!nonstrict
-- Panel: one card per MangoWC layout, drawn as a miniature of its arrangement.
-- Card chrome follows omarluq/DMSMangoWCLayoutManager.

local COLUMNS = 3
-- The panel shell insets content 14px a side on top of this, so a margin reads as
-- PAD + 14 and the manifest size is the grid plus (PAD + 14) twice.
local PAD = 6
local GRID_GAP = 10
local CARD_WIDTH = 170
local PREVIEW_HEIGHT = 92
local CARD_PAD = 12
local BEZEL_PAD = 4
local SCREEN_PAD = 9
local WINDOW_GAP = 4

-- The reference places windows absolutely and noctalia's ui is flex-only, so the
-- viewport is measured here to turn cross-axis fractions into explicit pixels.
local VIEW_W = CARD_WIDTH - (CARD_PAD + BEZEL_PAD + SCREEN_PAD) * 2
local VIEW_H = PREVIEW_HEIGHT - (BEZEL_PAD + SCREEN_PAD) * 2

-- A window is { g = main-axis weight, c = cross-axis fraction, accent, o = opacity }
-- and a split adds dir; g and c default to 1. Symbols match MangoWC's layouts[].
local LAYOUTS = {
	{
		name = "tile",
		sym = "T",
		label = "Tile",
		cell = { dir = "row", { g = 58, accent = true }, { dir = "column", g = 38, {}, {} } },
	},
	{
		name = "scroller",
		sym = "S",
		label = "Scroller",
		cell = {
			dir = "row",
			{ g = 22, c = 0.64, o = 0.72 },
			{ g = 24, c = 0.84, o = 0.82 },
			{ g = 30, accent = true },
			{ g = 24, c = 0.84, o = 0.82 },
		},
	},
	{
		name = "grid",
		sym = "G",
		label = "Grid",
		cell = { dir = "column", { dir = "row", { accent = true }, {} }, { dir = "row", {}, {} } },
	},
	{ name = "monocle", sym = "M", label = "Monocle", cell = { dir = "row", { accent = true } } },
	{
		name = "deck",
		sym = "K",
		label = "Deck",
		cell = {
			dir = "row",
			{ g = 56, accent = true },
			{ g = 13, c = 0.78, o = 0.72 },
			{ g = 13, c = 0.58, o = 0.82 },
			{ g = 12, c = 0.38, o = 0.92 },
		},
	},
	{
		name = "center_tile",
		sym = "CT",
		label = "Center Tile",
		cell = {
			dir = "row",
			{ dir = "column", g = 20, {}, {} },
			{ g = 52, accent = true },
			{ dir = "column", g = 20, {}, {} },
		},
	},
	{
		name = "right_tile",
		sym = "RT",
		label = "Right Tile",
		cell = { dir = "row", { dir = "column", g = 38, {}, {} }, { g = 58, accent = true } },
	},
	{
		name = "vertical_scroller",
		sym = "VS",
		label = "Vertical Scroller",
		cell = {
			dir = "column",
			{ g = 22, c = 0.64, o = 0.72 },
			{ g = 24, c = 0.84, o = 0.82 },
			{ g = 30, accent = true },
			{ g = 24, c = 0.84, o = 0.82 },
		},
	},
	{
		name = "vertical_tile",
		sym = "VT",
		label = "Vertical Tile",
		cell = { dir = "column", { g = 54, accent = true }, { dir = "row", g = 40, {}, {}, {} } },
	},
	{
		name = "vertical_grid",
		sym = "VG",
		label = "Vertical Grid",
		cell = {
			dir = "row",
			{ dir = "column", g = 40, { g = 46, accent = true }, { g = 48 } },
			{ dir = "column", g = 54, { g = 28 }, { g = 28 }, { g = 32 } },
		},
	},
	{
		name = "vertical_deck",
		sym = "VK",
		label = "Vertical Deck",
		cell = {
			dir = "column",
			{ g = 52, accent = true },
			{ g = 13, c = 0.78, o = 0.72 },
			{ g = 13, c = 0.64, o = 0.82 },
			{ g = 12, c = 0.5, o = 0.92 },
		},
	},
	{
		name = "dwindle",
		sym = "DW",
		label = "Dwindle",
		cell = {
			dir = "row",
			{ g = 55, accent = true },
			{ dir = "column", g = 45, { g = 55 }, { dir = "row", g = 45, {}, {} } },
		},
	},
	{
		name = "fair",
		sym = "F",
		label = "Fair",
		cell = { dir = "column", { dir = "row", { accent = true }, {} }, { dir = "row", {}, {}, {} } },
	},
	{
		name = "vertical_fair",
		sym = "VF",
		label = "Vertical Fair",
		cell = { dir = "row", { dir = "column", { accent = true }, {} }, { dir = "column", {}, {}, {} } },
	},
}

local activeSym = nil
local hoveredName = nil
local roundness = 1

-- Stands in for Interface corner roundness: a plugin radius is scaled by the surface
-- scale only, and no runtime call exposes corner_radius_scale for us to read.
local function r(radius)
	return radius * roundness
end

local function windowFill(node, selected, hovered)
	if node.accent then
		return selected and "primary/0.78" or "primary/0.34"
	end
	return hovered and "on_surface/0.18" or "on_surface/0.12"
end

-- w and h are this node's pixel box: main axis split by weight, cross axis the
-- parent's extent times the child's fraction.
local function mini(node, w, h, parentDir, selected, hovered)
	local props = { flexGrow = node.g or 1, opacity = node.o }
	if parentDir == "row" then
		props.height = h
	elseif parentDir == "column" then
		props.width = w
	end

	if not node.dir then
		props.radius = r(5)
		props.fill = windowFill(node, selected, hovered)
		props.border = node.accent and (selected and "primary/0.95" or "primary/0.55") or "outline/0.55"
		props.borderWidth = 1
		return ui.box(props)
	end

	local total = 0
	for _, child in ipairs(node) do
		total += child.g or 1
	end
	local span = (node.dir == "row" and w or h) - WINDOW_GAP * (#node - 1)
	local children = {}
	for index, child in ipairs(node) do
		local share = span * (child.g or 1) / total
		if node.dir == "row" then
			children[index] = mini(child, share, h * (child.c or 1), "row", selected, hovered)
		else
			children[index] = mini(child, w * (child.c or 1), share, "column", selected, hovered)
		end
	end

	props.gap = WINDOW_GAP
	props.align = "center"
	return (node.dir == "row" and ui.row or ui.column)(props, children)
end

local function apply(entry)
	noctalia.runAsync("mmsg dispatch setlayout," .. entry.name)
	panel.close()
end

local function card(entry)
	local selected = entry.sym == activeSym
	local hovered = entry.name == hoveredName
	return ui.column({
		key = entry.name,
		width = CARD_WIDTH,
		gap = 8,
		padding = CARD_PAD,
		radius = r(12),
		-- stretch, not center: flexGrow children need a definite cross-axis width.
		align = "stretch",
		fill = selected and "primary/0.12" or (hovered and "surface_variant" or "surface_variant/0.55"),
		-- hovered doubles as the keyboard cursor, so it needs to read at a glance.
		border = selected and "primary" or (hovered and "primary/0.6" or "outline"),
		borderWidth = selected and 2 or 1,
		onHover = "onCardHover",
		onClick = function()
			apply(entry)
		end,
	}, {
		ui.column({
			height = PREVIEW_HEIGHT,
			padding = BEZEL_PAD,
			radius = r(10),
			fill = selected and "surface/0.94" or "surface/0.76",
			border = selected and "primary/0.6" or "outline/0.75",
			borderWidth = 1,
		}, {
			ui.column({
				flexGrow = 1,
				padding = SCREEN_PAD,
				radius = r(7),
				fill = selected and "surface_variant/0.9" or "surface_variant/0.7",
				border = "outline/0.38",
				borderWidth = 1,
			}, { mini(entry.cell, VIEW_W, VIEW_H, nil, selected, hovered) }),
		}),
		ui.label({
			text = entry.label,
			fontSize = 12,
			textAlign = "center",
			fontWeight = selected and "semibold" or "medium",
			color = "on_surface",
		}),
	})
end

local function render()
	-- Once per render, not per card: getConfig per node per frame burns the CPU budget.
	roundness = noctalia.getConfig("corner_roundness") or 1

	-- ui.button rounds itself with Style::scaledRadiusMd, so it tracks the shell's
	-- corner roundness directly rather than through the setting standing in for it.
	local rows = {
		ui.row({ align = "center" }, {
			ui.label({ text = noctalia.tr("panel.title"), fontSize = 16, fontWeight = "semibold" }),
			ui.spacer({ flexGrow = 1 }),
			ui.button({
				glyph = "close",
				-- default over outline: same border, but filled surface_variant like
				-- the cards instead of the darker plain surface.
				variant = "default",
				tooltip = noctalia.tr("panel.close"),
				onClick = function()
					panel.close()
				end,
			}),
		}),
	}
	local row = {}
	for _, entry in ipairs(LAYOUTS) do
		table.insert(row, card(entry))
		if #row == COLUMNS then
			table.insert(rows, ui.row({ gap = GRID_GAP }, row))
			row = {}
		end
	end
	if #row > 0 then
		table.insert(rows, ui.row({ gap = GRID_GAP }, row))
	end

	-- A plain column, not ui.scroll: the scroll insets its viewport ~13px a side and
	-- clips to it, which no padding can undo and which no margin this tight survives.
	panel.render(ui.column({ gap = GRID_GAP, padding = PAD }, rows))
end

function onCardHover(state, key)
	hoveredName = (state == "true") and key or nil
	render()
end

-- Escape is absent on purpose: the host owns panel dismissal and refuses to hand it
-- over, so a panel can never make itself impossible to close from the keyboard.
local KEY_STEPS = {
	h = -1,
	left = -1,
	l = 1,
	right = 1,
	k = -COLUMNS,
	up = -COLUMNS,
	j = COLUMNS,
	down = COLUMNS,
}

local function cursorIndex()
	for index, entry in ipairs(LAYOUTS) do
		if entry.name == hoveredName or (hoveredName == nil and entry.sym == activeSym) then
			return index
		end
	end
	return 1
end

function onKey(chord, pressed)
	if not pressed then
		return
	end
	local current = cursorIndex()
	if chord == "enter" or chord == "space" then
		apply(LAYOUTS[current])
		return
	end
	local target = LAYOUTS[current + (KEY_STEPS[chord] or 0)]
	if target then
		hoveredName = target.name
		render()
	end
end

function readActive(result)
	local ok, data = pcall(noctalia.json.decode, result.stdout)
	if ok then
		for _, monitor in ipairs(data and data.monitors or {}) do
			if monitor.active then
				activeSym = monitor.layout_symbol
				break
			end
		end
	end
	render()
end

function onOpen()
	-- The script outlives the panel, so a stale cursor would otherwise be what the
	-- first Enter applies. Clearing it puts the cursor back on the active layout.
	hoveredName = nil
	-- Paint the grid before the query returns, or the panel opens empty.
	render()
	-- setlayout targets the focused monitor, so highlight that monitor's layout.
	noctalia.runAsync("mmsg get all-monitors", readActive)
end
