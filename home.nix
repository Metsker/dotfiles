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
    runtimeInputs = with pkgs; [ grim slurp satty wayfreeze wlrctl libnotify ];
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
    runtimeInputs = with pkgs; [ wayfreeze slurp grim wlrctl tesseract wl-clipboard libnotify ];
    text = builtins.readFile ./scripts/textpicker.sh;
  };
  # Super+C/V copy/paste: mmsg (mango) reads the focused appid, wtype injects Ctrl(+Shift)+C/V.
  clipboard = pkgs.writeShellApplication {
    name = "clipboard";
    runtimeInputs = [
      pkgs.wtype
      pkgs.jq
      pkgs.mangowm
    ];
    text = builtins.readFile ./scripts/clipboard.sh;
  };
  # Launches URLs as standalone chromium --app windows; keeps chromium off the global PATH.
  webapp = pkgs.writeShellApplication {
    name = "webapp";
    runtimeInputs = [ pkgs.chromium ];
    text = builtins.readFile ./scripts/webapp.sh;
  };
  # monstar terminal, built by the monstar-flake input.
  monstarPkg = inputs.monstar.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # Terminal indirection (absolute store path: ~/.local/bin isn't on mango's session PATH).
  term = pkgs.writeShellScriptBin "term" ''exec ${monstarPkg}/bin/monstar "$@"'';
  # NAUTILUS_4_EXTENSION_DIR replaces the extension dir rather than adding to it, so nautilus's
  # own two have to ride along with the python bridge or the Properties tabs they draw vanish.
  nautilusExtensions = pkgs.buildEnv {
    name = "nautilus-extensions";
    paths = [ pkgs.nautilus pkgs.nautilus-python ];
    pathsToLink = [ "/lib/nautilus/extensions-4" ];
  };
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
      # Default 2 (auto) only picks the portal when sandboxed; 1 forces it, so uploads get the GTK picker.
      "widget.use-xdg-desktop-portal.file-picker" = 1;
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
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # noctalia's papirus-icons template recolors folders in place, so the theme has to be writable:
  # the store copy is not, and the /usr/share fallback it looks for does not exist here. Papirus
  # comes along because Papirus-Dark is a shell - every size >= 32px symlinks into ../Papirus.
  home.activation.papirusWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    icons="$HOME/.local/share/icons"
    src="${config.gtk.iconTheme.package}/share/icons"
    if [ "$(cat "$icons/.papirus-source" 2>/dev/null)" != "$src" ]; then
      run mkdir -p "$icons"
      run rm -rf "$icons/Papirus" "$icons/Papirus-Dark"
      run cp -a "$src/Papirus" "$src/Papirus-Dark" "$icons/"
      run chmod -R u+w "$icons/Papirus" "$icons/Papirus-Dark"
      run rm -f "$icons"/Papirus*/icon-theme.cache # built against the store path; stale it wins
      # The only sizes papirus-folders recolors that Papirus-Dark keeps its own copy of; the
      # content is byte-identical to Papirus's, so linking them lets one recolor cover both.
      for s in 22x22 24x24; do
        run rm -rf "$icons/Papirus-Dark/$s/places"
        run ln -s "../../Papirus/$s/places" "$icons/Papirus-Dark/$s/places"
      done
      echo "$src" > "$icons/.papirus-source"
    fi
  '';

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    qt6ctSettings.Appearance = {
      custom_palette = true;
      style = "Fusion";
      color_scheme_path = "${config.home.homeDirectory}/.config/qt6ct/colors/noctalia.conf";
      # Qt has no icon theme of its own; without this Qt apps fall back to hicolor and show blanks.
      icon_theme = "Papirus-Dark";
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
      lg = "lazygit";
      c = "claude";
      # prime sudo up front so the build does not stall on a password prompt at the end
      rebuild = "sudo -v; and nh os switch";
      restart = "systemctl --user restart";
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

  home.file.".local/share/fonts/JetBrainsMono".source =
    "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";

  # Nautilus ships no "Open in Terminal"; its built-in one only speaks D-Bus to gnome-console.
  systemd.user.sessionVariables.NAUTILUS_4_EXTENSION_DIR = "${nautilusExtensions}/lib/nautilus/extensions-4";

  # monstar is not in the extension's terminal list, so drive it through the custom command.
  dconf.settings."com/github/stunkymonkey/nautilus-open-any-terminal" = {
    terminal = "custom";
    custom-local-command = "${term}/bin/term";
  };

  home.file.".local/state/noctalia/settings.toml".source =
    create_symlink "${dotfiles}/noctalia/settings.toml";

  # Both steam and lutris scan compatibilitytools.d, so one link serves both.
  home.file.".local/share/Steam/compatibilitytools.d/${pkgs.proton-ge-bin.version}".source =
    pkgs.proton-ge-bin.steamcompattool;

  # umu can't fetch steamrt4 itself: Valve's latest-public-beta alias 403s on GET (HEAD still
  # 307s), and umu 1.4.1 hardcodes that URL with no override, so it dies on a missing
  # toolmanifest.vdf. Steam already ships the same runtime, so borrow it instead of downloading.
  # Not home.file: umu writes a marker into this dir and renameat2's it on update.
  # Drop once repo.steampowered.com serves the alias again; umu then self-heals on its next update.
  home.activation.umuSteamrt4 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    runtime="$HOME/.local/share/Steam/steamapps/common/SteamLinuxRuntime_4"
    link="$HOME/.local/share/umu/steamrt4"
    if [ -e "$runtime/toolmanifest.vdf" ] && [ ! -e "$link/toolmanifest.vdf" ]; then
      run mkdir -p "$(dirname "$link")"
      run rmdir "$link" 2>/dev/null || true # umu leaves an empty dir behind when its download fails
      run ln -sfn "$runtime" "$link"
    fi
  '';

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
    monstarPkg
    ghostty.terminfo # monstar sets TERM=xterm-ghostty; supplies that terminfo entry

    hyprpicker
    xwayland
    slurp
    nautilus
    nautilus-python
    nautilus-open-any-terminal
    xarchiver

    gcc
    gnumake
    ripgrep
    fzf
    fd
    jq
    openmw
    modrinth-app
    lutris
    umu-launcher # lutris runs proton through umu; without it no proton versions show up
    vintagestory
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
    cargo
    rustfmt
    rust-analyzer
    herdr
    github-cli
    lazygit
    godot

    nil
    nixpkgs-fmt
    stylua

    telegram-desktop
    discord

    tiled
  ];
}
