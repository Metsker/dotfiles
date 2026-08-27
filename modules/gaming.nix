{
  flake.modules.nixos.base = {
    # GE-Proton is linked into ~/.local/share/Steam/compatibilitytools.d below,
    # which both steam and lutris scan, so no extraCompatPackages needed here.
    programs.steam.enable = true;

    environment.sessionVariables.PROTON_ENABLE_WAYLAND = "1";
  };

  flake.modules.homeManager.metsker = { lib, pkgs, ... }: {
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

    # umu can't fetch steamrt4 itself: Valve's latest-public-beta alias 403s on GET (HEAD still
    # 307s), and umu 1.4.1 hardcodes that URL with no override, so it dies on a missing
    # toolmanifest.vdf. Steam already ships the same runtime, so borrow it instead of downloading.
    # Not home.file: umu writes a marker into this dir and renameat2's it on update.
    # Drop once repo.steampowered.com serves the alias again; umu then self-heals on its next update.
    home.activation.umuSteamrt4 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      runtime="$HOME/.local/share/Steam/steamapps/common/SteamLinuxRuntime_4"
      link="$HOME/.local/share/umu/steamrt4"
      if [ -e "$runtime/toolmanifest.vdf" ] && [ ! -e "$link/toolmanifest.vdf" ]; then
        run mkdir -p "$(dirname "$link")"
        run rmdir "$link" 2>/dev/null || true # umu leaves an empty dir behind when its download fails
        run ln -sfn "$runtime" "$link"
      fi
    '';
  };
}
