{ config, lib, pkgs, inputs, ... }:

{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.metsker = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.fish;
  };

  hardware.graphics.enable = true;

  # Redistributable firmware blobs for real BT/Wi-Fi/GPU hardware (no-op in VM).
  hardware.enableRedistributableFirmware = true;

  # Bluetooth stack; Noctalia's panel drives BlueZ directly, so no blueman needed.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true; # battery reporting + better BLE
  };

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  services.hardware.openrgb.enable = true;

  # PipeWire (ALSA + Pulse compat + Bluetooth A2DP); rtkit grants realtime priority.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  qt.enable = true;

  programs.niri.enable = true;

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
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
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

  system.stateVersion = "26.05";

  system.autoUpgrade = {
    enable = false; # Toggle on real machine
    dates = "weekly";
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 10d";
  };

  nix.settings.auto-optimise-store = true;
}
