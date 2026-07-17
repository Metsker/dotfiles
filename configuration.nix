{ config, lib, pkgs, inputs, ... }:

{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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
  };

  hardware.graphics.enable = true;

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  services.hardware.openrgb.enable = true;

  qt.enable = true;

  programs.niri.enable = true;

  # Login screen: greetd + Noctalia greeter. `--session niri` is only the
  # default selection; the greeter shows a picker listing every WM/compositor
  # you enable, so future WMs appear automatically with no greeter changes.
  programs.noctalia-greeter = {
    enable = true;
    greeter-args = "--session niri";
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = "set -g fish_greeting";
  };

  environment.systemPackages = with pkgs; [
    neovim
    wget
    foot
    git
  ];

  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  nix.settings.extra-substituters = [
    "https://noctalia.cachix.org"
    "https://herdr-nix.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    "herdr-nix.cachix.org-1:+AT7TY8E6j/Pe9lB8Vjmp15Y4RPb8YtOnOwr/fboDS8="
  ];

  # This machine only has ~3.8 GiB RAM. When a flake input (e.g. an uncached
  # noctalia bump) has to compile from source, parallel C++ builds exhaust
  # memory and the OOM killer takes down whatever runs in the session cgroup
  # (i.e. the terminal). Compressed RAM swap plus capped build parallelism
  # keep from-source rebuilds within budget.
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };
  nix.settings.max-jobs = 1;
  nix.settings.cores = 2;

  system.stateVersion = "26.05";
}
