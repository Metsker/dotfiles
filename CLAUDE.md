# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A NixOS flake configuring a single host (`pc`), plus the plain-text dotfiles it symlinks into `~/.config`.
No build system, no tests - the rebuild is the test.

## Commands

```sh
nh os switch          # rebuild + activate (nh is pinned to this flake in modules/nix.nix)
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
imports another by path, so files can be renamed and moved freely. Each one owns a single feature
*across every layer it touches* - `modules/mango.nix` carries the compositor's NixOS options, its
patch overlay, and its `~/.config/mango` symlink together.

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

- **mango** is the live compositor (`programs.mango`), started by greetd autologin through **uwsm** so
  apps land in systemd user scopes. `config/mango/config.conf` sources the other `.conf` files.
- **noctalia** is the bar/shell/launcher and owns theming. Its templates render color palettes into app
  configs at theme-switch time; the rendered outputs are gitignored (`**/noctalia.*`, `**/themes/noctalia`).
  Edit the template (`config/noctalia/templates/`) or the noctalia settings, never the generated file.
  `config/mango/noctalia.conf` and `config/monstar/themes/noctalia` are both generated.
- **monstar** is the terminal, built from a flake input. `term` in `modules/monstar.nix` is an
  absolute-store-path shim because `~/.local/bin` is not on mango's session PATH.
- `config/hypr/` and `config/niri/` are inactive leftovers - neither compositor is installed, and
  `patches/hyprland-scrolling-clamp-camera.diff` is unused. Do not treat them as live config.

## Claude Code config

`modules/claude.nix` owns it all. MCP servers are declared in one `writeText` JSON and passed via a `claude`
wrapper (`--mcp-config=...`); do not add servers to `~/.claude.json`. `settings.json` is linked with
`ln -sf` in an activation script rather than `home.file`, because Claude Code rewrites it at runtime and
a read-only store symlink would break that. The tracked files live in `config/claude/`.

## Conventions

- Commit messages follow `config/claude/skills/writing-commit-messages/SKILL.md`: kernel style,
  `subsystem: imperative summary`, body explaining why, and **no `Co-Authored-By` or attribution trailer**
  (this repo's rule overrides the default).
- Comments explain *why* a non-obvious workaround exists, and stay to one line per block.
- `ponytail:` prefixes a deliberate shortcut with a known ceiling and its upgrade path.
