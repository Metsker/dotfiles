{ config, pkgs, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configs = {
    nvim = "nvim";
    herdr = "herdr";
    alacritty = "alacritty";
    niri = "niri";
  };
in

{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };

  home.username = "metsker";
  home.homeDirectory = "/home/metsker";
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
  home.stateVersion = "26.05";

  programs.fish = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/dotfiles/#pc";
    };
  };

  programs.zoxide = {
    enable = true;
    options = [ "--cmd cd" ];
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
  };

  home.file.".claude/settings.json".source =
    create_symlink "${dotfiles}/claude/settings.json";

  home.file.".local/state/noctalia/settings.toml".source =
    create_symlink "${dotfiles}/noctalia/settings.toml";

  xdg.configFile = builtins.mapAttrs
    (name: subpath: {
      source = create_symlink "${dotfiles}/${subpath}";
      recursive = true;
    })
    configs;

  home.packages = with pkgs; [
    ripgrep
    nil
    nixpkgs-fmt
    tree-sitter
    nodejs
    gcc
    claude-code
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    github-cli
    lazygit
  ];
}
