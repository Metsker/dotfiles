{ inputs, ... }:

# The graphical session: mango as the compositor, noctalia as the bar/shell/launcher,
# plus the screen-capture portal and the little wayland tools bound in mango's keybinds.
{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [
      inputs.mango.nixosModules.mango
      inputs.noctalia-greeter.nixosModules.default
    ];

    programs.mango = {
      enable = true;
      package = pkgs.mangowm;
      addLoginEntry = false; # uwsm-managed session entry only
    };

    # Runs mango under systemd user units: app scopes tear down cleanly, graphical-session.target works.
    programs.uwsm = {
      enable = true;
      waylandCompositors.mango = {
        prettyName = "Mango";
        comment = "Mango managed by uwsm";
        binPath = "/run/current-system/sw/bin/mango";
      };
    };

    # Auto-login into mango at boot (LUKS passphrase already gates access); greeter only shows after logout.
    services.greetd.settings.initial_session = {
      command = "uwsm start -F -- /run/current-system/sw/bin/mango";
      user = "metsker";
    };

    # Electron apps (Discord) ignore SIGTERM and stall logout for 90s; SIGKILL them after 10s instead.
    systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

    programs.noctalia-greeter.enable = true;

    nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];

    xdg.portal.wlr.settings.screencast = {
      chooser_type = "simple";
      chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
    };

    programs.gpu-screen-recorder.enable = true;

    nixpkgs.overlays = [
      # Exposes the flake input under pkgs so the tool wrappers below can list it in runtimeInputs.
      (final: prev: {
        mangowm = inputs.mango.packages.${prev.stdenv.hostPlatform.system}.default;
      })
      # xdpw offers only 24-bit BG24 shm on NVIDIA GLES2; Chromium needs 32-bit - breaks Discord screenshare.
      # Patch = upstream PR 386 + XBGR/ABGR fallbacks. Drop when https://github.com/emersion/xdg-desktop-portal-wlr/issues/385 is fixed.
      # The 2-buffer pool still starves the capture loop with Electron consumers; drop the buffer-count patch when PR 396 lands.
      (final: prev: {
        xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../patches/xdpw-shm-fallback-formats.diff
            ../patches/xdpw-buffer-count.diff
          ];
        });
      })
    ];
  };

  flake.modules.homeManager.metsker = { config, pkgs, dotfile, ... }: {
    imports = [ inputs.noctalia.homeModules.default ];

    xdg.configFile.mango = { source = dotfile "mango"; recursive = true; };
    xdg.configFile.uwsm = { source = dotfile "uwsm"; recursive = true; };

    programs.noctalia = {
      enable = true;
      systemd.enable = true;
    };

    home.file.".local/state/noctalia/settings.toml".source = dotfile "noctalia/settings.toml";

    home.packages = with pkgs; [
      xwayland

      (writeShellApplication {
        name = "screenshot";
        runtimeInputs = [ grim slurp satty wayfreeze wlrctl libnotify ];
        text = builtins.readFile ../scripts/screenshot.sh;
      })
      # wayfreeze gives the instant freeze; hyprpicker picks with its zoom lens.
      (writeShellApplication {
        name = "colorpicker";
        runtimeInputs = [ wayfreeze hyprpicker ];
        text = builtins.readFile ../scripts/colorpicker.sh;
      })
      # Freeze, slurp a region, OCR it with tesseract, copy the text to the clipboard.
      (writeShellApplication {
        name = "textpicker";
        runtimeInputs = [ wayfreeze slurp grim wlrctl tesseract wl-clipboard libnotify ];
        text = builtins.readFile ../scripts/textpicker.sh;
      })
      # Super+C/V copy/paste: mmsg (mango) reads the focused appid, wtype injects Ctrl(+Shift)+C/V.
      (writeShellApplication {
        name = "clipboard";
        runtimeInputs = [ wtype jq mangowm ];
        text = builtins.readFile ../scripts/clipboard.sh;
      })
      (writeShellApplication {
        name = "record";
        runtimeInputs = [ config.programs.noctalia.package procps gnused ];
        text = builtins.readFile ../scripts/record.sh;
      })

      hyprpicker
      slurp
      wl-clipboard
      libnotify
    ];
  };
}
