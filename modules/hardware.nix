{
  # Everything that exists because of the metal: GPU, firmware, audio, bluetooth, peripherals.
  flake.modules.nixos.base = {
    hardware.graphics.enable = true;

    # Redistributable firmware blobs for BT/Wi-Fi/GPU hardware.
    hardware.enableRedistributableFirmware = true;

    # Pulls in hardware.logitech.wireless.enable (udev rules) by default.
    programs.solaar = {
      enable = true;
      # The module's own user service, rather than an autostart line in all three compositors:
      # it restarts on failure and stops with the session, which a spawned process does not.
      userService.enable = true;
    };

    environment.etc."libinput/local-overrides.quirks".text = ''
      [Logitech MX Anywhere 3S]
      MatchName=Logitech MX Anywhere 3S
      AttrEventCode=-REL_WHEEL_HI_RES;-REL_HWHEEL_HI_RES;
    '';

    # PipeWire (ALSA + Pulse compat + Bluetooth A2DP); rtkit grants realtime priority.
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Noctalia's panel drives BlueZ directly, so no blueman needed.
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      # settings.General.Experimental = true; # battery reporting + better BLE
    };

    # Noctalia's battery readouts come over UPower; on this desktop that is the wireless peripherals.
    services.upower.enable = true;

    services.hardware.openrgb = {
      enable = true;
      # The server applies the profile itself once its own ~20s of device detection finishes -
      # which is all the old poll-then-launch script was doing from the outside.
      startupProfile = "carrot";
    };

    # The server reads profiles from its own state dir while the GUI writes them to the user's
    # config dir; a symlink keeps the file the GUI saves as the only copy.
    systemd.tmpfiles.rules = [
      "L+ /var/lib/OpenRGB/carrot.orp - - - - /home/metsker/.config/OpenRGB/carrot.orp"
    ];

    # ddcutil talks to the monitors over the GPU's i2c buses; this loads i2c-dev and
    # grants the seat user access, instead of leaning on OpenRGB's udev rules for it.
    hardware.i2c.enable = true;
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    # A whole directory, not `recursive`: OpenRGB rewrites OpenRGB.json and drops a detection log
    # per start into this directory, which per-file store symlinks would make read-only.
    xdg.configFile.OpenRGB.source = dotfile "openrgb";

    # Noctalia loads effect presets over $XDG_RUNTIME_DIR/EasyEffectsServer, so the daemon has to be up.
    services.easyeffects.enable = true;

    home.packages = [
      # No backlight class on a desktop, so monitor brightness goes over DDC/CI. The wrapper
      # shadows ddcutil itself; everything but `detect` is passed straight through.
      (pkgs.writeShellApplication {
        name = "ddcutil";
        runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.gnugrep ];
        runtimeEnv.DDCUTIL_REAL = "${pkgs.ddcutil}/bin/ddcutil";
        text = builtins.readFile ../scripts/ddcutil-connector-fix.sh;
      })
    ];
  };
}
