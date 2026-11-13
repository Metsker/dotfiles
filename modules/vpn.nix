{
  # The VPN: dae redirects every flow through eBPF, with no TUN device.
  flake.modules.nixos.base = { config, lib, ... }: {
    # The config holds the node's password, so it stays outside git and the store.
    services.dae = {
      enable = true;
      configFile = "/home/metsker/dotfiles/config/dae/config.dae";
      # tproxy_port is only spoken to by dae's own eBPF program, never by remote hosts.
      openFirewall.enable = false;
    };

    # Otherwise a reload re-reads the credential copied at start, not the edited file.
    systemd.services.dae = lib.mkIf config.services.dae.enable { serviceConfig.RefreshOnReload = "credentials"; };

    # Drop once dae's hysteria2 client survives paused downloads.
    nixpkgs.overlays = [
      (final: prev: {
        dae = prev.dae.overrideAttrs (old: {
          # proxyVendor keeps dependencies as zips, so each module is unpacked, patched and swapped in by a replace.
          postConfigure = (old.postConfigure or "") + ''
            patchModule() {
              go mod download "$1"
              cp -r "$(go list -m -f '{{.Dir}}' "$1")" "$NIX_BUILD_TOP/$2"
              chmod -R u+w "$NIX_BUILD_TOP/$2"
              patch -d "$NIX_BUILD_TOP/$2" -p1 < "$3"
              go mod edit -replace "$1=$NIX_BUILD_TOP/$2"
            }
            patchModule github.com/daeuniverse/outbound outbound ${../patches/dae-hysteria2-conn-window.patch}
          '';
        });
      })
    ];
  };

  flake.modules.nixos.pc = { lib, pkgs, ... }:
    let
      # Trial: mihomo replaces dae on pc, needing no patches; set this to "dae" and rebuild to go back.
      tunnel = "mihomo";
      stallmon = pkgs.writeShellApplication {
        name = "dae-stallmon";
        runtimeInputs = with pkgs; [ nftables iproute2 gawk curl coreutils findutils getent ];
        text = builtins.readFile ../scripts/dae-stallmon.sh;
      };
    in
    {
      services.dae.enable = lib.mkForce (tunnel == "dae");

      # The config holds the node's password, so it stays outside git and the store.
      services.mihomo = {
        enable = tunnel == "mihomo";
        configFile = "/home/metsker/dotfiles/config/mihomo/config.yaml";
        tunMode = true;
        # The PROCESS-NAME rule has to see other users' processes.
        processesInfo = true;
      };

      # mihomo looks for rule data only in its state directory, so the files dae already uses are linked there.
      systemd.services.mihomo.serviceConfig.ExecStartPre = lib.mkIf (tunnel == "mihomo") [
        "${pkgs.coreutils}/bin/ln -sfn ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat /var/lib/private/mihomo/geoip.dat"
        "${pkgs.coreutils}/bin/ln -sfn ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat /var/lib/private/mihomo/geosite.dat"
      ];

      # mihomo's TCP stack accepts flows on its tunnel device, and replies to its own sockets fail a strict reverse-path check.
      networking.firewall = lib.mkIf (tunnel == "mihomo") {
        trustedInterfaces = [ "mihomo" ];
        checkReversePath = "loose";
      };

      # Temporary: per-second tunnel counters in /var/log/dae-stallmon; drop once the stalls are understood.
      systemd.services.dae-stallmon = {
        description = "Log per-second dae tunnel counters";
        after = [ "dae.service" ];
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
