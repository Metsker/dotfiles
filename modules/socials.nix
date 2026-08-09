{
  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = with pkgs; [
      telegram-desktop
      discord
    ];
  };
}
