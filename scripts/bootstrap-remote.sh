# Provision a Debian host over SSH with the same herdr and neovim this machine runs.
#
#   bootstrap-remote raspberrypi vps-main
#
# herdr's client refuses a server whose version differs, so the pinned HERDR_VERSION
# below must track pkgs.herdr - bump both together, with the hashes from
# https://herdr.dev/latest.json (.releases.<version>.sha256).
#
# Re-runnable: every step is a no-op once the pinned version is already in place.
# A TTY is allocated because apt may need to prompt for a sudo password.

if [ "$#" -eq 0 ]; then
  echo "usage: bootstrap-remote <ssh-host> [<ssh-host>...]" >&2
  exit 64
fi

for host in "$@"; do
  printf '\n==> %s\n' "$host"

  ssh "$host" 'mkdir -p "$HOME/.cache" && cat > "$HOME/.cache/bootstrap-remote.sh"' <<'PAYLOAD'
#!/bin/sh
# Runs on the remote host under Debian's /bin/sh - keep it POSIX.
set -eu

HERDR_VERSION=0.8.0
HERDR_SHA256_X86_64=b872ea7e40fa2cb17e857ac9b62b1bf26db7b403c622f5d2f3f5b35f6e9acd28
HERDR_SHA256_AARCH64=f647ac66468d9efbc642fe534fb284468f0aea60641606fc008dfc0d82a3ca87

# Neovim publishes no checksum asset, so these are pinned from a local download.
NVIM_VERSION=0.12.4
NVIM_SHA256_X86_64=012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628
NVIM_SHA256_ARM64=ceb7e88c6b681f0515d135dcdfad54f5eb4373b25ce6172197cd9a69c758063f

# nvim-treesitter's main branch shells out to `tree-sitter build`, and Debian only
# carries 0.22, far too old for it. Mirrors pkgs.tree-sitter; any recent CLI works.
TS_CLI_VERSION=0.26.9
TS_CLI_SHA256_X64=9ce82137caa65864e7ca8b869fd391cef88c9bd2a01c4371b9c4dd26c2585efb
TS_CLI_SHA256_ARM64=c8feeb32115958cb44442ca4d68f6d66cf7605dbd65681e62342181ebdd6db3b

NVIM_CONFIG_REPO=https://github.com/Metsker/nvim

BIN="$HOME/.local/bin"
mkdir -p "$BIN"
# nvim has to find tree-sitter during the plugin pass, and a non-interactive SSH
# shell does not pick up the login PATH this script appends to further down.
PATH="$BIN:$PATH"
export PATH

case "$(uname -m)" in
  x86_64|amd64)
    herdr_asset=linux-x86_64; herdr_sha=$HERDR_SHA256_X86_64
    nvim_asset=linux-x86_64;  nvim_sha=$NVIM_SHA256_X86_64
    ts_asset=linux-x64;       ts_sha=$TS_CLI_SHA256_X64
    ;;
  aarch64|arm64)
    herdr_asset=linux-aarch64; herdr_sha=$HERDR_SHA256_AARCH64
    nvim_asset=linux-arm64;    nvim_sha=$NVIM_SHA256_ARM64
    ts_asset=linux-arm64;      ts_sha=$TS_CLI_SHA256_ARM64
    ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

step() { printf '  - %s\n' "$1"; }

# --- system packages ---------------------------------------------------------
# curl, git and a compiler are hard requirements; the rest only sharpen the picker.
# Splitting them keeps a host with no usable sudo installable, minus the extras.
missing=
for pair in curl:curl git:git cc:build-essential rg:ripgrep fdfind:fd-find unzip:unzip; do
  cmd=${pair%%:*}
  pkg=${pair#*:}
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $pkg"
done

if [ -n "$missing" ]; then
  if [ "$(id -u)" -eq 0 ]; then
    sudo=
  elif sudo -n true 2>/dev/null || [ -t 0 ]; then
    sudo=sudo
  else
    sudo=unavailable
  fi

  if [ "$sudo" = unavailable ]; then
    case "$missing" in
      *curl*|*git*|*build-essential*)
        echo "need$missing but sudo cannot prompt without a terminal" >&2
        exit 1
        ;;
    esac
    step "skipping optional packages ($missing) - no usable sudo; re-run from a terminal"
  else
    step "apt install:$missing"
    # One unreachable third-party source must not block a package from the Debian
    # repos, and update reports failure for the whole run - so let install decide.
    # shellcheck disable=SC2086
    $sudo apt-get update -qq || step "  some apt sources failed to refresh - continuing"
    # shellcheck disable=SC2086
    $sudo apt-get install -y -qq $missing
  fi
else
  step "system packages already present"
fi

# Debian ships fd as fdfind; snacks.picker looks for either, this keeps `fd` usable too.
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sfn "$(command -v fdfind)" "$BIN/fd"
fi

# --- herdr -------------------------------------------------------------------
if [ "$("$BIN/herdr" --version 2>/dev/null | awk '{print $2}')" = "$HERDR_VERSION" ]; then
  step "herdr $HERDR_VERSION already installed"
else
  step "installing herdr $HERDR_VERSION ($herdr_asset)"
  tmp=$(mktemp -d)
  curl -fsSL --retry 3 -o "$tmp/herdr" \
    "https://github.com/herdrdev/herdr/releases/download/v$HERDR_VERSION/herdr-$herdr_asset"
  echo "$herdr_sha  $tmp/herdr" | sha256sum -c - >/dev/null
  install -m 755 "$tmp/herdr" "$BIN/herdr"
  rm -rf "$tmp"
fi

# --- neovim ------------------------------------------------------------------
nvim_dir="$HOME/.local/share/nvim-dist/$NVIM_VERSION"
if [ -x "$nvim_dir/bin/nvim" ]; then
  step "neovim $NVIM_VERSION already installed"
else
  step "installing neovim $NVIM_VERSION ($nvim_asset)"
  tmp=$(mktemp -d)
  curl -fsSL --retry 3 -o "$tmp/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/nvim-$nvim_asset.tar.gz"
  echo "$nvim_sha  $tmp/nvim.tar.gz" | sha256sum -c - >/dev/null
  mkdir -p "$nvim_dir"
  tar -xzf "$tmp/nvim.tar.gz" -C "$nvim_dir" --strip-components=1
  rm -rf "$tmp"
fi
ln -sfn "$nvim_dir/bin/nvim" "$BIN/nvim"

# --- tree-sitter cli ---------------------------------------------------------
if [ "$("$BIN/tree-sitter" --version 2>/dev/null | awk '{print $2}')" = "$TS_CLI_VERSION" ]; then
  step "tree-sitter $TS_CLI_VERSION already installed"
else
  step "installing tree-sitter $TS_CLI_VERSION ($ts_asset)"
  tmp=$(mktemp -d)
  curl -fsSL --retry 3 -o "$tmp/ts.gz" \
    "https://github.com/tree-sitter/tree-sitter/releases/download/v$TS_CLI_VERSION/tree-sitter-$ts_asset.gz"
  echo "$ts_sha  $tmp/ts.gz" | sha256sum -c - >/dev/null
  gunzip -c "$tmp/ts.gz" > "$tmp/tree-sitter"
  install -m 755 "$tmp/tree-sitter" "$BIN/tree-sitter"
  rm -rf "$tmp"
fi

# --- neovim config -----------------------------------------------------------
nvim_config="$HOME/.config/nvim"
if [ -d "$nvim_config/.git" ]; then
  step "updating $nvim_config"
  git -C "$nvim_config" pull --ff-only --quiet || step "  (not fast-forwardable, left as is)"
elif [ -e "$nvim_config" ]; then
  step "$nvim_config exists and is not a git checkout - left alone"
else
  step "cloning $NVIM_CONFIG_REPO"
  git clone --quiet --depth 1 "$NVIM_CONFIG_REPO" "$nvim_config"
fi

# --- herdr config ------------------------------------------------------------
# `herdr --remote` sends the local keybindings, so these only apply when herdr is
# started from an SSH shell on this host.
mkdir -p "$HOME/.config/herdr"
cat > "$HOME/.config/herdr/config.toml" <<'TOML'
onboarding = false

[keys]
prefix = "ctrl+s"
navigate_workspace_up = "p"
navigate_workspace_down = "n"

[terminal]
new_cwd = "follow"

[ui.sound]
enabled = false

[ui]
agent_panel_sort = "priority"

[theme]
name = "terminal"
auto_switch = false

[experimental]
kitty_graphics = true

# The pinned binary has to match the client, so never self-update.
[update]
version_check = false
TOML
step "wrote ~/.config/herdr/config.toml"

# --- PATH --------------------------------------------------------------------
# herdr finds ~/.local/bin/herdr without this, but nvim and fd need it on a plain login.
path_line='export PATH="$HOME/.local/bin:$PATH"'
for rc in "$HOME/.profile" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  grep -qF "$path_line" "$rc" || printf '\n# added by bootstrap-remote\n%s\n' "$path_line" >> "$rc"
done

# --- plugins -----------------------------------------------------------------
# vim.pack clones synchronously on first start, but nvim-treesitter compiles its
# parsers on a background queue that the config kicks off and never waits for, so
# a plain `nvim --headless +qa` quits with nothing built. install() does hand back
# a waitable handle, and nothing keeps it - so wrap require to grab the handle
# before the config runs, then wait on it once startup is done. Compiling ~20
# parsers takes several minutes, more on a Pi.
step "fetching neovim plugins and compiling treesitter parsers (several minutes)"

hook_lua=$(mktemp)
cat > "$hook_lua" <<'LUA'
-- --cmd runs before plugin/ files, so this lands ahead of the install() call
_G.__ts_handles = {}
local base = require
_G.require = function(name)
  local mod = base(name)
  if name == 'nvim-treesitter' and not _G.__ts_hooked then
    _G.__ts_hooked = true
    local install = mod.install
    mod.install = function(...)
      local handle = install(...)
      table.insert(_G.__ts_handles, handle)
      return handle
    end
  end
  return mod
end
LUA

wait_lua=$(mktemp)
cat > "$wait_lua" <<'LUA'
for _, handle in ipairs(_G.__ts_handles or {}) do
  pcall(function() handle:wait(2400000) end)
end
local built = vim.fn.glob(vim.fn.stdpath('data') .. '/site/parser/*.so', false, true)
io.write(string.format('  - treesitter parsers installed: %d\n', #built))
if #_G.__ts_handles == 0 then
  io.write('  - no treesitter install call seen - config may have changed\n')
end
LUA

if ! "$BIN/nvim" --headless --cmd "luafile $hook_lua" -c "luafile $wait_lua" -c qa 2>/dev/null; then
  step "  plugin bootstrap reported errors - open nvim once by hand"
fi
rm -f "$hook_lua" "$wait_lua"

printf '  done: herdr %s, neovim %s\n' \
  "$("$BIN/herdr" --version | awk '{print $2}')" \
  "$("$BIN/nvim" --version | head -1 | awk '{print $2}')"
PAYLOAD

  ssh -t "$host" 'sh "$HOME/.cache/bootstrap-remote.sh"'
done
