{ inputs, ... }:

{
  # Zapret-Rust bypasses DPI for Discord/YouTube by steering traffic through nfqws in nftables.
  # The upstream package is the TUI; running it needs root, which the wrapper arranges through
  # polkit. The flake also ships a NixOS module for running it as a systemd service - enable
  # services.zapret-rust once autotune has picked an interface and strategy that work here.
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [
      inputs.zapret-rust.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
