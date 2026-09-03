{ inputs, ... }:

# The text-mode half of the desktop: shell, terminal, editor, file manager, git.
let
  # The only place the terminal is named. $TERMINAL covers anything that spawns one through a
  # shell; KIO's launcher reads kdeglobals instead, so it needs the same answer written there.
  terminal = {
    binary = "monstar";
    desktopId = "dev.rockorager.monstar.desktop";
  };
in
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
      # Anything that spawns a terminal reads this; noctalia's own discovery list ends
      # at foot and never names monstar.
      TERMINAL = terminal.binary;
      # snacks.nvim gates kitty graphics on the XTVERSION terminal name, which libghostty
      # does not answer to; set for the session because `-e nvim` starts no shell.
      SNACKS_GHOSTTY = "1";
    };

    # No nixpkgs.follows on the input, so this cache actually hits.
    nix.settings = {
      extra-substituters = [ "https://monstar.cachix.org" ];
      extra-trusted-public-keys = [ "monstar.cachix.org-1:75M9ke+wZlmUcNsXpDae9793qhdRgtlNUEu/mW7u20c=" ];
    };
  };

  flake.modules.homeManager.metsker = { lib, pkgs, dotfile, ... }:
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

      programs.bat.enable = true;

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
        pkgs.github-cli
        pkgs.lazygit
        pkgs.jrnl
      ];

      # KIO's terminal launcher reads kdeglobals, not the environment, and falls through to
      # konsole when these are unset - which is why dolphin's "Open Terminal Here" did nothing.
      # Written by activation rather than home.file because noctalia merges colors and fonts into
      # the same file at runtime, and a read-only store symlink would break that.
      home.activation.kdeTerminal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General \
          --key TerminalApplication ${terminal.binary}
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General \
          --key TerminalService ${terminal.desktopId}
      '';

      xdg.configFile.monstar = { source = dotfile "monstar"; recursive = true; };
      xdg.configFile.foot = { source = dotfile "foot"; recursive = true; };
      xdg.configFile.yazi = { source = dotfile "yazi"; recursive = true; };
      xdg.configFile.lazygit = { source = dotfile "lazygit"; recursive = true; };
      # config/nvim is a git submodule (github.com/Metsker/nvim).
      xdg.configFile.nvim = { source = dotfile "nvim"; recursive = true; };

      xdg.desktopEntries.nvim = {
        name = "Neovim";
        genericName = "Text Editor";
        exec = "nvim %F";
        # The launcher supplies the terminal - noctalia through $TERMINAL, KIO through kdeglobals -
        # so this entry names none. A desktop Exec is not shell-expanded, so $TERMINAL cannot go here.
        terminal = true;
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
