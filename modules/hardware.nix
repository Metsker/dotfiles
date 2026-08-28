{
  # Everything that exists because of the metal: GPU, firmware, audio, bluetooth, peripherals.
  flake.modules.nixos.base = {
    hardware.graphics.enable = true;

    # Redistributable firmware blobs for BT/Wi-Fi/GPU hardware.
    hardware.enableRedistributableFirmware = true;

    # Pulls in hardware.logitech.wireless.enable (udev rules) by default.
    programs.solaar.enable = true;

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

    services.hardware.openrgb.enable = true;

    # ddcutil talks to the monitors over the GPU's i2c buses; this loads i2c-dev and
    # grants the seat user access, instead of leaning on OpenRGB's udev rules for it.
    hardware.i2c.enable = true;
  };

  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = [
      # No backlight class on a desktop, so monitor brightness goes over DDC/CI. The wrapper
      # shadows ddcutil itself; everything but `detect` is passed straight through.
      (pkgs.writeShellApplication {
        name = "ddcutil";
        runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.gnugrep ];
        runtimeEnv.DDCUTIL_REAL = "${pkgs.ddcutil}/bin/ddcutil";
        text = builtins.readFile ../scripts/ddcutil-connector-fix.sh;
      })
      # Waits out the OpenRGB SDK server's device detection, then applies the named profile.
      (pkgs.writeShellApplication {
        name = "openrgb-profile";
        runtimeInputs = [ pkgs.openrgb ];
        text = builtins.readFile ../scripts/openrgb-profile.sh;
      })
      (pkgs.writeShellApplication {
        name = "solaar-start";
        runtimeInputs = [ pkgs.solaar ];
        text = builtins.readFile ../scripts/solaar-start.sh;
      })
    ];
  };
}
