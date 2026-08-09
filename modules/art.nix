{
  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = [ pkgs.krita ];
  };
}
