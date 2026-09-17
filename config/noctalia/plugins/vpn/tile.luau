--!nonstrict
-- Control-center tile: the same toggle as the bar widget, off the same published
-- state. It holds no logic of its own - the watcher service owns both.

local tunnel = noctalia.state.get("tunnel")

local function render()
	local up = tunnel ~= nil and tunnel.up
	local busy = tunnel ~= nil and tunnel.busy
	shortcut.setLabel(
		if busy then noctalia.tr("shortcut.busy")
		elseif up then noctalia.tr("shortcut.up")
		else noctalia.tr("shortcut.down")
	)
	shortcut.setIcon(noctalia.getConfig("up_glyph"), noctalia.getConfig("down_glyph"))
	shortcut.setActive(up)
	-- A tile that goes dead while the dialog is open is what stops a second dialog
	-- here: a shortcut gets no update() tick, so it has no other way to notice.
	shortcut.setEnabled(not busy)
end

noctalia.state.watch("tunnel", function(value)
	tunnel = value
	render()
end)

function onClick()
	noctalia.state.set("command", { action = "toggle", at = noctalia.nowMs() })
end

-- Draw before the first publish, or the tile shows its manifest icon until then.
render()
