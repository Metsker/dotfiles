{
  flake.modules.nixos.base = {
    # GE-Proton is linked into ~/.local/share/Steam/compatibilitytools.d below,
    # which both steam and lutris scan, so no extraCompatPackages needed here.
    programs.steam.enable = true;

    environment.sessionVariables.PROTON_ENABLE_WAYLAND = "1";
    # Every Vulkan app gets the HUD; desktop apps opt out via `blacklist` in MangoHud.conf.
    environment.sessionVariables.MANGOHUD = "1";

    # lutris's FHS env still lists gtk2, now marked broken (NixOS/nixpkgs#410814); drop once lutris stops pulling it.
    nixpkgs.config.problems.handlers."gtk+".broken = "warn";
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    home.packages = with pkgs; [
      mangohud
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

    xdg.configFile.MangoHud.source = dotfile "MangoHud";
  };
}
