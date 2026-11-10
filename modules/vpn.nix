{
  # The VPN across every layer it touches: the clients and the root service Hiddify's TUN runs in.
  flake.modules.nixos.base = { pkgs, ... }:
    let
      # nixpkgs dropped hiddify-app as unmaintained; upstream ships Linux as an AppImage only.
      hiddifyVersion = "5.5.5";
      hiddifySrc = pkgs.fetchurl {
        url = "https://github.com/hiddify/hiddify-app/releases/download/v${hiddifyVersion}/Hiddify-Linux-x64-AppImage.AppImage";
        hash = "sha256-0cpIwiqtOMs6UyT8uq2f3aV9dHedBnHffxTJnIXW0EE=";
      };
      # The image carries its GTK stack, its core and its CLI; only GTK's epoxy and sqlite's zstd
      # come from outside it.
      hiddifyBundle = pkgs.appimageTools.extract {
        pname = "hiddify";
        version = hiddifyVersion;
        src = hiddifySrc;
      };
      hiddifyApp = pkgs.symlinkJoin {
        name = "hiddify-${hiddifyVersion}";
        paths = [
          (pkgs.appimageTools.wrapType2 {
            pname = "hiddify";
            version = hiddifyVersion;
            src = hiddifySrc;
            extraPkgs = p: [ p.libepoxy p.zstd ];
          })
        ];
        postBuild = ''
          mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
          cp ${hiddifyBundle}/hiddify.png $out/share/icons/hicolor/256x256/apps/hiddify.png
          cp ${pkgs.makeDesktopItem {
            name = "hiddify";
            desktopName = "Hiddify";
            genericName = "Proxy client";
            comment = "Multi-platform proxy client based on sing-box";
            exec = "hiddify %u";
            icon = "hiddify";
            categories = [ "Network" ];
            startupWMClass = "app.hiddify.com";
            mimeTypes = [
              "x-scheme-handler/hiddify"
              "x-scheme-handler/v2ray"
              "x-scheme-handler/v2rayn"
              "x-scheme-handler/v2rayng"
              "x-scheme-handler/clash"
              "x-scheme-handler/clashmeta"
              "x-scheme-handler/sing-box"
            ];
          }}/share/applications/hiddify.desktop $out/share/applications/hiddify.desktop
        '';
      };
    in
    {
      # Hiddify's TUN needs root, and on first connect the app installs its own systemd unit through
      # pkexec - which cannot write /etc/systemd/system here. Declaring the unit is the same end
      # state: the app only checks that something answers on 18020 with the secret and build stamp
      # the two share below.
      systemd.services.hiddify-admin-bgservice = {
        description = "Hiddify VPN service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${hiddifyBundle}/HiddifyCli admin_bgservice run";
          # ./lib/hiddify-core.so is a cwd-relative NEEDED entry, resolved before main runs.
          WorkingDirectory = hiddifyBundle;
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      # The one file both sides need: the user's app reads it to authenticate, the root service reads
      # it to enforce. Written once, so a rebuild never drops the app's connection.
      system.activationScripts.hiddifySecret.text = ''
        secret=/var/lib/hiddify-admin-bgservice/control.secret
        mkdir -p "$(dirname "$secret")"
        if [ ! -s "$secret" ]; then
          ${pkgs.coreutils}/bin/head -c 48 /dev/urandom \
            | ${pkgs.coreutils}/bin/base64 \
            | ${pkgs.coreutils}/bin/tr -d '\n' > "$secret"
        fi
        ${pkgs.coreutils}/bin/chown metsker "$secret"
        ${pkgs.coreutils}/bin/chmod 600 "$secret"
      '';

      services.v2raya = {
        enable = true;
        cliPackage = pkgs.sing-box;
      };

      environment.systemPackages = with pkgs; [
        termius
        v2rayn
        hiddifyApp
      ];
    };
}
