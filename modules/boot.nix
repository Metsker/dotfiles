{
  flake.modules.nixos.base = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 5;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.initrd.systemd.enable = true;

    # Boot to black: plymouth cannot hand the display to mango without a visible repaint.
    boot.kernelParams = [ "quiet" ];

    # Console prints only emerg/alert/crit, so a fatal boot still says something.
    boot.consoleLogLevel = 3;

    # boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
