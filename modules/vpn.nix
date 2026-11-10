{
  # The VPN across every layer it touches: the client, the tunnel, and the greeter gate.
  #
  # AmneziaVPN's GUI can only connect once a graphical session exists, which is backwards for
  # autostart - everything a session launches wants the tunnel already up. So the tunnel is a
  # system unit reading a conf exported from the client, and the GUI is a management tool rather
  # than part of the boot path.
  flake.modules.nixos.base = { config, pkgs, ... }: {
    # Still where servers get picked and clients re-issued; re-export amn0.conf after either.
    programs.amnezia-vpn.enable = true;

    # awg-quick's add_if takes the kernel path whenever creating the link succeeds, which is what
    # we want: the module implements the same I1-I5/S1-S4/H1-H4 generation as the tools and does
    # the crypto in kernel. The client ships its own amneziawg-go and ignores it.
    boot.extraModulePackages = [ config.boot.kernelPackages.amneziawg ];

    # The client's own export directory; the conf carries a private key, so it stays out of the
    # repo. The client omits MTU from its exports and awg-quick then derives route_mtu - 80 =
    # 1420, which blackholes into a tunnel that connects and crawls - put MTU = 1376 back after
    # every re-export.
    systemd.services.amneziawg-amn0 = {
      description = "AmneziaWG tunnel";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ amneziawg-tools iproute2 nftables iptables procps systemd ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # A VPN that will not come up has to delay login, never prevent it.
        TimeoutStartSec = "30s";
        ExecStart = "${pkgs.amneziawg-tools}/bin/awg-quick up /etc/amnezia/amneziawg/amn0.conf";
        ExecStop = "${pkgs.amneziawg-tools}/bin/awg-quick down /etc/amnezia/amneziawg/amn0.conf";
      };
    };

    # Wants, not requires: a dead tunnel costs the 30s above, it does not lock the greeter away.
    systemd.services.greetd = {
      wants = [ "amneziawg-amn0.service" ];
      after = [ "amneziawg-amn0.service" ];
    };

    # systemd.user.units."app-AmneziaVPN@autostart.service".enable = false;
		
    services.v2raya = {
      enable = true;
      cliPackage = pkgs.sing-box;
    };


    environment.systemPackages = with pkgs; [ amneziawg-tools termius v2rayn ];
  };
}
