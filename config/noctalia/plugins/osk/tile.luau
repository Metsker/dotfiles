--!nonstrict
-- Control-center tile: draws what the watcher publishes and asks it for a toggle.

local keyboard = noctalia.state.get("keyboard")

local function render()
	local up = keyboard ~= nil and keyboard.running
	local busy = keyboard ~= nil and keyboard.busy
	-- One label for both states: "Keyboard on" is cut off at tile width, and the highlight already says it.
	shortcut.setLabel(noctalia.tr("shortcut.label"))
	shortcut.setIcon("keyboard", "keyboard-off")
	shortcut.setActive(up)
	-- A shortcut gets no update() tick, so going dead is the only way it can show
	-- that a click is already being handled.
	shortcut.setEnabled(not busy)
end

noctalia.state.watch("keyboard", function(value)
	keyboard = value
	render()
end)

function onClick()
	noctalia.state.set("command", { action = "toggle", at = noctalia.nowMs() })
end

-- Draw before the first publish, or the tile shows its manifest icon until then.
render()
