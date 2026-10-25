{ config, inputs, ... }:

{
  flake.modules.nixos.t490 = { pkgs, ... }: {
    imports = [ ./_t490-hardware.nix inputs.disko.nixosModules.disko ];

    # nixos-anywhere formats this layout; the LUKS passphrase is read from passwordFile only at install time.
    disko.devices.disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              passwordFile = "/tmp/secret.key";
              settings.allowDiscards = true;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };

    # No swap partition: zram covers memory pressure without a second LUKS container.
    zramSwap.enable = true;

    networking.hostName = "t490";

    # VA-API on the UHD 620 needs the iHD driver; Mesa alone gives no hardware video decode.
    hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

    # The embedded controller drops the CPU's power limit under load; throttled keeps resetting it.
    services.throttled.enable = true;

    # Noctalia's power profile switch talks to power-profiles-daemon over D-Bus.
    services.power-profiles-daemon.enable = true;

    # ThinkPad BIOS and Thunderbolt firmware ship through LVFS, so updates need no Windows.
    services.fwupd.enable = true;
  };

  flake.nixosConfigurations.t490 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      config.flake.modules.nixos.base
      config.flake.modules.nixos.t490
    ];
  };
}
