{ inputs, ... }:

# The half of the graphical session every desktop profile shares: noctalia, the one shell, the uwsm
# plumbing, the greeter that picks between the compositors, the portals, and the wayland tools that
# do not care which compositor is up.
#
# A profile is one compositor, one file each (mango.nix, driftwm.nix, umbriel.nix). All three are
# always installed; swapping means logging out and picking another entry in the greeter. noctalia is
# the shell on all of them, so it binds to graphical-session.target - the one target all three reach.
{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [ inputs.noctalia-greeter.nixosModules.default ];

    nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];

    # Runs the compositor under systemd user units: app scopes tear down cleanly, and uwsm
    # publishes a wayland-session@<compositor>.target that each profile hangs its shell off.
    programs.uwsm.enable = true;

    # No autologin any more: the greeter is where the profile gets picked, and it remembers
    # the last choice. The LUKS passphrase still gates access at boot.
    programs.noctalia-greeter.enable = true;

    # Electron apps (Discord) ignore SIGTERM and stall logout for 90s; SIGKILL them after 10s instead.
    systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

    xdg.portal.wlr.settings.screencast = {
      chooser_type = "simple";
      chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
    };

    # Qt apps open this dialog natively already, so the portal's picker now matches them.
    # Each profile points its own compositor's portal config at it.
    xdg.portal.extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];

    programs.gpu-screen-recorder.enable = true;

    # voxtype grabs its push-to-talk key straight from /dev/input, because mango has no key-release bind.
    users.users.metsker.extraGroups = [ "input" ];

    nixpkgs.overlays = [
      # gsr disables nvenc when built against libavcodec >= 63 unless the driver offers nvenc API 13.1;
      # 580 is the last branch for this Pascal card and caps out at 13.0. Drop when gsr stops gating on
      # the ffmpeg major, or when the card is replaced.
      (final: prev: {
        gpu-screen-recorder = prev.gpu-screen-recorder.override { ffmpeg = prev.ffmpeg_8; };
      })
      # Carries the parakeet engine, which beats vulkan whisper on this card and leaves the GPU alone.
      (final: prev: {
        voxtype = prev.voxtype.override { onnxSupport = true; };
      })
    ];
  };

  flake.modules.homeManager.metsker = { config, pkgs, dotfile, ... }: {
    imports = [ inputs.noctalia.homeModules.default ];

    xdg.configFile.uwsm = { source = dotfile "uwsm"; recursive = true; };
    xdg.configFile.voxtype = { source = dotfile "voxtype"; recursive = true; };

    # The module's own graphical-session.target is right here: every profile reaches it, and every
    # profile wants noctalia. Its per-compositor features come from runtime detection, not from Nix.
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
    };

    home.file.".local/state/noctalia/settings.toml".source = dotfile "noctalia/settings.toml";

    # Nixpkgs ships no unit for the dictation daemon, and it only makes sense with a compositor up.
    systemd.user.services.voxtype = {
      Unit = {
        Description = "Voxtype push-to-talk dictation daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.voxtype}/bin/voxtype daemon";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.packages = with pkgs; [
      voxtype
      xwayland

      (writeShellApplication {
        name = "screenshot";
        runtimeInputs = [ grim slurp satty wayfreeze wlrctl libnotify ];
        text = builtins.readFile ../../scripts/screenshot.sh;
      })
      # wayfreeze gives the instant freeze; hyprpicker picks with its zoom lens.
      (writeShellApplication {
        name = "colorpicker";
        runtimeInputs = [ wayfreeze hyprpicker ];
        text = builtins.readFile ../../scripts/colorpicker.sh;
      })
      # Freeze, slurp a region, OCR it with tesseract, copy the text to the clipboard.
      (writeShellApplication {
        name = "textpicker";
        runtimeInputs = [ wayfreeze slurp grim wlrctl tesseract wl-clipboard libnotify ];
        text = builtins.readFile ../../scripts/textpicker.sh;
      })
      # Super+C/V copy/paste: asks the running compositor for the focused window's pid,
      # then wtype injects Ctrl(+Shift)+C/V. Shared, so it carries all three compositors' clients.
      (writeShellApplication {
        name = "clipboard";
        runtimeInputs = [ wtype jq mangowm driftwm umbriel ];
        text = builtins.readFile ../../scripts/clipboard.sh;
      })
      # Drives noctalia's screen_recorder plugin, so it works wherever noctalia does.
      (writeShellApplication {
        name = "record";
        runtimeInputs = [ config.programs.noctalia.package procps gnused ];
        text = builtins.readFile ../../scripts/record.sh;
      })
      # Runs on every dictation via voxtype's post_process hook; pure bash, so nothing to put on PATH.
      (writeShellApplication {
        name = "voxtype-postprocess";
        runtimeInputs = [ ];
        text = builtins.readFile ../../scripts/voxtype-postprocess.sh;
      })

      hyprpicker
      slurp
      wl-clipboard
      libnotify
    ];
  };
}
