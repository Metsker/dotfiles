{ config, pkgs, lib, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configs = {
    nvim = "nvim";
    herdr = "herdr/config.toml";
    foot = "foot";
    mango = "mango";
    hypr = "hypr";
    uwsm = "uwsm";
    yazi = "yazi";
    lazygit = "lazygit";
    monstar = "monstar";
  };
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [ grim slurp satty wayfreeze libnotify ];
    text = builtins.readFile ./scripts/screenshot.sh;
  };
  # wayfreeze gives the instant freeze; hyprpicker picks with its zoom lens.
  colorpicker = pkgs.writeShellApplication {
    name = "colorpicker";
    runtimeInputs = with pkgs; [ wayfreeze hyprpicker ];
    text = builtins.readFile ./scripts/colorpicker.sh;
  };
  # Freeze, slurp a region, OCR it with tesseract, copy the text to the clipboard.
  textpicker = pkgs.writeShellApplication {
    name = "textpicker";
    runtimeInputs = with pkgs; [ wayfreeze slurp grim tesseract wl-clipboard libnotify ];
    text = builtins.readFile ./scripts/textpicker.sh;
  };
  # Super+C/V copy/paste: mmsg (mango) reads the focused appid, wtype injects Ctrl(+Shift)+C/V.
  clipboard = pkgs.writeShellApplication {
    name = "clipboard";
    runtimeInputs = [
      pkgs.wtype
      pkgs.jq
      inputs.mango.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    text = builtins.readFile ./scripts/clipboard.sh;
  };
  # Launches URLs as standalone chromium --app windows; keeps chromium off the global PATH.
  webapp = pkgs.writeShellApplication {
    name = "webapp";
    runtimeInputs = [ pkgs.chromium ];
    text = builtins.readFile ./scripts/webapp.sh;
  };
  # Terminal indirection (absolute path: ~/.local/bin isn't on mango's session PATH).
  term = pkgs.writeShellScriptBin "term" ''exec ${config.home.homeDirectory}/.local/bin/monstar "$@"'';
in
{
  imports = [
    inputs.noctalia.homeModules.default
    inputs.zen-browser.homeModules.default
    ./xdg.nix
    ./webapps.nix
    ./claude.nix
  ];

  home.username = "metsker";
  home.homeDirectory = "/home/metsker";
  home.stateVersion = "26.05";

  programs.zen-browser = {
    enable = true;
    profiles.default.settings = {
      "toolkit.legacyUserProfileCustomizations.stylesheets" = false;
      "zen.theme.content-element-separation" = 0;
      "zen.view.experimental-no-window-controls" = true;
      "zen.widget.linux.transparency" = false;
      "browser.tabs.allow_transparent_browser" = true;
      "browser.tabs.hoverPreview.enabled" = true;
    };
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };

  home.pointerCursor = {
    enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
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

  # Hide the Qt5/Qt6 Settings tools from the noctalia launcher (still runnable via `qt5ct`/`qt6ct`).
  xdg.desktopEntries.qt5ct = {
    name = "Qt5 Settings";
    exec = "qt5ct";
    noDisplay = true;
  };
  xdg.desktopEntries.qt6ct = {
    name = "Qt6 Settings";
    exec = "qt6ct";
    noDisplay = true;
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
      c = "claude";
    };
  };

  programs.zoxide = {
    enable = true;
    options = [ "--cmd cd" ];
  };

  programs.yazi = {
    enable = true;
    # enableFishIntegration = true;
  };

  home.file.".local/state/noctalia/settings.toml".source =
    create_symlink "${dotfiles}/noctalia/settings.toml";

  xdg.configFile = lib.mapAttrs'
    (name: subpath: lib.nameValuePair subpath {
      source = create_symlink "${dotfiles}/${subpath}";
      recursive = true;
    })
    configs;

  home.packages = with pkgs; [
    screenshot
    colorpicker
    textpicker
    clipboard
    webapp
    term
    ghostty.terminfo # monstar sets TERM=xterm-ghostty; supplies that terminfo entry

    hyprpicker
    xwayland
    slurp

    gcc
    ripgrep
    fzf
    fd
    jq
    openmw
    tealdeer
    imv
    mpv
    ffmpeg
    imagemagick
    wl-clipboard
    libnotify
    tree-sitter
    nodejs
    bun
    typescript
    python3
    rustc
    herdr
    github-cli
    lazygit

    nil
    nixpkgs-fmt
    stylua

    telegram-desktop
    discord
  ];
}
