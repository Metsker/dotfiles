# Mango Layout

Mango Layout adds a bar widget showing the tiling layout MangoWC is using on
the current output, and a picker panel that previews every layout as a
miniature of its window arrangement so you can switch by sight instead of by
name.

## Plugin

| Field | Value |
| --- | --- |
| ID | `metsker/mango-layout` |
| Entries | Bar widget: `layout`; panel: `picker` |

## Requirements

MangoWC and its `mmsg` command on `PATH`. The widget reads
`mmsg watch all-tags` for live layout changes, the panel reads
`mmsg get all-monitors` to mark the active layout, and picking a card runs
`mmsg dispatch setlayout,<name>`.

## Usage

Add the `layout` widget from Noctalia's widget picker. It shows the layout
symbol of the active tag on the bar's own output - the one-letter symbol
MangoWC reports for the layout, such as `S` for scroller or `T` for tile.

Click the widget to open the picker, which draws all fourteen MangoWC layouts
as miniature previews and outlines the one the focused monitor is using; click
a card to switch to it. Right-click the widget to cycle to the next layout
without opening the picker.

The picker takes keyboard focus when it opens:

| Key | Action |
| --- | --- |
| `h` / `Left` | Move the cursor left |
| `l` / `Right` | Move the cursor right |
| `k` / `Up` | Move the cursor up a row |
| `j` / `Down` | Move the cursor down a row |
| `Enter` / `Space` | Apply the layout under the cursor |
| `Esc` | Close the picker |

The cursor starts on the layout the focused monitor is using, and the mouse shares
it: hovering a card moves the cursor there.

The picker can also be opened without the widget:

```sh
noctalia msg panel-toggle metsker/mango-layout:picker
```

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `corner_roundness` | `double` | `1.0` | Rounding of the layout cards, on the same scale as the shell's own Interface setting: `0` square, `1` default, `2` extra rounded. |

It exists because a plugin cannot read the shell's corner roundness: `radius` on a
plugin node is scaled by the surface scale alone, and no runtime call exposes
`corner_radius_scale`. Set it to match your Interface setting.

## Notes

On a multi-monitor setup each bar shows the layout of the output it sits on.
If the output cannot be identified the widget falls back to the first monitor
MangoWC reports. The picker always targets the focused monitor, because that
is what `setlayout` acts on.
