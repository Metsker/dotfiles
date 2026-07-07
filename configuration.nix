{ config, lib, pkgs, ... }:

{
  imports =
    [
      /etc/nixos/hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "lev";

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  users.users.metsker = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.fish;
    packages = with pkgs; [
      tree
    ];
  };

  hardware.graphics.enable = true;
  programs.niri.enable = true;
  programs.fish.enable = true;

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    alacritty
    git
  ];

  # Override NixOS's `EDITOR = mkDefault "nano"`; applies session-wide so
  # graphical apps (e.g. yazi's editor opener) inherit it too.
  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  system.stateVersion = "26.05";
}
