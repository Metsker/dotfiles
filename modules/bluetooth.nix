{
  # Bluetooth stack; Noctalia's panel drives BlueZ directly, so no blueman needed.
  flake.modules.nixos.base.hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # settings.General.Experimental = true; # battery reporting + better BLE
  };
}
