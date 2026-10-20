{ config, inputs, ... }:

{
  flake.modules.nixos.pc = { config, pkgs, ... }: {
    imports = [ ./_pc-hardware.nix ];

    networking.hostName = "pc";

    boot.initrd.luks.devices."luks-da92cd42-5072-4b32-9bdb-cd6ab64ff710".device = "/dev/disk/by-uuid/da92cd42-5072-4b32-9bdb-cd6ab64ff710";

    services.xserver.videoDrivers = [ "nvidia" ];

    # Load NVIDIA KMS in initrd so noctalia greeter gets accelerated /dev/dri/card0 (not software simpledrm).
    boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    # Let i2c_piix4 claim the SMBus region ACPI reserves, so OpenRGB can see RAM RGB/SPD over SMBus.
    boot.kernelParams = [ "acpi_enforce_resources=lax" ];

    hardware.nvidia = {
      modesetting.enable = true;
      # Blackwell (the RTX 5060) runs only on the open kernel modules.
      open = true;
      # patchelf 0.19.2 overlaps nvidia-smi's first two load segments and ld.so segfaults on it; drop once a newer patchelf lays it out cleanly.
      package = config.boot.kernelPackages.nvidiaPackages.latest.overrideAttrs (old: {
        nativeBuildInputs = [
          (pkgs.patchelf.overrideAttrs {
            version = "0.15.2";
            src = pkgs.fetchurl {
              url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
              hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
            };
            doCheck = false;
          })
        ] ++ old.nativeBuildInputs;
      });
    };
  };

  flake.nixosConfigurations.pc = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      config.flake.modules.nixos.base
      config.flake.modules.nixos.pc
      { home-manager.users.metsker.imports = [ config.flake.modules.homeManager.pc ]; }
    ];
  };
}
