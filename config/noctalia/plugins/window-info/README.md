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

`wminfo` on `PATH` - this repo's compositor-query script (`scripts/wminfo.sh`, wrapped in
`modules/desktop/session.nix`). It is the only place a compositor is named, so the widget asks it
two questions and branches on nothing:

| Query | Answer |
| --- | --- |
| `wminfo watch-focused-window` | `{"title":…,"appid":…}` at every focus change, until killed |
| `wminfo focused-window` | that same object once, for the resync tick |

Null fields are an empty desktop and hide the widget. A nonzero exit means the IPC itself failed,
and the last value stays on the bar rather than blinking out. A compositor that answers neither -
driftwm, whose IPC carries no focus event to watch - leaves the widget hidden.

MangoWC and Umbriel are what wminfo answers for today; a third compositor is a case block there
rather than a change here.

## Usage

Add the `window` widget from Noctalia's widget picker.

| Action | Effect |
| --- | --- |
| Click | Toggle between title and app id |
| Middle-click | Copy the shown value to the clipboard |
| Hover | Tooltip with the untruncated value |

The glyph tracks the mode: by default a window frame for the title, a tag for
the app id. Longer text is truncated to the maximum length; the tooltip always has the whole
value. With no window focused the widget hides itself, glyph included, so an
empty tag leaves no gap on the bar.

## Settings

Widget-level, edited with the bar widget's own settings, so a narrow bar and a
wide one can carry the same widget at different caps.

| Setting | Default | Effect |
| --- | --- | --- |
| Maximum length | 40 | Characters before the text is truncated, ellipsis included |
| Title glyph | `app-window` | Shown while the title is displayed |
| App id glyph | `tag` | Shown while the app id is displayed |

Truncation counts characters rather than bytes, so a Cyrillic or emoji title is
never cut mid-character.

## Notes

The mode is global, not per-bar: clicking one instance switches every instance
on every monitor at once, through the plugin's shared state. It is also written
to `$XDG_STATE_HOME/noctalia/plugins/data/metsker/window-info/mode`, so a shell
restart comes back on whichever mode was last picked.
