{
  # Boot, nix, locale, networking - the plumbing that has nothing to do with any app.
  flake.modules.nixos.base = { pkgs, ... }: {
    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 5;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.initrd.systemd.enable = true;

    # Boot to black: plymouth cannot hand the display to mango without a visible repaint.
    boot.kernelParams = [ "quiet" ];

    # Console prints only emerg/alert/crit, so a fatal boot still says something.
    boot.consoleLogLevel = 3;

    # boot.kernelPackages = pkgs.linuxPackages_latest;

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.auto-optimise-store = true;

    nixpkgs.config.allowUnfree = true;

    programs.nh = {
      enable = true;
      flake = "/home/metsker/dotfiles";
    };

    networking.networkmanager.enable = true;

    time.timeZone = "Europe/Amsterdam";

    i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };

    environment.systemPackages = [ pkgs.wget ];

    programs.ssh.startAgent = true;

    system.stateVersion = "26.05";

    # system.autoUpgrade = {
    #   enable = true;
    #   dates = "weekly";
    # };
  };

  flake.modules.homeManager.metsker = {
    home.stateVersion = "26.05";
  };
}
