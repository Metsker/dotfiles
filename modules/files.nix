{ inputs, ... }:

{
  # The file manager: luciole.
  flake.modules.nixos.base = { pkgs, ... }: {
    # GVfs's volume monitor mounts removable drives through udisks2, which only Plasma and GNOME switch on themselves.
    services.udisks2.enable = true;

    # Luciole's Trash and remote folders go through GIO, which finds them only with GVfs running.
    services.gvfs.enable = true;

    # For the luciole user template in noctalia's settings.toml; drop both for the builtin "luciole" id once noctalia > 5.5.0.
    environment.pathsToLink = [ "/share/luciole" ];
  };

  flake.modules.homeManager.metsker = { pkgs, ... }:
    let
      extractAndTrash = pkgs.writeShellApplication {
        name = "extract-and-trash";
        runtimeInputs = with pkgs; [ unar glib libnotify coreutils ];
        text = builtins.readFile ../scripts/extract-and-trash.sh;
      };
    in
    {
      home.packages = [ inputs.luciole.packages.${pkgs.stdenv.hostPlatform.system}.default ];

      # Luciole's Scripts submenu has no file-type filter, so this shows for every selection; a non-archive is reported, not touched.
      xdg.dataFile."luciole/scripts/Extract and trash archive".source = "${extractAndTrash}/bin/extract-and-trash";

      xdg.mimeApps.defaultApplications."inode/directory" = "dev.noctalia.luciole.desktop";
    };
}
