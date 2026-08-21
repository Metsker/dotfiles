{
  # Everything that exists because of the metal: GPU, firmware, audio, bluetooth, peripherals.
  flake.modules.nixos.base = {
    hardware.graphics.enable = true;

    # Redistributable firmware blobs for BT/Wi-Fi/GPU hardware.
    hardware.enableRedistributableFirmware = true;

    hardware.logitech.wireless = {
      enable = true;
      enableGraphical = true;
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

    services.hardware.openrgb.enable = true;
  };

  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = [
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
