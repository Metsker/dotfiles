{ inputs, ... }:

# Coding agents - Claude Code, pi, opencode - and the declarative MCP servers they share
# (one read-only JSON file), with each agent's config symlinks and packages.
{
  # No nixpkgs.follows on the input, so this cache actually hits.
  flake.modules.nixos.base.nix.settings = {
    extra-substituters = [ "https://claude-code.cachix.org" ];
    extra-trusted-public-keys = [ "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk=" ];
  };

  flake.modules.homeManager.metsker = { config, lib, pkgs, dotfile, ... }:
    let
      dotfiles = "${config.home.homeDirectory}/dotfiles/config";

      # sadjow/claude-code-nix: hourly-updated build, cached at claude-code.cachix.org.
      claude-code = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

      # Not in nixpkgs, but the npm package declares no dependencies at all - it ships its
      # own bundle - so the tarball plus a node wrapper is the entire build. Drop for
      # pkgs.chrome-devtools-mcp once one exists.
      chrome-devtools-mcp = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "chrome-devtools-mcp";
        version = "1.8.0";
        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-${finalAttrs.version}.tgz";
          hash = "sha256-rAM0QQzqddEaXrtVX7sBOaSjlN412YzCo7wKlZ8ATN0=";
        };
        nativeBuildInputs = [ pkgs.makeWrapper ];
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/chrome-devtools-mcp
          cp -r . $out/lib/chrome-devtools-mcp/
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/chrome-devtools-mcp \
            --add-flags $out/lib/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js
          runHook postInstall
        '';
      });

      # Single declarative source of truth for MCP servers: Claude loads it via --mcp-config,
      # pi reads it as its user-level mcp.json - both take the same mcpServers shape.
      mcpConfig = pkgs.writeText "mcp.json" (builtins.toJSON {
        mcpServers = {
          # --isolated keeps Playwright's profile out of the read-only store.
          # --viewport-size so a screenshot comes out the same size in every
          # session rather than at whatever the browser happened to open at - and
          # so nothing has to resize a tab before it has one, which is its own
          # small trap. Browsers come from dev.nix, which points every
          # playwright on the machine at the set this package already uses.
          playwright = {
            command = "${pkgs.playwright-mcp}/bin/playwright-mcp";
            args = [ "--headless" "--isolated" "--viewport-size" "1440x900" ];
          };
          context7 = { command = "${pkgs.context7-mcp}/bin/context7-mcp"; args = [ ]; };

          # Playwright answers what the DOM says, which for a game drawing into one canvas
          # is nothing at all. This one answers why a frame took 40ms: performance traces,
          # CPU throttling, console and network. Playwright's patched Chrome is passed because the
          # Chrome puppeteer would otherwise fetch is dynamically linked against libraries
          # on no path here - the same trap dev.nix documents for Playwright's browsers.
          chrome-devtools = {
            command = "${chrome-devtools-mcp}/bin/chrome-devtools-mcp";
            args = [
              "--headless"
              "--isolated"
              "--executablePath=${pkgs.playwright-driver.browsers}/chromium-${pkgs.playwright-driver.browsersJSON.chromium.revision}/chrome-linux64/chrome"
              "--viewport=1440x900"
              "--usageStatistics=false"
            ];
          };
        };
      });

      # Linked one skill at a time, not as one directory, because other installers write into ~/.claude/skills too.
      ownSkills = map
        (name: lib.nameValuePair ".claude/skills/${name}" { source = dotfile "claude/skills/${name}"; })
        (builtins.attrNames
          (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../config/claude/skills)));

      # Wrap claude so every launch loads the Nix-managed servers; merges with project .mcp.json.
      # =form is required: --mcp-config is variadic and the space form swallows the subcommand.
      claude = pkgs.writeShellScriptBin "claude" ''
        exec ${claude-code}/bin/claude --mcp-config=${mcpConfig} "$@"
      '';

      # Notification hook in settings.json: pings Telegram when Claude goes idle or asks for permission.
      claude-notify = pkgs.writeShellApplication {
        name = "claude-notify";
        runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils ];
        text = builtins.readFile ../scripts/claude-notify.sh;
      };
    in
    {
      # ln -sf tolerates Claude Code overwriting settings.json at runtime; home.file would collide.
      home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "$HOME/.claude"
        run ln -sf "${dotfiles}/claude/settings.json" "$HOME/.claude/settings.json"
      '';

      home.file = lib.listToAttrs ownSkills // {
        ".claude/CLAUDE.md".source = dotfile "claude/CLAUDE.md";
        ".claude/keybindings.json".source = dotfile "claude/keybindings.json";

        # pi writes settings.json through the link, so the out-of-store symlink survives its rewrites.
        ".pi/agent/settings.json".source = dotfile "pi/settings.json";
        ".pi/agent/keybindings.json".source = dotfile "pi/keybindings.json";
        ".pi/agent/AGENTS.md".source = dotfile "pi/AGENTS.md";
        ".pi/agent/extensions".source = dotfile "pi/extensions";
        # Read-only, so `pi mcp add` and /mcp's saved toggles fail - add servers to mcpConfig instead.
        ".pi/agent/mcp.json".source = mcpConfig;
      };

      home.packages = [
        claude # wrapped claude-code with --mcp-config
        claude-notify
        pkgs.playwright-mcp # bundles its own NixOS chromium
        pkgs.context7-mcp
        chrome-devtools-mcp

        pkgs.pi-coding-agent
        pkgs.opencode
      ];

      programs.fish.shellAliases.c = "claude";
    };
}
