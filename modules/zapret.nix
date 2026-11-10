{ inputs, ... }:

{
  # Zapret-Rust DPI bypass, TUI only - enable the flake's services.zapret-rust once autotune picks a strategy.
  flake.modules.nixos.base = { pkgs, ... }:
    let
      # The binary's own pkexec re-exec skips this wrapper and wipes its env, so elevate here first.
      zapret-rust = inputs.zapret-rust.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
        (_: {
          postInstall = ''
            wrapProgram $out/bin/zapret-rust \
              --run 'if [ "$EUID" != 0 ]; then exec /run/wrappers/bin/pkexec "$0" "$@"; fi' \
              --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [ coreutils curl iptables libcap nftables procps systemd which ])} \
              --set ZAPRET_CACHE_DIR /var/lib/zapret-rust
          '';
        });
    in
    {
      environment.systemPackages = [ zapret-rust ];
    };
}
