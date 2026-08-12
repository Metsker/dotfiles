{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.git ];
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    programs.git = {
      enable = true;
      settings = {
        user.name = "metsker";
        user.email = "lev.shchinoff@gmail.com";
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core.editor = "nvim";
        credential."https://github.com".helper = "!${pkgs.github-cli}/bin/gh auth git-credential";
        credential."https://gist.github.com".helper = "!${pkgs.github-cli}/bin/gh auth git-credential";
      };
    };

    home.packages = with pkgs; [ github-cli lazygit ];
    programs.fish.shellAliases.lg = "lazygit";
    xdg.configFile.lazygit = { source = dotfile "lazygit"; recursive = true; };
  };
}
