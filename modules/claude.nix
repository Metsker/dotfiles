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

      # Single declarative source of truth for MCP servers, loaded via --mcp-config.
      mcpConfig = pkgs.writeText "claude-mcp.json" (builtins.toJSON {
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
          # CPU throttling, console and network. Chromium is passed explicitly because the
          # Chrome puppeteer would otherwise fetch is dynamically linked against libraries
          # on no path here - the same trap dev.nix documents for Playwright's browsers.
          chrome-devtools = {
            command = "${chrome-devtools-mcp}/bin/chrome-devtools-mcp";
            args = [
              "--headless"
              "--isolated"
              "--executablePath=${pkgs.chromium}/bin/chromium"
              "--viewport=1440x900"
              "--usageStatistics=false"
            ];
          };
        };
      });

      # ~/.claude/skills merges two sources, so it is linked one skill at a time rather than as
      # a single directory. The hand-written ones stay out-of-store symlinks, so editing a
      # SKILL.md still takes effect without a rebuild; kepano/obsidian-skills is pinned by the
      # flake input and read-only in the store. Only adding or removing a skill needs a rebuild.
      skillsIn = src:
        builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir src));
      skillLinks = mkSource: names:
        map (name: lib.nameValuePair ".claude/skills/${name}" { source = mkSource name; }) names;
      # Own skills come last, so a name they share with an upstream one resolves to ours.
      vendoredSkills = skillLinks
        (name: "${inputs.obsidian-skills}/skills/${name}")
        (skillsIn "${inputs.obsidian-skills}/skills");
      ownSkills = skillLinks
        (name: dotfile "claude/skills/${name}")
        (skillsIn ../config/claude/skills);

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

      # ~/.claude/skills used to be one symlink to the dotfiles directory. It is now a real
      # directory holding one symlink per skill, so that generation's link has to go first:
      # left in place, home-manager writes the per-skill links *through* it, straight into
      # the source directory, where each one then points back at itself. Runs before
      # checkLinkTargets so the file phase sees a clean path.
      home.activation.claudeSkillsLegacyLink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/.claude/skills" ]; then
          run rm "$HOME/.claude/skills"
        fi
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

      home.file = lib.listToAttrs (vendoredSkills ++ ownSkills) // {
        ".claude/CLAUDE.md".source = dotfile "claude/CLAUDE.md";
        ".claude/keybindings.json".source = dotfile "claude/keybindings.json";
      };

      home.packages = [
        claude # wrapped claude-code with --mcp-config
        pkgs.playwright-mcp # bundles its own NixOS chromium
        pkgs.context7-mcp
        chrome-devtools-mcp
        # ai-usagebar + ai-usagebar-tui: plan usage from ~/.claude/.credentials.json.
        inputs.ai-usagebar.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

      programs.fish.shellAliases.c = "claude";
    };
}
