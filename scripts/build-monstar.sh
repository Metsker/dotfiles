#!/usr/bin/env bash
# Build monstar (rockorager's Zig/Wayland terminal) from source on NixOS.
# Zig cannot fetch deps.files.ghostty.org over TLS here, so those tarballs are
# pulled with nix and imported into zig's cache locally; the rest zig fetches.
set -euo pipefail

SRC="${MONSTAR_SRC:-$HOME/src/monstar}"
PREFIX="${MONSTAR_PREFIX:-$HOME/.local}"
CACHE="$SRC/.zig-global-cache"
GCROOTS="$PREFIX/state/monstar-libs"

# build-time tools (compilers, scanners, dev libs for pkg-config)
TOOLS=(zig_0_16 cacert git nix wayland-scanner wayland-protocols pkg-config
       wayland libxkbcommon fontconfig freetype harfbuzz dbus)
# runtime libs the binary needs on LD_LIBRARY_PATH (NixOS has no /usr/lib)
RUNTIME=(wayland libxkbcommon fontconfig freetype harfbuzz dbus libglvnd mesa)

# fetch or update source
if [ -d "$SRC/.git" ]; then git -C "$SRC" pull --ff-only; else
  git clone https://github.com/rockorager/monstar "$SRC"; fi
cd "$SRC"

# build, importing any tarballs zig cannot fetch into its cache, then retry
nix-shell -p "${TOOLS[@]}" --run '
  set -euo pipefail
  export SSL_CERT_FILE="$NIX_SSL_CERT_FILE"
  export ZIG_GLOBAL_CACHE_DIR="'"$CACHE"'"
  mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
  for _ in 1 2 3 4 5; do
    if zig build -Doptimize=ReleaseFast --prefix "'"$PREFIX"'" >build.log 2>&1; then
      echo "build ok"; exit 0; fi
    mapfile -t urls < <(grep -oE "https?://[^\"]+" build.log | sort -u)
    [ "${#urls[@]}" -eq 0 ] && { cat build.log; exit 1; }
    echo "importing ${#urls[@]} deps zig could not fetch..."
    for u in "${urls[@]}"; do
      p=$(nix-prefetch-url --print-path "$u" 2>/dev/null | tail -1)
      zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "$p" >/dev/null
    done
  done
  echo "still failing after retries:"; cat build.log; exit 1
'

# gc-root the runtime libs (survives nix-collect-garbage) and bake LD_LIBRARY_PATH
mkdir -p "$GCROOTS" "$PREFIX/libexec"
LD=$(nix-shell -p "${RUNTIME[@]}" --run '
  i=0; out=""
  for p in $buildInputs; do
    nix-store --add-root "'"$GCROOTS"'/lib-$i" -r "$p" >/dev/null
    out="$out$p/lib:"; i=$((i+1))
  done
  printf "%s" "${out%:}"')

# install the real binary under libexec, wrap it with the baked lib path
mv "$PREFIX/bin/monstar" "$PREFIX/libexec/monstar"
cat > "$PREFIX/bin/monstar" <<EOF
#!/bin/sh
export LD_LIBRARY_PATH="$LD\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$PREFIX/libexec/monstar" "\$@"
EOF
chmod +x "$PREFIX/bin/monstar"

echo "installed: $PREFIX/bin/monstar ($($PREFIX/bin/monstar --version))"
