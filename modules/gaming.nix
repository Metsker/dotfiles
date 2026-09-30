{
  flake.modules.nixos.base = {
    # GE-Proton is linked into ~/.local/share/Steam/compatibilitytools.d below,
    # which both steam and lutris scan, so no extraCompatPackages needed here.
    programs.steam.enable = true;

    environment.sessionVariables.PROTON_ENABLE_WAYLAND = "1";
  };

  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = with pkgs; [
      openmw
      prismlauncher
      lutris
      umu-launcher # lutris runs proton through umu; without it no proton versions show up
      vintagestory
      osu-lazer-bin
    ];

    # Both steam and lutris scan compatibilitytools.d, so one link serves both.
    home.file.".local/share/Steam/compatibilitytools.d/${pkgs.proton-ge-bin.version}".source =
      pkgs.proton-ge-bin.steamcompattool;
  };
}
