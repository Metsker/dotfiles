{
  # Everything that exists because of the metal: GPU, firmware, audio, bluetooth, peripherals.
  flake.modules.nixos.base = { pkgs, ... }: {
    hardware.graphics.enable = true;

    # Redistributable firmware blobs for BT/Wi-Fi/GPU hardware.
    hardware.enableRedistributableFirmware = true;

    # Pulls in hardware.logitech.wireless.enable (udev rules) by default.
    programs.solaar = {
      enable = true;
      # The module's own user service, rather than an autostart line in every compositor:
      # it restarts on failure and stops with the session, which a spawned process does not.
      userService.enable = true;
    };

    environment.etc."libinput/local-overrides.quirks".text = ''
      [Logitech MX Anywhere 3S]
      MatchName=Logitech MX Anywhere 3S
      AttrEventCode=-REL_WHEEL_HI_RES;-REL_HWHEEL_HI_RES;
    '';

    # WebHID for the XVX MU68 keyboard's web driver; a 70- file, since extraRules lands in 99-local.rules, after uaccess is applied.
    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/70-xvx-mu68.rules" ''
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="fffe", ATTRS{idProduct}=="00ae", TAG+="uaccess"
      '')
    ];

    # PipeWire (ALSA + Pulse compat + Bluetooth A2DP); rtkit grants realtime priority.
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Noctalia's panel drives BlueZ directly, so no blueman needed.
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      # settings.General.Experimental = true; # battery reporting + better BLE
    };

    # Noctalia's battery readouts come over UPower: the laptop battery and the wireless peripherals.
    services.upower.enable = true;
  };

  flake.modules.homeManager.metsker = {
    # Noctalia loads effect presets over $XDG_RUNTIME_DIR/EasyEffectsServer, so the daemon has to be up.
    services.easyeffects.enable = true;
  };

  # The desktop's RGB RAM, its DDC monitors, its GPU undervolt and its fan sensors; the laptop has none of them.
  flake.modules.nixos.pc = { config, lib, ... }: {
    # Fan speeds and Vcore come from the IT8689E, only in the out-of-tree it87; pc.nix's acpi_enforce_resources=lax lets it bind.
    boot.extraModulePackages = [
      # nixpkgs installs it beside the in-tree it87, which depmod prefers; updates/ outranks the in-tree one.
      (config.boot.kernelPackages.it87.overrideAttrs (old: {
        makeFlags = lib.filter (f: !lib.hasPrefix "MODDESTDIR=" f) old.makeFlags
          ++ [ "MODDESTDIR=$(out)/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/updates" ];
      }))
    ];
    boot.kernelModules = [ "it87" ];

    # 2700 MHz at ~915 mV instead of ~1005 mV, under the 123 W floor of the cap; the GUI can no longer save.
    services.lact = {
      enable = true;
      settings = {
        version = 7;
        daemon = {
          log_level = "info";
          admin_group = "wheel";
          disable_clocks_cleanup = false;
        };
        apply_settings_timer = 5;
        gpus."10DE:2D05-19DA:1780-0000:07:00.0" = {
          fan_control_enabled = false;
          power_cap = 123.0;
          min_core_clock = 180;
          max_core_clock = 2700;
          gpu_clock_offsets."0" = 300;
        };
        current_profile = null;
        auto_switch_profiles = false;
      };
    };

    services.hardware.openrgb = {
      enable = true;
      # The server applies the profile itself once its own ~20s of device detection finishes -
      # which is all the old poll-then-launch script was doing from the outside.
      startupProfile = "off";
    };

    # The server reads profiles from its own state dir while the GUI writes them to the user's
    # config dir; a symlink keeps the file the GUI saves as the only copy.
    systemd.tmpfiles.rules = [
      "L+ /var/lib/OpenRGB/carrot.orp - - - - /home/metsker/.config/OpenRGB/carrot.orp"
    ];

    # ddcutil talks to the monitors over the GPU's i2c buses; this loads i2c-dev and
    # grants the seat user access, instead of leaning on OpenRGB's udev rules for it.
    hardware.i2c.enable = true;
    # The seat ACL is revoked before the session stops, and ddc-brightness saves on the way out.
    users.users.metsker.extraGroups = [ "i2c" ];
  };

  flake.modules.homeManager.pc = { pkgs, dotfile, ... }:
    let
      # No backlight class on a desktop, so monitor brightness goes over DDC/CI. The wrapper
      # shadows ddcutil itself; everything but `detect` is passed straight through.
      ddcutil = pkgs.writeShellApplication {
        name = "ddcutil";
        runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.gnugrep ];
        runtimeEnv.DDCUTIL_REAL = "${pkgs.ddcutil}/bin/ddcutil";
        text = builtins.readFile ../scripts/ddcutil-connector-fix.sh;
      };

      ddc-brightness = pkgs.writeShellApplication {
        name = "ddc-brightness";
        runtimeInputs = [ ddcutil pkgs.coreutils pkgs.gawk ];
        text = builtins.readFile ../scripts/ddc-brightness.sh;
      };
    in
    {
      # A whole directory, not `recursive`: OpenRGB rewrites OpenRGB.json and drops a detection log
      # per start into this directory, which per-file store symlinks would make read-only.
      xdg.configFile.OpenRGB.source = dotfile "openrgb";

      home.packages = [ ddcutil ddc-brightness ];

      # Before noctalia, so its brightness service reads the restored values and never races us on i2c.
      systemd.user.services.ddc-brightness = {
        Unit = {
          Description = "Carry DDC monitor brightness across power cycles";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          Before = [ "noctalia.service" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${ddc-brightness}/bin/ddc-brightness restore";
          ExecStop = "${ddc-brightness}/bin/ddc-brightness save";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
