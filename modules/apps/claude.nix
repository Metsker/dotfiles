{ inputs, ... }:

# All Claude Code config in one place: config symlink, declarative MCP servers
# (a read-only --mcp-config file), stale-state pruning, and the packages.
{
  # No nixpkgs.follows on the input, so this cache actually hits.
  flake.modules.nixos.base.nix.settings = {
    extra-substituters = [ "https://claude-code.cachix.org" ];
    extra-trusted-public-keys = [ "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk=" ];
  };

  flake.modules.homeManager.metsker = { config, lib, pkgs, dotfile, ... }:
    let
      dotfiles = "${config.home.homeDirectory}/dotfiles/config";

      # Built from source by the upstream flake; tracks whatever the fff input pins.
      fff-mcp = inputs.fff.packages.${pkgs.stdenv.hostPlatform.system}.fff-mcp;

      # sadjow/claude-code-nix: hourly-updated build, cached at claude-code.cachix.org.
      claude-code = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # Single declarative source of truth for MCP servers, loaded via --mcp-config.
      mcpConfig = pkgs.writeText "claude-mcp.json" (builtins.toJSON {
        mcpServers = {
          # --isolated keeps Playwright's profile out of the read-only store.
          playwright = { command = "${pkgs.playwright-mcp}/bin/playwright-mcp"; args = [ "--headless" "--isolated" ]; };
          context7 = { command = "${pkgs.context7-mcp}/bin/context7-mcp"; args = [ ]; };
          fff = { command = "${fff-mcp}/bin/fff-mcp"; args = [ ]; };
        };
      });

      # Wrap claude so every launch loads the Nix-managed servers; merges with project .mcp.json.
      # =form is required: --mcp-config is variadic and the space form swallows the subcommand.
      claude = pkgs.writeShellScriptBin "claude" ''
        exec ${claude-code}/bin/claude --mcp-config=${mcpConfig} "$@"
      '';
    in
    {
      # ln -sf tolerates Claude Code overwriting settings.json at runtime; home.file would collide.
      home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "$HOME/.claude"
        run ln -sf "${dotfiles}/claude/settings.json" "$HOME/.claude/settings.json"
      '';

      # One-time: drop the stale user-scope MCP entries the old activation wrote; MCP now comes from --mcp-config.
      home.activation.claudeMcpCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.claude.json"
        if [ -e "$cfg" ]; then
          ${pkgs.jq}/bin/jq 'del(.mcpServers.playwright, .mcpServers.context7)' "$cfg" > "$cfg.new"
          run mv "$cfg.new" "$cfg"
        fi
      '';

      # context7/playwright ship no version in the official marketplace, so their install
      # records nag "Plugins updated" forever. Both now run via --mcp-config; drop the stale installs.
      home.activation.claudePluginCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        reg="$HOME/.claude/plugins/installed_plugins.json"
        if [ -e "$reg" ]; then
          ${pkgs.jq}/bin/jq \
            'del(.plugins["context7@claude-plugins-official"], .plugins["playwright@claude-plugins-official"])' \
            "$reg" > "$reg.new"
          run mv "$reg.new" "$reg"
        fi
      '';

      home.file.".claude/CLAUDE.md".source = dotfile "claude/CLAUDE.md";
      home.file.".claude/keybindings.json".source = dotfile "claude/keybindings.json";
      home.file.".claude/skills".source = dotfile "claude/skills";

      home.packages = [
        claude # wrapped claude-code with --mcp-config
        pkgs.playwright-mcp # bundles its own NixOS chromium
        pkgs.context7-mcp
        fff-mcp
      ];

      programs.fish.shellAliases.c = "claude";
    };
}
