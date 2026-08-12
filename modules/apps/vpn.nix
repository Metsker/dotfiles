{
  flake.modules.nixos.base = { config, pkgs, ... }: {
    programs.amnezia-vpn.enable = true;

    boot.extraModulePackages = with config.boot.kernelPackages; [ amneziawg ];

    environment.systemPackages = [ pkgs.amneziawg-tools ];

    # Amnezia's "launch at startup" entry must exist (it gates launch-minimized), but mango's
    # autostart already launches the client gated on nm-online; mask the duplicate XDG unit.
    systemd.user.units."app-AmneziaVPN@autostart.service".enable = false;
  };
}
