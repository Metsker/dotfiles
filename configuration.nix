{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.noctalia-greeter.nixosModules.default
    inputs.mango.nixosModules.mango
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "omarchy";
    themePackages = [ (pkgs.callPackage ./plymouth/omarchy { }) ];
  };
  # Leave the last splash frame in the scanout buffer instead of restoring the text console,
  # so nothing repaints between plymouth quitting and mango's modeset.
  systemd.services.plymouth-quit.serviceConfig.ExecStart = [
    ""
    # keep upstream's "-": quitting a dead plymouth is not an activation failure
    "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
  ];
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [ "quiet" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ amneziawg ];

  # boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.luks.devices."luks-da92cd42-5072-4b32-9bdb-cd6ab64ff710".device = "/dev/disk/by-uuid/da92cd42-5072-4b32-9bdb-cd6ab64ff710";

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

  programs.mango = {
    enable = true;
    addLoginEntry = false; # uwsm-managed session entry only
  };

  # Runs mango under systemd user units: app scopes tear down cleanly, graphical-session.target works.
  programs.uwsm = {
    enable = true;
    waylandCompositors.mango = {
      prettyName = "Mango";
      comment = "Mango managed by uwsm";
      binPath = "/run/current-system/sw/bin/mango";
    };
  };

  programs.gpu-screen-recorder.enable = true;

  # GE-Proton is linked into ~/.local/share/Steam/compatibilitytools.d in home.nix,
  # which both steam and lutris scan, so no extraCompatPackages needed here.
  programs.steam.enable = true;

  programs.nh = {
    enable = true;
    flake = "/home/metsker/dotfiles";
  };

  xdg.portal.wlr.settings.screencast = {
    chooser_type = "simple";
    chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
  };

  programs.amnezia-vpn.enable = true;

  # Amnezia's "launch at startup" entry must exist (it gates launch-minimized), but mango's
  # autostart already launches the client gated on nm-online; mask the duplicate XDG unit.
  systemd.user.units."app-AmneziaVPN@autostart.service".enable = false;

  programs.noctalia-greeter = {
    enable = true;
  };

  # Electron apps (Discord) ignore SIGTERM and stall logout for 90s; SIGKILL them after 10s instead.
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

  # Auto-login into mango at boot (LUKS passphrase already gates access); greeter only shows after logout.
  services.greetd.settings.initial_session = {
    command = "uwsm start -F -- /run/current-system/sw/bin/mango";
    user = "metsker";
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
    PROTON_ENABLE_WAYLAND = "1";
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
    "https://monstar.cachix.org"
    "https://claude-code.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    "monstar.cachix.org-1:75M9ke+wZlmUcNsXpDae9793qhdRgtlNUEu/mW7u20c="
    "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
  ];

  system.stateVersion = "26.05";

  # system.autoUpgrade = {
  #   enable = true;
  #   dates = "weekly";
  # };

  nix.settings.auto-optimise-store = true;
}
