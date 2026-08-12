{
  flake.modules.nixos.base = { pkgs, ... }: {
    programs.fish = {
      enable = true;
      interactiveShellInit = "set -g fish_greeting";
    };

    users.users.metsker.shell = pkgs.fish;
  };

  flake.modules.homeManager.metsker = {
    programs.fish = {
      enable = true;
      shellAliases = {
        rebuild = "sudo -v; and nh os switch";
        restart = "systemctl --user restart";
      };
    };

    programs.zoxide = {
      enable = true;
      options = [ "--cmd cd" ];
    };
  };
}
