{
  description = "NixOS flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    umbriel = {
      url = "github:noctalia-dev/umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Not in nixpkgs yet (NixOS/nixpkgs#447604).
    glide = {
      url = "github:glide-browser/glide.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # glide's theme; its scripts load through fx-autoconfig.
    natsumi = {
      url = "github:greeeen-dev/natsumi-browser";
      flake = false;
    };
    fx-autoconfig = {
      url = "github:MrOtherGuy/fx-autoconfig";
      flake = false;
    };
    # No nixpkgs.follows: match monstar-nix's pinned nixpkgs so the cache hits.
    monstar.url = "github:Metsker/monstar-nix";
    # No nixpkgs.follows: keep the flake's pin so the claude-code.cachix.org cache hits.
    claude-code.url = "github:sadjow/claude-code-nix";
    # Built from source (no binary cache), so follow our nixpkgs to share the Rust toolchain.
    zapret-rust = {
      url = "github:Sergeydigl3/zapret-discord-youtube-rust";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Dendritic: every .nix file under modules/ is a flake-parts module, imported automatically.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
