# VPN

VPN brings an AmneziaWG tunnel up or down from two places: a bar widget and a
control-center tile. Both say which of the two states the tunnel is in, and
clicking either asks for the other one.

## Plugin

| Field | Value |
| --- | --- |
| ID | `metsker/vpn` |
| Entries | Service: `watcher` · Bar widget: `vpn` · Shortcut: `toggle` |

## Requirements

`awg-quick` and `pkexec`, both on PATH, and a polkit authentication agent running
in the session - Noctalia ships one, enabled with `polkit_agent = true` under
`[shell]` in `settings.toml`. Without an agent the toggle silently does nothing,
because pkexec has nowhere to ask.

## Usage

Add the `vpn` widget from Noctalia's widget picker, the `toggle` tile from
Settings → Control Center shortcuts, or both. Either one runs `awg-quick up` or
`awg-quick down` under pkexec, which prompts for a password every time;
dismissing the prompt leaves the tunnel as it was and reports nothing. While the
prompt is open the widget shows a spinner and the tile goes dark, so a second
click cannot stack a second dialog.

Neither surface has to be placed for the plugin to work: the service holds the
state, and `noctalia msg plugin metsker/vpn:watcher all toggle` reaches it from a
terminal.

The tunnel's state is read rather than remembered, so one raised by a systemd
unit at boot, or by AmneziaVPN's own GUI, shows as connected here without having
told the plugin anything.

## Settings

Only the bar label is a widget setting, edited with the bar widget's own
settings. The rest are plugin-level, edited under Settings → Plugins, because the
two surfaces are two views of one tunnel and must not disagree about it.

| Setting | Default | Effect |
| --- | --- | --- |
| Show label | off | Print the interface name beside the glyph, on the bar |
| Interface | `amn0` | The link whose existence is read as connected |
| Config file | `/etc/amnezia/amneziawg/amn0.conf` | The conf handed to awg-quick |
| Connected glyph | `shield-check` | Shown by both surfaces while the tunnel is up |
| Disconnected glyph | `shield-off` | Shown by both surfaces while the tunnel is down |
| Command path | `/run/current-system/sw/bin` | PATH given to the elevated command (advanced) |

## Notes

The state and the one command that changes it live in the service rather than in
either surface, for two reasons. A shortcut gets no `update()` tick, so a tile
cannot poll for anything and has to be fed. And two surfaces each running their
own `awg-quick` would put two password dialogs on screen for one tunnel.

State is `/sys/class/net/<interface>` existing, polled every three seconds. That
is the tunnel itself rather than a cache of it, so nothing has to notify the
service and nothing can leave it disagreeing with reality for longer than a tick.
The surfaces ask for a *toggle* rather than for a direction, so a tile drawn from
a stale publish cannot ask for the state the tunnel is already in.

pkexec replaces the inherited environment with a PATH of the FHS bin
directories, which are empty on NixOS. `awg-quick` carries its own dependencies
through a wrapper but still calls `awg` by bare name, so the elevated command is
`pkexec env PATH=… awg-quick …` rather than `pkexec awg-quick …`, which would
fail at the first `awg setconf`. The Command path setting is what to change on a
distribution that puts these somewhere else.

This repo's NixOS configuration also runs `amneziawg-amn0.service`, a oneshot
with `RemainAfterExit = true` that raises the same tunnel at boot. awg-quick and
systemd do not know about each other: taking the tunnel down here leaves that
unit reporting `active`, and `systemctl restart amneziawg-amn0` is what puts the
two back in agreement. Nothing breaks in the meantime - the next boot starts from
a clean slate either way - but `systemctl is-active` is not a second opinion on
what this plugin shows.
