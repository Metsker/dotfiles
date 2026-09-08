# Window Info

Window Info adds a bar widget showing the focused window's title or its app id
(the class you need for a window rule), switched by clicking the widget. Right-clicking writes both
values into one of the compositor's own float rules, so that window opens floating - and a second
window of the same app joins its title to the same rule rather than opening another.
Noctalia's own active window widget shows the title only, falling back to the app id
only when the title is empty, and has no way to ask for the app id.

## Plugin

| Field | Value |
| --- | --- |
| ID | `metsker/window-info` |
| Entries | Bar widget: `window` |

## Requirements

`wminfo` on `PATH` - this repo's compositor-query script (`scripts/wminfo.sh`, wrapped in
`modules/desktop/session.nix`). It is the only place a compositor is named, so the widget asks it
four questions and branches on nothing:

| Query | Answer |
| --- | --- |
| `wminfo watch-focused-window` | `{"title":…,"appid":…}` at every focus change, until killed |
| `wminfo focused-window` | that same object once, for the resync tick |
| `wminfo float-rules` | the compositor's float rules, one `appid<tab>title<tab>title…` line per rule |
| `wminfo float-rule <appid> <title>` | adds that title to the app's rule, drops it where it is already there |

Null fields are an empty desktop and hide the widget. A nonzero exit means the IPC itself failed,
and the last value stays on the bar rather than blinking out. A compositor that answers neither -
driftwm, whose IPC carries no focus event to watch - leaves the widget hidden.

Umbriel is the only compositor wminfo writes rules for today. MangoWC keeps its rules in its own
config language, which nothing writes yet, so a right-click there reports that it changed nothing.

## Usage

Add the `window` widget from Noctalia's widget picker.

| Action | Effect |
| --- | --- |
| Click | Toggle between title and app id |
| Right-click | Add or drop the compositor's float rule for the focused window |
| Middle-click | Copy the shown value to the clipboard |
| Hover | Tooltip with the untruncated value, and the float rule that matches the window |

The focused app's own icon sits where a glyph would, resolved the way the built-in active window
widget resolves it - the desktop entry for the app id, then the icon theme - and drawn at the glyph's
size. An app id that matches no entry and no themed icon falls back to the mode glyph: by default a
window frame for the title, a tag for the app id. Longer text is truncated to the maximum length;
the tooltip always has the whole value. With no window focused the widget hides itself, icon
included, so an empty tag leaves no gap on the bar.

## Float rules

A right-click toggles the focused window in the compositor's own config, keyed on its app id and
its title together rather than on whichever of the two the widget happens to be showing. On umbriel
it writes

```toml
# rule	md.Obsidian	README - notes - Obsidian v1.9.14
[[window_rule]]
match.app_id = "^md\\.Obsidian$"
match.title = "^README - notes - Obsidian v1\\.9\\.14$"
default_floating = true
```

to `~/.config/umbriel/float-rules.toml`, an optional include listed in `config.toml`, then runs
`umbriel msg config-reload` - a written include is not a loaded one. A second right-click on the
same window drops it again. The tooltip names the rule whenever a window it matches is focused, so
a rule stays visible between the press and the next window opening.

There is one rule per app id, and it lists every title floated under that app id as one
alternation, so right-clicking a second Obsidian window joins its title to the rule already there:

```toml
# rule	md.Obsidian	README - notes - Obsidian v1.9.14	Tasks - notes - Obsidian v1.9.14
[[window_rule]]
match.app_id = "^md\\.Obsidian$"
match.title = "^(README - notes - Obsidian v1\\.9\\.14|Tasks - notes - Obsidian v1\\.9\\.14)$"
default_floating = true
```

Dropping a title takes it back out of the alternation, and the block goes with its last title. A
window that sets no app id keys on its title alone, under the rule whose app id is empty.

The matches are regexes, so wminfo escapes each literal into one and anchors it, and keeps the
literals in the comment above the block. That comment is what the file is read back from - to drop
a rule by hand, delete the comment and its block together, because the next write regenerates the
file from the comments alone.

`default_floating` only applies when a window opens, so the press also floats the focused window
outright, and tiles it back once no rule covers it any more, leaving every other open window where
it is.

A rule reaches every window it names, the first one included, which is as far as a compositor rule
reaches: Obsidian gives a popped-out window the same app id and the same
`<tab> - <vault> - Obsidian <version>` title shape as the main window, and runs every window in one
process, so nothing distinguishes "the main window" from "a popout" for a rule to key on.

## Settings

Widget-level, edited with the bar widget's own settings, so a narrow bar and a
wide one can carry the same widget at different caps.

| Setting | Default | Effect |
| --- | --- | --- |
| Maximum length | 40 | Characters before the text is truncated, ellipsis included |
| App icon | on | The focused app's icon in place of the glyph, glyph on no match |
| Title glyph | `app-window` | Shown while the title is displayed, with no app icon |
| App id glyph | `tag` | Shown while the app id is displayed, with no app icon |

Truncation counts characters rather than bytes, so a Cyrillic or emoji title is
never cut mid-character.

## Notes

The mode is global, not per-bar: clicking one instance switches every instance
on every monitor at once, through the plugin's shared state. It is also written
to `$XDG_STATE_HOME/noctalia/plugins/data/metsker/window-info/mode`, so a shell
restart comes back on whichever mode was last picked.

A right-click reports what actually changed rather than what was asked for: the widget re-reads
`wminfo float-rules` afterwards, and says the rule was added, dropped, or - on a compositor wminfo
writes no rules for - that nothing changed at all.
