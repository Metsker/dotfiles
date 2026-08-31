#!/usr/bin/env bash
# Refresh the gitignored upstream clones under config/noctalia/refs, then re-copy the
# Luau type definitions that luau-lsp reads from the plugins directory.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
refs_dir="$repo_root/config/noctalia/refs"
plugins_dir="$repo_root/config/noctalia/plugins"

repos=(
  "official-plugins https://github.com/noctalia-dev/official-plugins.git"
  "noctalia-docs https://github.com/noctalia-dev/noctalia-docs.git"
  "noctalia https://github.com/noctalia-dev/noctalia.git"
)

mkdir -p "$refs_dir"

for entry in "${repos[@]}"; do
  read -r name url <<<"$entry"
  target="$refs_dir/$name"
  if [[ -d "$target/.git" ]]; then
    echo "==> updating $name"
    git -C "$target" fetch --depth 1 origin HEAD
    git -C "$target" reset --hard FETCH_HEAD
  else
    echo "==> cloning $name"
    git clone --depth 1 --filter=blob:none "$url" "$target"
  fi
done

# The definitions are tracked in this repo so the language server keeps working
# on a fresh checkout, before refs/ has been populated.
cp "$refs_dir/official-plugins/noctalia.d.luau" "$plugins_dir/noctalia.d.luau"
cp "$refs_dir/official-plugins/.luaurc" "$plugins_dir/.luaurc"

# kCurrentPluginApiVersion is an alias for the newest named level, so resolve it to
# the number a plugin.toml would actually declare.
api_header="$refs_dir/noctalia/src/scripting/plugin_api.h"
oldest=$(grep -oP 'kOldestSupportedPluginApiVersion = \K[0-9]+' "$api_header")
newest_alias=$(grep -oP 'kCurrentPluginApiVersion = \K\w+' "$api_header")
newest=$(grep -oP "$newest_alias = \K[0-9]+" "$api_header")
echo "==> plugin API accepted by the noctalia source at refs/noctalia: $oldest to $newest"
