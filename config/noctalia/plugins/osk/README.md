# On-screen keyboard

A control-center tile that opens an on-screen keyboard, closes it again, and
shows which of the two it currently is. Written for wvkbd, which has no close
button of its own: it is a layer surface, so the compositor's close-window bind
cannot reach it either.

## Plugin

| Field | Value |
| --- | --- |
| ID | `metsker/osk` |
| Entries | Service: `watcher` · Shortcut: `toggle` |

## Requirements

The program named in the settings, on PATH or given as an absolute path. This
repo's NixOS configuration builds `wvkbd-deskintl` in `modules/desktop/session.nix`.

## Usage

Add the `toggle` tile from Settings → Control Center shortcuts. A click starts
the keyboard if it is not running and closes it if it is. The tile is
highlighted while the keyboard is up.

The service works without the tile placed:
`noctalia msg plugin metsker/osk:watcher all toggle` reaches it from a terminal.

## Settings

| Setting | Default | Effect |
| --- | --- | --- |
| Program | `wvkbd-deskintl` | The keyboard to start |
| Arguments | `-l full,cyrillic,special --landscape-layers full,cyrillic,special -H 280 -L 280` | Its flags, passed through a shell |

## Notes

The service tracks the one keyboard it started by pid, and closes it with
`kill <pid>`. A keyboard started some other way - from a terminal, say - is
neither shown on the tile nor closed by it; a click then starts a second one.
Matching by name was tried first and dropped: the only matcher the host offers
is a substring search over command lines, which also hits a shell or an editor
whose command line merely mentions the program.

The pid is stored in the plugin's data directory, so a noctalia restart still
knows which process to close. Before acting on it, the service checks that
`/proc/<pid>/comm` still names the program, so a pid the kernel has since
handed to something else is forgotten rather than killed.

While a keyboard is up, the service reads that one `/proc` file every two
seconds, which is how a keyboard that exited on its own turns the tile off.
With no keyboard up it reads nothing.

wvkbd also accepts SIGUSR1/SIGUSR2/SIGRTMIN to hide, show and toggle a running
keyboard. Those are not used: a hidden keyboard looks the same as a closed one
from outside, so the tile could not tell the two apart.
