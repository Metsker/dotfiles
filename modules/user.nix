{ config, inputs, ... }:

{
  flake.modules.nixos.base = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    users.users.metsker = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.metsker.imports = [ config.flake.modules.homeManager.metsker ];
    };
  };

  flake.modules.homeManager.metsker = { config, ... }: {
    home.username = "metsker";
    home.homeDirectory = "/home/metsker";

    # Tracked configs are symlinked out of the store, so editing one takes effect without a rebuild.
    _module.args.dotfile = path:
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/config/${path}";

    xdg.mimeApps.enable = true;

    # Steam's "Add desktop shortcut" writes to XDG_DESKTOP_DIR; point it where the launcher scans.
    xdg.userDirs = {
      enable = true;
      desktop = "${config.home.homeDirectory}/.local/share/applications";
    };
  };
}
