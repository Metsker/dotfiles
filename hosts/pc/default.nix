{ config, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "pc";

  services.xserver.videoDrivers = [ "nvidia" ];

  # Load NVIDIA KMS in initrd so noctalia greeter gets accelerated /dev/dri/card0 (not software simpledrm).
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # Let i2c_piix4 claim the SMBus region ACPI reserves, so OpenRGB can see RAM RGB/SPD over SMBus.
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
}
