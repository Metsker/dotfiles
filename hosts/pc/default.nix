{ config, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "pc";

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
}
