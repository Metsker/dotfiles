{
  flake.modules.nixos.base.services.hardware.openrgb.enable = true;

  flake.modules.homeManager.metsker = { pkgs, ... }: {
    # Waits out the OpenRGB SDK server's device detection, then applies the named profile.
    home.packages = [
      (pkgs.writeShellApplication {
        name = "openrgb-profile";
        runtimeInputs = [ pkgs.openrgb ];
        text = builtins.readFile ../../scripts/openrgb-profile.sh;
      })
    ];
  };
}
