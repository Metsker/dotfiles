{ config, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "pc";

  services.xserver.videoDrivers = [ "nvidia" ];

  # Load NVIDIA KMS in initrd so noctalia greeter gets accelerated /dev/dri/card0 (not software simpledrm).
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
}
