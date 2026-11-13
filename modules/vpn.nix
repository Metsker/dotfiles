{
  # The VPN: dae redirects every flow through eBPF, with no TUN device.
  flake.modules.nixos.base = {
    # The config holds the node's password, so it stays outside git and the store.
    services.dae = {
      enable = true;
      configFile = "/home/metsker/dotfiles/config/dae/config.dae";
      # tproxy_port is only spoken to by dae's own eBPF program, never by remote hosts.
      openFirewall.enable = false;
    };

    # Otherwise a reload re-reads the credential copied at start, not the edited file.
    systemd.services.dae.serviceConfig.RefreshOnReload = "credentials";

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
      stallmon = pkgs.writeShellApplication {
        name = "dae-stallmon";
        runtimeInputs = with pkgs; [ nftables iproute2 gawk curl coreutils findutils getent ];
        text = builtins.readFile ../scripts/dae-stallmon.sh;
      };
    in
    {
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

      # Temporary (stall test): the official hysteria client as a local SOCKS5 node for dae; drop with the test.
      systemd.services.hysteria-client = {
        description = "Official hysteria2 client as a SOCKS5 node for dae";
        before = [ "dae.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.hysteria} client --disable-update-check -c %d/config.yaml";
          LoadCredential = "config.yaml:/home/metsker/dotfiles/config/dae/hysteria-client.yaml";
          DynamicUser = true;
          Restart = "always";
          RestartSec = 3;
        };
      };
    };
}
