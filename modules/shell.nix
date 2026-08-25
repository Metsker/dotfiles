{ inputs, ... }:

# The text-mode half of the desktop: shell, terminal, editor, file manager, git.
{
  flake.modules.nixos.base = { pkgs, ... }: {
    programs.fish = {
      enable = true;
      interactiveShellInit = "set -g fish_greeting";
    };

    users.users.metsker.shell = pkgs.fish;

    environment.systemPackages = with pkgs; [ foot neovim git ];

    environment.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # No nixpkgs.follows on the input, so this cache actually hits.
    nix.settings = {
      extra-substituters = [ "https://monstar.cachix.org" ];
      extra-trusted-public-keys = [ "monstar.cachix.org-1:75M9ke+wZlmUcNsXpDae9793qhdRgtlNUEu/mW7u20c=" ];
    };
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }:
    let
      monstar = inputs.monstar.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      programs.fish = {
        enable = true;
        shellAliases = {
          rebuild = "sudo -v; and nh os switch";
          restart = "systemctl --user restart";
          lg = "lazygit";
        };
      };

      programs.eza = {
        enable = true;
        git = true;
        icons = "auto";
        extraOptions = [ "--group-directories-first" ];
      };

      programs.zoxide = {
        enable = true;
        options = [ "--cmd cd" ];
      };

      programs.yazi = {
        enable = true;
        # enableFishIntegration = true;
      };

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

      home.packages = [
        monstar
        # Terminal indirection (absolute store path: ~/.local/bin isn't on mango's session PATH).
        (pkgs.writeShellScriptBin "term" ''exec ${monstar}/bin/monstar "$@"'')
        pkgs.ghostty.terminfo # monstar sets TERM=xterm-ghostty; supplies that terminfo entry
        pkgs.github-cli
        pkgs.lazygit
      ];

      xdg.configFile.monstar = { source = dotfile "monstar"; recursive = true; };
      xdg.configFile.foot = { source = dotfile "foot"; recursive = true; };
      xdg.configFile.yazi = { source = dotfile "yazi"; recursive = true; };
      xdg.configFile.lazygit = { source = dotfile "lazygit"; recursive = true; };
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
