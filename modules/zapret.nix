{ inputs, ... }:

{
  # Zapret-Rust bypasses DPI for Discord/YouTube by steering traffic through nfqws in nftables.
  # The upstream package is the TUI; the flake also ships a NixOS module for running it as a
  # systemd service. This installs the TUI now - enable services.zapret-rust once autotune has
  # picked a strategy that works here.
  flake.modules.nixos.base = { pkgs, ... }:
    let
      # Two packaging bugs on NixOS: the wrapper prepends pkgs.polkit's pkexec, which is not
      # setuid and shadows /run/wrappers/bin/pkexec, and it leaves the cache in the read-only
      # store. Suffix polkit instead, and default the cache to the service's writable state dir.
      zapret-rust = inputs.zapret-rust.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
        (_: {
          postInstall = ''
            wrapProgram $out/bin/zapret-rust \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nftables ]} \
              --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.polkit ]} \
              --set ZAPRET_CACHE_DIR /var/lib/zapret-rust
          '';
        });
    in
    {
      environment.systemPackages = [ zapret-rust ];
    };
}
