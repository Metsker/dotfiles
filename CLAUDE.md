# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A NixOS flake configuring a single host (`pc`), plus the plain-text dotfiles it symlinks into `~/.config`.
No build system, no tests - the rebuild is the test.

## Commands

```sh
nh os switch          # rebuild + activate (nh is pinned to this flake in configuration.nix)
nh os boot            # activate on next boot
nix flake update mango  # update one input; `nix flake update` updates all
nixpkgs-fmt file.nix  # formatter; `nil` is the LSP
git submodule update --init  # config/nvim is a submodule (github.com/Metsker/nvim)
```

There is no way to validate a change short of a rebuild. `nix flake check` is not wired up.

## Two-layer architecture

**Nix layer** declares packages, services, and hardware. **Dotfile layer** is everything under `config/`.

`home.nix` links `config/*` into `~/.config` with `mkOutOfStoreSymlink`, so edits to a tracked config
take effect immediately with no rebuild - restart the app, not the system. A rebuild is only needed when:

- adding a *new* directory to the `configs` attrset in `home.nix`
- changing anything in a `.nix` file
- changing a script under `scripts/` (they are built into store paths, see below)

### Layout

- `flake.nix` - `mkHost` composes `hosts/<name>/` + `configuration.nix` + home-manager (`home.nix`).
- `configuration.nix` - system-wide, host-agnostic. `hosts/pc/` holds only hardware/driver specifics (NVIDIA).
- `home.nix` - user packages, symlink table, script wrappers. Imports `xdg.nix`, `webapps.nix`, `claude.nix`.
- `patches/` - out-of-tree patches applied via `nixpkgs.overlays` in `configuration.nix`.

### Scripts

`scripts/*.sh` are wrapped with `pkgs.writeShellApplication` in `home.nix`, with every dependency listed
in `runtimeInputs`. A script must never assume a binary is on PATH - add it to `runtimeInputs` instead.
`set -euo pipefail` and shellcheck are applied by the wrapper.

### Overlays

Each overlay in `configuration.nix` pins or patches an upstream package and carries a comment naming the
condition to drop it (a merged PR, a fixed issue). Keep that discipline: an overlay without an exit
condition becomes permanent.

## Desktop stack

- **mango** is the live compositor (`programs.mango`), started by greetd autologin through **uwsm** so
  apps land in systemd user scopes. `config/mango/config.conf` sources the other `.conf` files.
- **noctalia** is the bar/shell/launcher and owns theming. Its templates render color palettes into app
  configs at theme-switch time; the rendered outputs are gitignored (`**/noctalia.*`, `**/themes/noctalia`).
  Edit the template (`config/noctalia/templates/`) or the noctalia settings, never the generated file.
  `config/mango/noctalia.conf` and `config/monstar/themes/noctalia` are both generated.
- **monstar** is the terminal, built from a flake input. `term` in `home.nix` is an absolute-store-path
  shim because `~/.local/bin` is not on mango's session PATH.
- `config/hypr/` and `config/niri/` are inactive leftovers - neither compositor is installed, and
  `patches/hyprland-scrolling-clamp-camera.diff` is unused. Do not treat them as live config.

## Claude Code config

`claude.nix` owns it all. MCP servers are declared in one `writeText` JSON and passed via a `claude`
wrapper (`--mcp-config=...`); do not add servers to `~/.claude.json`. `settings.json` is linked with
`ln -sf` in an activation script rather than `home.file`, because Claude Code rewrites it at runtime and
a read-only store symlink would break that. The tracked files live in `config/claude/`.

## Conventions

- Commit messages follow `config/claude/skills/writing-commit-messages/SKILL.md`: kernel style,
  `subsystem: imperative summary`, body explaining why, and **no `Co-Authored-By` or attribution trailer**
  (this repo's rule overrides the default).
- Comments explain *why* a non-obvious workaround exists, and stay to one line per block.
- `ponytail:` prefixes a deliberate shortcut with a known ceiling and its upgrade path.
