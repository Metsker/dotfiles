{ inputs, ... }:

{
  flake.modules.nixos.base = {
    imports = [ inputs.noctalia-greeter.nixosModules.default ];

    programs.noctalia-greeter.enable = true;

    nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  flake.modules.homeManager.metsker = { dotfile, ... }: {
    imports = [ inputs.noctalia.homeModules.default ];

    programs.noctalia = {
      enable = true;
      systemd.enable = true;
    };

    home.file.".local/state/noctalia/settings.toml".source = dotfile "noctalia/settings.toml";
  };
}
