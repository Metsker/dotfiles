{ config, inputs, ... }:

{
  flake.modules.nixos.pc = { config, ... }: {
    imports = [ ./_pc-hardware.nix ];

    networking.hostName = "pc";

    boot.initrd.luks.devices."luks-da92cd42-5072-4b32-9bdb-cd6ab64ff710".device = "/dev/disk/by-uuid/da92cd42-5072-4b32-9bdb-cd6ab64ff710";

    services.xserver.videoDrivers = [ "nvidia" ];

    # Let i2c_piix4 claim the SMBus region ACPI reserves, so OpenRGB can see RAM RGB/SPD over SMBus.
    boot.kernelParams = [ "acpi_enforce_resources=lax" ];

    hardware.nvidia = {
      modesetting.enable = true;
      # Blackwell (the RTX 5060) runs only on the open kernel modules.
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
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
