{
  # Everything that exists because of the metal: GPU, firmware, audio, bluetooth, peripherals.
  flake.modules.nixos.base = {
    hardware.graphics.enable = true;

    # Redistributable firmware blobs for BT/Wi-Fi/GPU hardware.
    hardware.enableRedistributableFirmware = true;

    # Pulls in hardware.logitech.wireless.enable (udev rules) by default.
    programs.solaar = {
      enable = true;
      # The module's own user service, rather than an autostart line in every compositor:
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
    # The seat ACL is revoked before the session stops, and ddc-brightness saves on the way out.
    users.users.metsker.extraGroups = [ "i2c" ];
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }:
    let
      # No backlight class on a desktop, so monitor brightness goes over DDC/CI. The wrapper
      # shadows ddcutil itself; everything but `detect` is passed straight through.
      ddcutil = pkgs.writeShellApplication {
        name = "ddcutil";
        runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.gnugrep ];
        runtimeEnv.DDCUTIL_REAL = "${pkgs.ddcutil}/bin/ddcutil";
        text = builtins.readFile ../scripts/ddcutil-connector-fix.sh;
      };

      ddc-brightness = pkgs.writeShellApplication {
        name = "ddc-brightness";
        runtimeInputs = [ ddcutil pkgs.coreutils pkgs.gawk ];
        text = builtins.readFile ../scripts/ddc-brightness.sh;
      };
    in
    {
      # A whole directory, not `recursive`: OpenRGB rewrites OpenRGB.json and drops a detection log
      # per start into this directory, which per-file store symlinks would make read-only.
      xdg.configFile.OpenRGB.source = dotfile "openrgb";

      # Noctalia loads effect presets over $XDG_RUNTIME_DIR/EasyEffectsServer, so the daemon has to be up.
      services.easyeffects.enable = true;

      home.packages = [ ddcutil ddc-brightness ];

      # Before noctalia, so its brightness service reads the restored values and never races us on i2c.
      systemd.user.services.ddc-brightness = {
        Unit = {
          Description = "Carry DDC monitor brightness across power cycles";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          Before = [ "noctalia.service" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${ddc-brightness}/bin/ddc-brightness restore";
          ExecStop = "${ddc-brightness}/bin/ddc-brightness save";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
