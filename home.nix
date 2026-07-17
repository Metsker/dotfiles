{ config, pkgs, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configs = {
    nvim = "nvim";
    herdr = "herdr";
    foot = "foot";
    niri = "niri";
    yazi = "yazi";
    lazygit = "lazygit";
  };
in

{
  imports = [
    inputs.noctalia.homeModules.default
    inputs.zen-browser.homeModules.default
    ./xdg.nix
  ];

  home.username = "metsker";
  home.homeDirectory = "/home/metsker";
  home.stateVersion = "26.05";

  programs.zen-browser = {
    enable = true;
    policies.Preferences."toolkit.legacyUserProfileCustomizations.stylesheets" = {
      Value = true;
      Status = "locked";
    };
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    qt6ctSettings.Appearance = {
      custom_palette = true;
      style = "Fusion";
      color_scheme_path = "${config.home.homeDirectory}/.config/qt6ct/colors/noctalia.conf";
    };
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

  programs.fish = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/dotfiles/#pc";
      lg = "lazygit";
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

  # programs.steam.enable = true;

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
    nil
    nixpkgs-fmt
    stylua
    gcc
    ripgrep
    fzf
    fd
    jq
    imv
    mpv
    ffmpeg
    tree-sitter
    nodejs
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    github-cli
    lazygit

    claude-code
    telegram-desktop
    discord
  ];
}
