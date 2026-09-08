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
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    driftwm = {
      url = "github:malbiruk/driftwm";
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
    # No nixpkgs.follows: match monstar-nix's pinned nixpkgs so the cache hits.
    monstar.url = "github:Metsker/monstar-nix";
    # No nixpkgs.follows: keep the flake's pin so the claude-code.cachix.org cache hits.
    claude-code.url = "github:sadjow/claude-code-nix";
    # Agent Skills for Obsidian. Not a flake - it is a plain tree of SKILL.md directories,
    # so it is consumed as a source and symlinked into ~/.claude/skills by claude.nix.
    obsidian-skills = {
      url = "github:kepano/obsidian-skills";
      flake = false;
    };
    ai-usagebar = {
      url = "github:akitaonrails/ai-usagebar";
      # Upstream pins a darwin nixpkgs branch; follow ours so there is only one.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Dendritic: every .nix file under modules/ is a flake-parts module, imported automatically.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
