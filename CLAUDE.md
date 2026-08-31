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
| `desktop/session.nix` | uwsm, greetd, portals, screencast, voxtype, the wayland tool scripts |
| `desktop/mango-noctalia.nix` | desktop profile: mango + noctalia |
| `desktop/hyprland-dms.nix` | desktop profile: hyprland + DankMaterialShell |
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

Two **desktop profiles**, each a compositor + shell pair in one module, both installed at once.
There is no autologin: the greeter is where a profile gets picked, and swapping means logging out
and choosing the other entry. Everything a pair needs - packages, overlays, portal config, config
symlinks, its own scripts - lives in that pair's file, and `modules/desktop/session.nix` holds only
what both need.

**uwsm** publishes a `wayland-session@<compositor>.target` per session, and each profile hangs its
shell off its own one. That is what keeps the other profile's shell down; `graphical-session.target`
would start both. The instance name comes from the session entry, so it must match the entry the
profile registers - `mango-uwsm` from `programs.uwsm.waylandCompositors`, `hyprland-uwsm` from
`programs.hyprland.withUWSM`. The greeter also lists a plain `hyprland` entry that the hyprland
package ships; it bypasses uwsm and starts no shell, so it is the wrong one to pick.

- **mango + noctalia** (`modules/desktop/mango-noctalia.nix`). `config/mango/config.conf` sources the
  other `.conf` files. noctalia owns theming: its templates render color palettes into app configs at
  theme-switch time, and the rendered outputs are gitignored (`**/noctalia.*`, `**/themes/noctalia`).
  Edit the template (`config/noctalia/templates/`) or the noctalia settings, never the generated file.
  `config/mango/noctalia.conf` and `config/monstar/themes/noctalia` are both generated.
- **hyprland + dms** (`modules/desktop/hyprland-dms.nix`). DankMaterialShell owns the Hyprland
  config: `dms setup` writes `~/.config/hypr/hyprland.lua` plus the `dms/` fragments beside it
  (`binds.lua`, `layout.lua`, `colors.lua`, `windowrules.lua`, `cursor.lua`), and the DMS Settings
  pages rewrite them at runtime, so none of that is tracked - run `dms setup` once on a fresh
  machine. Two exceptions are symlinked out of `config/hypr/dms/`: `binds-user.lua`, which setup
  never rewrites and which carries everything personal (input, workspace pinning, autostart,
  window rules, keybinds), and `outputs.lua`, the monitor layout, which setup leaves alone while
  it is non-empty. `hyprland.lua` requires `binds-user.lua` last, so a key the generated config
  already bound has to be released with `hl.unbind` before it can be re-used - `binds-user.lua`
  wraps that pair in a local `bind` helper. **Setup only appends `require("dms.binds")` and
  `require("dms.binds-user")` to `hyprland.lua`**, so `outputs.lua`, `layout.lua`, `colors.lua`
  and `windowrules.lua` would never load; `binds-user.lua` requires them itself at the top.
  Its settings are ported from `config/mango/*.conf` so both profiles behave the same: master
  layout with the master area on the right (mango's `right_tile`), and mango's per-monitor tags
  1-9 flattened into global workspace ids with the monitor in the tens digit - 1-9 on HDMI-A-2,
  11-19 on DP-1, 21-29 on the HDMI-A-3 panel. Panels are driven by
  `dms ipc call <target> <function>`, so a bind does nothing while the shell is down. DMS's
  matugen theming is independent of noctalia's templates. There is no recording bind on this
  profile: `record` drives noctalia's screen_recorder plugin and DMS ships no equivalent.
  `screenshot` still asks mango's `mmsg` for window boxes and the cursor position, so on this
  profile it works without window snapping.
- **monstar** is the terminal, built from a flake input. `term` in `modules/shell.nix` is an
  absolute-store-path shim because `~/.local/bin` is not on either compositor's session PATH.
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
