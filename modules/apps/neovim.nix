{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.neovim ];

    environment.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  flake.modules.homeManager.metsker = { dotfile, ... }: {
    # config/nvim is a git submodule (github.com/Metsker/nvim).
    xdg.configFile.nvim = { source = dotfile "nvim"; recursive = true; };

    xdg.desktopEntries.nvim = {
      name = "Neovim";
      genericName = "Text Editor";
      exec = "term -e nvim %F";
      terminal = false;
      type = "Application";
      icon = "nvim";
      categories = [ "Utility" "TextEditor" ];
      mimeType = [ "text/plain" ];
    };

    xdg.mimeApps.defaultApplications = {
      "text/plain" = "nvim.desktop";
      "text/markdown" = "nvim.desktop";
      "application/json" = "nvim.desktop";
      "application/xml" = "nvim.desktop";
      "text/x-shellscript" = "nvim.desktop";
      "text/x-python" = "nvim.desktop";
    };
  };
}
