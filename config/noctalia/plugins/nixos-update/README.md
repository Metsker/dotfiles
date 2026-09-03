# NixOS Update

NixOS Update adds a bar widget that appears once the NixOS channel it watches
has moved past the revision your flake pins, and is absent while the two agree.
Visible means `nix flake update` would move you; it says nothing about whether
the built system matches the lock.

## Plugin

| Field | Value |
| --- | --- |
| ID | `metsker/nixos-update` |
| Entries | Service: `checker` · Bar widget: `update` |

## Requirements

Network access, and a `flake.lock` to read. Nothing else - the check is one HTTP
GET of `https://channels.nixos.org/<channel>/git-revision`, compared against the
revision the lock holds for one of the flake's inputs.

## Usage

Add the `update` widget from Noctalia's widget picker. Clicking it opens a
terminal running the update command.

The text beside the glyph is how old the pinned revision is, in days, taken
from the lock's own `lastModified`. Turning the label off leaves the glyph on
its own. Either way the tooltip carries both short revisions and the channel
they were compared for.

## Settings

The glyph and the label toggle are widget settings, edited with the bar
widget's own settings, so two placements can differ. The other five are
plugin-level, edited under Settings → Plugins.

| Setting | Default | Effect |
| --- | --- | --- |
| Glyph | `snowflake` | Shown while the channel is ahead of the pin |
| Show label | on | Print the pin's age beside the glyph |
| Channel | `nixos-unstable` | Which channel's head to fetch |
| Flake lock | `~/dotfiles/flake.lock` | The lock file to read the pin from |
| Flake input | `nixpkgs` | Which of the flake's inputs to compare (advanced) |
| Check interval | 60 min | Minutes between checks |
| Update command | `cd ~/dotfiles && nix flake update && nh os switch` | Run in a terminal on click |

## Notes

The checking settings are plugin-level and the drawing settings widget-level,
because the service does the checking and the widget only draws: one settings
page feeds both, and one request per interval covers every bar.

A flake input that only *follows* another input has no revision of its own -
`flake.lock` records it as a path rather than a node name. Pointing the Flake
input setting at one of those hides the widget instead of reporting a bogus
comparison, as does an unreachable channel or a misspelled channel name.

The service defines `onConfigChanged`, so editing a setting re-checks in place
rather than making the host restart the runtime.
