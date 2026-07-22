{ config, lib, pkgs, ... }:

# All Claude Code config in one place: config symlinks, the Playwright MCP
# registration, and the packages themselves.
let
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";
  create_symlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # ln -sf tolerates Claude Code overwriting settings.json at runtime; home.file would collide.
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.claude"
    run ln -sf "${dotfiles}/claude/settings.json" "$HOME/.claude/settings.json"
  '';

  # Register nixpkgs Playwright MCP; --isolated keeps the profile out of the read-only store.
  home.activation.claudePlaywrightMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.claude.json"
    [ -e "$cfg" ] || echo '{}' > "$cfg"
    ${pkgs.jq}/bin/jq \
      '.mcpServers.playwright = { command: "${pkgs.playwright-mcp}/bin/playwright-mcp", args: ["--headless", "--isolated"] }' \
      "$cfg" > "$cfg.new"
    run mv "$cfg.new" "$cfg"
  '';

  home.file.".claude/CLAUDE.md".source = create_symlink "${dotfiles}/claude/CLAUDE.md";
  home.file.".claude/skills".source = create_symlink "${dotfiles}/claude/skills";

  home.packages = with pkgs; [
    claude-code
    playwright-mcp # bundles its own NixOS chromium
  ];
}
