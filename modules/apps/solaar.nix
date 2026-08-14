{
  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "solaar-start";
        runtimeInputs = [ pkgs.solaar ];
        text = builtins.readFile ../../scripts/solaar-start.sh;
      })
    ];
  };
}
