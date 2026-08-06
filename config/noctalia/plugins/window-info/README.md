# Window Info

Window Info adds a bar widget showing the focused window's title or its app id
(the class you need for a window rule), switched by clicking the widget.
Noctalia's own active window widget shows the title only.

## Plugin

| Field | Value |
| --- | --- |
| ID | `metsker/window-info` |
| Entries | Bar widget: `window` |

## Requirements

MangoWC and its `mmsg` command on `PATH`. The widget reads
`mmsg watch focusing-client` for live focus changes.

## Usage

Add the `window` widget from Noctalia's widget picker.

| Action | Effect |
| --- | --- |
| Click | Toggle between title and app id |
| Middle-click | Copy the shown value to the clipboard |
| Hover | Tooltip with the untruncated value |

The glyph tracks the mode: a window frame for the title, a tag for the app id.
Text longer than 40 characters is truncated; the tooltip always has the whole
value. With no window focused the widget hides itself, glyph included, so an
empty tag leaves no gap on the bar.

## Notes

The mode is global, not per-bar: clicking one instance switches every instance
on every monitor at once, through the plugin's shared state. It is also written
to `$XDG_STATE_HOME/noctalia/plugins/data/metsker/window-info/mode`, so a shell
restart comes back on whichever mode was last picked.
