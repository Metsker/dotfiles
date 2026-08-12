{ inputs, ... }:

{
  # No nixpkgs.follows on the input, so this cache actually hits.
  flake.modules.nixos.base.nix.settings = {
    extra-substituters = [ "https://monstar.cachix.org" ];
    extra-trusted-public-keys = [ "monstar.cachix.org-1:75M9ke+wZlmUcNsXpDae9793qhdRgtlNUEu/mW7u20c=" ];
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }:
    let
      monstar = inputs.monstar.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      home.packages = [
        monstar
        # Terminal indirection (absolute store path: ~/.local/bin isn't on mango's session PATH).
        (pkgs.writeShellScriptBin "term" ''exec ${monstar}/bin/monstar "$@"'')
        pkgs.ghostty.terminfo # monstar sets TERM=xterm-ghostty; supplies that terminfo entry
      ];

      xdg.configFile.monstar = { source = dotfile "monstar"; recursive = true; };
    };
}
