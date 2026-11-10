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
  };
}
