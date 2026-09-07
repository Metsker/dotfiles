# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A NixOS flake configuring a single host (`pc`), plus the plain-text dotfiles it symlinks into `~/.config`.
No build system, no tests - the rebuild is the test.

## Commands

```sh
nh os switch          # rebuild + activate (nh is pinned to this flake in modules/system.nix)
nh os boot            # activate on next boot
nix flake update mango  # update one input; `nix flake update` updates all
nixpkgs-fmt modules/  # formatter; `nil` is the LSP
git submodule update --init  # config/nvim is a submodule (github.com/Metsker/nvim)
```

**A new `.nix` file must be `git add`ed before it takes effect** - flakes ignore untracked
files, so import-tree simply will not see it.

`nix flake check` is not wired up, but a full eval catches every module error:

```sh
nix eval .#nixosConfigurations.pc.config.system.build.toplevel.drvPath
```

## Two-layer architecture

**Nix layer** declares packages, services, and hardware. **Dotfile layer** is everything under `config/`.

Tracked configs are linked into `~/.config` with `mkOutOfStoreSymlink`, so edits to a tracked config
take effect immediately with no rebuild - restart the app, not the system. A rebuild is only needed when:

- adding a *new* symlink (a new `xdg.configFile` entry in some module)
- changing anything in a `.nix` file
- changing a script under `scripts/` (they are built into store paths, see below)

### Dendritic layout

`flake.nix` holds inputs and nothing else; it hands `modules/` to flake-parts via `import-tree`:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

Every `.nix` file under `modules/` is therefore a **flake-parts module**, auto-imported. No file
imports another by path, so files can be renamed and moved freely. Each one owns a **domain**
*across every layer it touches* - `modules/desktop/mango-noctalia.nix` carries the compositor's NixOS
options, its overlays, the portal config and the `~/.config/mango` symlink together.

One file per domain, not per app - a new program joins the file its domain already owns:

| file | domain |
| --- | --- |
| `system.nix` | boot, nix settings, locale, networking, stateVersion |
| `hardware.nix` | GPU, firmware, audio, bluetooth, peripherals |
| `user.nix` | the account, home-manager wiring, the `dotfile` argument |
| `theming.nix` | GTK/Qt/cursor/icons, fonts |
| `desktop/session.nix` | noctalia, uwsm, greetd, portals, screencast, voxtype, the wayland tool scripts |
| `desktop/mango.nix` | desktop profile: mango |
| `desktop/driftwm.nix` | desktop profile: driftwm |
| `desktop/umbriel.nix` | desktop profile: umbriel |
| `shell.nix` | fish, monstar, foot, yazi, neovim, git |
| `dev.nix` | toolchain, playwright browsers, herdr, remote host bootstrap |
| `apps.nix` | browser, file manager, media, chat, art, VPN |
| `claude.nix`, `webapps.nix`, `gaming.nix` | each big enough to stand alone |

Nesting is cosmetic - import-tree walks the whole tree, so `modules/hosts/` groups files without
changing anything.

Modules are stored under three names and assembled in `modules/hosts/pc.nix`:

- `flake.modules.nixos.base` - host-agnostic NixOS
- `flake.modules.nixos.pc` - this machine's hardware (NVIDIA, LUKS, hostname)
- `flake.modules.homeManager.metsker` - the user's home, wired in by `modules/user.nix`

Conventions that follow from this:

- `inputs` is in scope in every file; nothing is threaded through `specialArgs`.
- Home modules take a `dotfile` argument (`modules/user.nix`): `dotfile "mango"` is the
  out-of-store symlink to `config/mango`.
- A cachix substituter lives next to the input that needs it, not in one central list.
- Files whose path contains `_` are skipped by import-tree - that is why the generated
  `modules/hosts/_pc-hardware.nix` is not a module of its own.
- `patches/` - out-of-tree patches, applied by an overlay in the feature's own module.

### Scripts

`scripts/*.sh` are wrapped with `pkgs.writeShellApplication` in the owning module, with every dependency listed
in `runtimeInputs`. A script must never assume a binary is on PATH - add it to `runtimeInputs` instead.
`set -euo pipefail` and shellcheck are applied by the wrapper.

### Overlays

Each overlay pins or patches an upstream package and carries a comment naming the
condition to drop it (a merged PR, a fixed issue). Keep that discipline: an overlay without an exit
condition becomes permanent.

## Desktop stack

Three **desktop profiles**, one compositor each, all installed at once. There is no autologin: the
greeter is where a profile gets picked, and swapping means logging out and choosing another entry.

**noctalia is the shell on all three**, so it is not part of any profile - it lives in
`modules/desktop/session.nix` on `graphical-session.target`, the one target every profile reaches.
A profile's file therefore holds only its compositor: packages, overlays, portal config, its config
symlink. Adding a fourth compositor means adding one file and nothing else.

The three reach that target by different routes. Only mango is **uwsm**-managed: uwsm publishes a
`wayland-session@<compositor>.target` per session, whose instance name must match the entry
`programs.uwsm.waylandCompositors` registers. driftwm ships its own `driftwm-session` and
`driftwm.service`, and umbriel its own `start-umbriel`, `umbriel.service` and
`umbriel-session.target`; both pull `graphical-session.target` up behind them. Nothing needs gating
any more, because there is only one shell and every profile wants it.

- **mango** (`modules/desktop/mango.nix`). `config/mango/config.conf` sources the other `.conf`
  files. Master layout with the master area on the right (`right_tile`), and per-monitor tags 1-9.
- **driftwm** (`modules/desktop/driftwm.nix`). An infinite-canvas compositor: windows keep their
  native size on a 2D canvas and the display is a camera over it, so there are no workspaces and
  mango's per-monitor tags have no analogue - `Mod+1-4` are camera bookmarks. `config/driftwm/config.toml`
  hot-reloads on save; every default is documented in the package's own `config.reference.toml`.
  Ported from mango: the launcher set, the input setup, the monitor layout and the silent-open rules.
  `Mod+C`/`Mod+V` are the clipboard script, which displaces `center-window` onto `Mod+Ctrl+C`.
  Its NixOS module sets the portal config, portal list and gnome-keyring with `mkDefault`, and a
  list option takes only its highest-priority definitions - so the module's portal defaults are
  dropped wholesale by the other modules' plain assignments and have to be repeated in the file.
  `screenshot` asks mango's `mmsg` for window boxes and the cursor position, so here it works
  without window snapping. The canvas background is a GLSL shader from the package's own
  `share/driftwm/wallpapers/`, named through `/run/current-system/sw` rather than a store path that
  moves; `environment.pathsToLink` is what puts that directory in the system profile at all.
- **umbriel** (`modules/desktop/umbriel.nix`). noctalia's own compositor, so the pairing needs no
  glue: its example config already carries noctalia's window and layer rules, and noctalia's
  `umbriel` theme template renders `~/.config/umbriel/noctalia.toml`, which `config.toml` includes
  through `[include.optional]`. Scrolling, dwindle and master layouts; `config/umbriel/config.toml`
  is ported from `config/mango/*.conf`, down to mango's per-monitor tag binds - nine static
  workspaces per output, reached as `workspace-switch:<n>/<output>`. Umbriel has no touchscreen
  mapping yet, so mango's `touch_map_to_mon` has no equivalent.
- noctalia owns theming on every profile: its templates render color palettes into app configs at
  theme-switch time, and the rendered outputs are gitignored (`**/noctalia.*`, `**/themes/noctalia`).
  Edit the template (`config/noctalia/templates/`) or the noctalia settings, never the generated file.
  `config/mango/noctalia.conf`, `config/umbriel/noctalia.toml` and `config/monstar/themes/noctalia`
  are all generated. Its per-compositor features come from runtime detection, not from Nix: mango and
  umbriel have workspace backends, driftwm falls to the `Unknown` path and shows no workspace module.
- **monstar** is the terminal, built from a flake input. `modules/shell.nix` names it exactly
  once, in a file-level `terminal` binding, and spends that on `$TERMINAL` in
  `environment.sessionVariables` and on the two KDE keys - swapping terminals is that one edit.
  All three compositors' keybinds spawn `$TERMINAL`, which works because their `spawn`/`exec` go
  through `sh`; noctalia reads it too, its own discovery list ending at foot. KIO's launcher
  reads `kdeglobals` rather than the environment, so an activation script writes
  `TerminalApplication` and `TerminalService` there - unset, dolphin's "Open Terminal Here"
  falls through to an absent konsole and does nothing. A desktop entry's `Exec` is never
  shell-expanded, so entries needing a terminal set `Terminal=true` and let the launcher supply
  one instead of naming it. `SNACKS_GHOSTTY` is a session variable for the same reason: `-e nvim`
  starts no shell, and libghostty does not answer to the XTVERSION probe snacks.nvim gates on.
- `config/niri/` is an inactive leftover - niri is not installed, and
  `patches/hyprland-scrolling-clamp-camera.diff` is unused. Do not treat them as live config.

## Claude Code config

`modules/claude.nix` owns it all. MCP servers are declared in one `writeText` JSON and passed via a `claude`
wrapper (`--mcp-config=...`); do not add servers to `~/.claude.json`. `settings.json` is linked with
`ln -sf` in an activation script rather than `home.file`, because Claude Code rewrites it at runtime and
a read-only store symlink would break that. The tracked files live in `config/claude/`.

## Conventions

- Commit messages follow `config/claude/skills/writing-commit-messages/SKILL.md`: kernel style,
  `subsystem: imperative summary`, a body only when the subject leaves a question
  open, and **no `Co-Authored-By` or attribution trailer**
  (this repo's rule overrides the default).
- Comments explain *why* a non-obvious workaround exists, and stay to one line per block.
- `ponytail:` prefixes a deliberate shortcut with a known ceiling and its upgrade path.
