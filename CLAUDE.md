# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A NixOS flake configuring two hosts - `pc` (the desktop) and `t490` (the laptop) - plus the plain-text
dotfiles it symlinks into `~/.config`.
No build system, no tests - the rebuild is the test.

## Commands

```sh
nh os switch          # rebuild + activate (nh is pinned to this flake in modules/system.nix)
nh os boot            # activate on next boot
nix flake update umbriel  # update one input; `nix flake update` updates all
nixpkgs-fmt modules/  # formatter; `nil` is the LSP
git submodule update --init  # config/nvim is a submodule (github.com/Metsker/nvim)
```

**A new `.nix` file must be `git add`ed before it takes effect** - flakes ignore untracked
files, so import-tree simply will not see it.

`nix flake check` is not wired up, but a full eval catches every module error:

```sh
nix eval .#nixosConfigurations.pc.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.t490.config.system.build.toplevel.drvPath
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
*across every layer it touches* - `modules/desktop/umbriel.nix` carries the compositor's NixOS
options, its overlay, the portal config and the `~/.config/umbriel` symlink together.

One file per domain, not per app - a new program joins the file its domain already owns:

| file | domain |
| --- | --- |
| `system.nix` | boot, nix settings, locale, networking, stateVersion |
| `hardware.nix` | GPU, firmware, audio, bluetooth, peripherals |
| `user.nix` | the account, home-manager wiring, the `dotfile` argument |
| `theming.nix` | GTK/Qt/cursor/icons, fonts |
| `desktop/session.nix` | noctalia, greetd, portals, screencast, voxtype, the wayland tool scripts |
| `desktop/umbriel.nix` | the compositor: umbriel |
| `shell.nix` | fish, monstar, foot, yazi, neovim, git |
| `dev.nix` | toolchain, playwright browsers, herdr, remote host bootstrap |
| `apps.nix` | browser, file manager, media, chat, art, notes |
| `vpn.nix` | the AmneziaVPN client, the boot-time tunnel, the greeter gate |
| `claude.nix`, `webapps.nix`, `gaming.nix` | each big enough to stand alone |

Nesting is cosmetic - import-tree walks the whole tree, so `modules/hosts/` groups files without
changing anything.

Modules are stored under these names and assembled in `modules/hosts/<host>.nix`:

- `flake.modules.nixos.base` - host-agnostic NixOS
- `flake.modules.nixos.<host>` - one machine's hardware (pc: NVIDIA, OpenRGB, DDC; t490: Intel, power)
- `flake.modules.homeManager.metsker` - the user's home on every host, wired in by `modules/user.nix`
- `flake.modules.homeManager.pc` - home config only the desktop wants (DDC brightness, OpenRGB),
  wired in by `modules/hosts/pc.nix`

A domain file may contribute to a host's names too - `hardware.nix` puts OpenRGB and DDC under
`nixos.pc` and `homeManager.pc` and the LACT GPU undervolt under `nixos.pc`, and `session.nix` its
NVIDIA-only gpu-screen-recorder overlay under `nixos.pc`, rather than in a host file, because they
belong to that file's domain.

Conventions that follow from this:

- `inputs` is in scope in every file; nothing is threaded through `specialArgs`.
- Home modules take a `dotfile` argument (`modules/user.nix`): `dotfile "umbriel"` is the
  out-of-store symlink to `config/umbriel`.
- A cachix substituter lives next to the input that needs it, not in one central list.
- Files whose path contains `_` are skipped by import-tree - that is why the generated
  `modules/hosts/_<host>-hardware.nix` files are not modules of their own.
- `patches/` - out-of-tree patches, applied by an overlay in the feature's own module.

### Scripts

`scripts/*.sh` are wrapped with `pkgs.writeShellApplication` in the owning module, with every dependency listed
in `runtimeInputs`. A script must never assume a binary is on PATH - add it to `runtimeInputs` instead.
`set -euo pipefail` and shellcheck are applied by the wrapper.

`scripts/wminfo.sh` is the only script that names a compositor. It answers six questions -
`boxes` (window rectangles for slurp), `focused-name`, `focused-window`,
`watch-focused-window`, `float-rules` and `float-rule` - and the wayland tools (`screenshot`,
`textpicker`, `clipboard`) plus noctalia's `window-info` plugin ask it instead of branching on
`XDG_CURRENT_DESKTOP` themselves.
A query the running compositor cannot answer returns nothing, and the caller decides what that
means: no boxes is no window snapping, no focused window is a hidden bar widget, no float rules is
a right-click that reports it changed nothing. The two window queries are the exception to that
silence - they exit nonzero when the IPC itself fails, so
a caller can tell that from an empty desktop. `float-rule` is the one query that writes: it edits
the compositor's own rule file and reloads it, because a float rule has to survive the window it
was read off.
Supporting another compositor is one more case block there.

`screenshot` and `textpicker` grab the whole screen the moment they start and crop that grab to the
selected region afterwards, rather than capturing once the region is drawn. On the NVIDIA blob an
output can end up without a cursor plane, and the compositor then composites the pointer into the
framebuffer, so every screencopy of that output carries it - umbriel hides it on the keypress
(`input.cursor.hide_when_typing`), which does not last past the mouse moving to select. wayfreeze is
only the still backdrop the region is drawn against.

### Overlays

Each overlay pins or patches an upstream package and carries a comment naming the
condition to drop it (a merged PR, a fixed issue). Keep that discipline: an overlay without an exit
condition becomes permanent.

## Desktop stack

One compositor, **umbriel**, with **noctalia** as the shell. Boot autologins into umbriel through
greetd's `initial_session` (in `session.nix`, next to the greeter it skips); the greeter is reached
by logging out.

noctalia is not part of the compositor's file - it lives in `modules/desktop/session.nix` on
`graphical-session.target`, which `start-umbriel`'s `umbriel.service` and `umbriel-session.target`
pull up. Adding another compositor means adding one file next to `umbriel.nix`.

- **umbriel** (`modules/desktop/umbriel.nix`). noctalia's own compositor, so the pairing needs no
  glue: its example config already carries noctalia's window and layer rules, and noctalia's
  `umbriel` theme template renders `~/.config/umbriel/noctalia.toml`, which `config.toml` pulls in
  through `[include]`. `config.toml` carries the include list, `[general]` and the odds and ends,
  and `input.toml`, `appearance.toml`, `layout.toml`, `rules.toml` and `keybinds.toml` carry the
  rest. `float-rules.toml` is written by `wminfo float-rule` and gitignored. Scrolling, dwindle and
  master layouts; nine static workspaces per output, reached as `workspace-switch:<n>/<output>`.
  `umbriel config validate` checks the config against the installed binary, and a rebuild only
  reaches the compositor after a re-login - until then its reload banner can flag keys the new
  binary accepts.
- **Per-host umbriel config.** Everything that names an output lives in
  `config/umbriel/hosts/<hostname>.toml`, included last by `config.toml` as `hosts/${HOSTNAME}.toml`:
  the `[output.*]` sections, the workspace binds, `general.autostart` with the `at_startup` rules
  that place those apps. The default
  `layout.mode` lives there too, though it names no output: scrolling on both hosts for now. `HOSTNAME` is
  a session variable `umbriel.nix` sets from `networking.hostName`, so it reaches umbriel's
  environment only after a re-login, and a host without a file fails to load loudly.
  `HOSTNAME=t490 umbriel config validate` checks another host's file. Connector names collide
  across hosts (the laptop has a DP-1 and HDMI-A-2 too), which is why none of this is shared.
  pc names its one monitor by identity (`"GWD ARZOPA 2022110200001"`) rather than connector, so
  moving it between DisplayPort ports keeps its settings and binds - the identity is per input,
  though: its HDMI input reports serial `0000001761630`; t490 pins Mod to eDP-1.
  `input.cursor.hide_when_typing` is on because pc's HDMI-A-2 gets no cursor plane from the NVIDIA
  blob - without it the composited pointer lands in every screenshot of that output.
- noctalia owns theming: its templates render color palettes into app configs at
  theme-switch time, and the rendered outputs are gitignored (`**/noctalia.*`, `**/themes/noctalia`).
  Edit the template (`config/noctalia/templates/`) or the noctalia settings, never the generated file.
  `config/umbriel/noctalia.toml` and `config/monstar/themes/noctalia` are generated. Its
  per-compositor features come from runtime detection, not from Nix: umbriel has a workspace
  backend, and a compositor it does not know falls to the `Unknown` path and shows no workspace
  module. `config/noctalia/settings.toml` is one file for both hosts - noctalia rewrites it at
  runtime, so it cannot be split; its per-output keys (lockscreen widgets, wallpapers) are inert on
  a host without that output.
- **monstar** is the terminal, built from a flake input. `modules/shell.nix` names it exactly
  once, in a file-level `terminal` binding, and spends that on `$TERMINAL` in
  `environment.sessionVariables` and on the two KDE keys - swapping terminals is that one edit.
  Both compositors' keybinds spawn `$TERMINAL`, which works because their `spawn`/`exec` go
  through `sh`; noctalia reads it too, its own discovery list ending at foot. KIO's launcher
  reads `kdeglobals` rather than the environment, so an activation script writes
  `TerminalApplication` and `TerminalService` there - unset, dolphin's "Open Terminal Here"
  falls through to an absent konsole and does nothing. A desktop entry's `Exec` is never
  shell-expanded, so entries needing a terminal set `Terminal=true` and let the launcher supply
  one instead of naming it. `SNACKS_GHOSTTY` is a session variable for the same reason: `-e nvim`
  starts no shell, and libghostty does not answer to the XTVERSION probe snacks.nvim gates on.
- `config/niri/` and `config/mango/` are inactive leftovers - neither compositor is installed.
  Do not treat them as live config or keep them in sync.

## Claude Code config

`modules/claude.nix` owns it all. MCP servers are declared in one `writeText` JSON and passed via a `claude`
wrapper (`--mcp-config=...`); do not add servers to `~/.claude.json`. `settings.json` is linked with
`ln -sf` in an activation script rather than `home.file`, because Claude Code rewrites it at runtime and
a read-only store symlink would break that. The tracked files live in `config/claude/`.

Mods (function-hook plugins) live in `config/claude/mods/`, one folder each, and are loaded by
`CLAUDE_CODE_PLUGIN_DIRS` in `settings.json`'s `env`, not by Nix, so they work on any machine and
hot-reload on save. `inline-images` draws a reply's `![alt](/abs/path)` lines as kitty graphics,
converting non-PNG files with `magick` from PATH; its `cellAspect` option (`pluginConfigs`) is the
terminal cell's height over width, since the mod API exposes no cell size. Claude Code only enables
those graphics when the terminal answers XTVERSION as kitty 0.28+ or Ghostty, which herdr does not,
so the same `env` sets `CLAUDE_CODE_FORCE_TERMINAL_IMAGES=1`.

## Conventions

- Commit messages follow `config/claude/skills/writing-commit-messages/SKILL.md`: kernel style,
  `subsystem: imperative summary`, a body only when the subject leaves a question
  open, and **no `Co-Authored-By` or attribution trailer**
  (this repo's rule overrides the default).
- Comments explain *why* a non-obvious workaround exists, and stay to one line per block.
