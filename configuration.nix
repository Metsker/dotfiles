{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.noctalia-greeter.nixosModules.default
    inputs.mango.nixosModules.mango
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.extraModulePackages = with config.boot.kernelPackages; [ amneziawg ];

  # boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.luks.devices."luks-da92cd42-5072-4b32-9bdb-cd6ab64ff710".device = "/dev/disk/by-uuid/da92cd42-5072-4b32-9bdb-cd6ab64ff710";

  # Discord ignores SIGTERM on shutdown; cap the wait so reboots aren't stuck 90s.
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";

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

  users.users.metsker = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.fish;
  };

  hardware.graphics.enable = true;

  # Redistributable firmware blobs for BT/Wi-Fi/GPU hardware.
  hardware.enableRedistributableFirmware = true;

  # Bluetooth stack; Noctalia's panel drives BlueZ directly, so no blueman needed.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # settings.General.Experimental = true; # battery reporting + better BLE
  };

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [Logitech MX Anywhere 3S]
    MatchName=Logitech MX Anywhere 3S
    AttrEventCode=-REL_WHEEL_HI_RES;-REL_HWHEEL_HI_RES;
  '';

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

  programs.dconf.enable = true;

  programs.mango.enable = true;

  programs.gpu-screen-recorder.enable = true;

  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  xdg.portal.wlr.settings.screencast = {
    chooser_type = "simple";
    chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
  };

  programs.amnezia-vpn.enable = true;

  programs.noctalia-greeter = {
    enable = true;
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
    amneziawg-tools
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

  # ponytail: pin solaar 1.1.20; nixos-26.05 and unstable both still ship 1.1.19.
  # Drop this overlay once your channel ships >= 1.1.20 - track https://github.com/NixOS/nixpkgs/pull/536409
  nixpkgs.overlays = [
    (final: prev: {
      solaar = prev.solaar.overrideAttrs (old: rec {
        version = "1.1.20";
        src = prev.fetchFromGitHub {
          owner = "pwr-Solaar";
          repo = "Solaar";
          tag = version;
          hash = "sha256-h/uiy0TtMicKch2cdXHur5DkvQun2sAw2HpFI7Qstqg=";
        };
      });
    })
    # xdpw offers only 24-bit BG24 shm on NVIDIA GLES2; Chromium needs 32-bit - breaks Discord screenshare.
    # Patch = upstream PR 386 + XBGR/ABGR fallbacks. Drop when https://github.com/emersion/xdg-desktop-portal-wlr/issues/385 is fixed.
    # Second patch reverts 0.8.3 driver mode (PW_STREAM_FLAG_DRIVER): Chromium holds both pool buffers,
    # capture loop never re-arms - frozen after first frame. Drop when xdpw issue #395 / PR #397 lands.
    (final: prev: {
      xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/xdpw-shm-fallback-formats.diff
          ./patches/xdpw-revert-driver-mode.diff
        ];
      });
    })
  ];

  nix.settings.extra-substituters = [
    "https://noctalia.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  system.stateVersion = "26.05";

  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.settings.auto-optimise-store = true;
}
