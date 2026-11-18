{
  # The VPN: mihomo routes every flow through its TUN device and picks the path by rule.
  flake.modules.nixos.base = { pkgs, ... }: {
    # The config holds the node's password, so it stays outside git and the store.
    services.mihomo = {
      enable = true;
      configFile = "/home/metsker/dotfiles/config/mihomo/config.yaml";
      tunMode = true;
      # The PROCESS-NAME rule has to see other users' processes.
      processesInfo = true;
    };

    # mihomo looks for rule data only in its state directory, so the v2fly files are linked there.
    systemd.services.mihomo.serviceConfig.ExecStartPre = [
      "${pkgs.coreutils}/bin/ln -sfn ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat /var/lib/private/mihomo/geoip.dat"
      "${pkgs.coreutils}/bin/ln -sfn ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat /var/lib/private/mihomo/geosite.dat"
    ];

    # mihomo's TCP stack accepts flows on its tunnel device, and replies to its own sockets fail a strict reverse-path check.
    networking.firewall = {
      trustedInterfaces = [ "mihomo" ];
      checkReversePath = "loose";
    };
  };

  flake.modules.nixos.pc = { lib, pkgs, ... }:
    let
      stallmon = pkgs.writeShellApplication {
        name = "dae-stallmon";
        runtimeInputs = with pkgs; [ nftables iproute2 gawk curl coreutils findutils getent ];
        text = builtins.readFile ../scripts/dae-stallmon.sh;
      };
    in
    {
      # Temporary: per-second tunnel counters in /var/log/dae-stallmon; drop once the hop silences are understood.
      systemd.services.dae-stallmon = {
        description = "Log per-second tunnel counters";
        after = [ "mihomo.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = lib.getExe stallmon;
          ExecStopPost = "-${pkgs.nftables}/bin/nft delete table inet dae_stallmon";
          LogsDirectory = "dae-stallmon";
          Restart = "on-failure";
          RestartSec = 10;
        };
      };
    };
}
