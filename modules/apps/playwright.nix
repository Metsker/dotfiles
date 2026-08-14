{
  # Playwright browsers, once, for everything on the machine.
  #
  # The browsers npm fetches are dynamically linked against libraries that are on
  # no path here, so `playwright install` in any project downloads a few hundred
  # megabytes that can never launch - it fails complaining about libgtk-3.so.0 and
  # a page of friends. nixpkgs patches its own set instead, and
  # PLAYWRIGHT_BROWSERS_PATH is what points a project's playwright at those.
  #
  # Same derivation pkgs.playwright-mcp already bakes into its own wrapper (see
  # claude.nix), so the browser Claude drives and the browser a test suite drives
  # cannot drift apart.
  #
  # The catch is worth writing down, because the error it gives is not obvious: a
  # browser directory in there is named for its *revision*, not for a version
  # range, so npm playwright only finds these when its version matches the
  # driver's. Anything else says "Executable doesn't exist at
  # .../chromium_headless_shell-1234" and suggests running `playwright install`,
  # which is the one thing that cannot help. PLAYWRIGHT_NIX_VERSION is that
  # version, so a project can pin against it rather than guess:
  #
  #   npm i -D playwright@$PLAYWRIGHT_NIX_VERSION
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.sessionVariables = {
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
      PLAYWRIGHT_NIX_VERSION = pkgs.playwright-driver.version;
      # Nothing it could download would run, so fail fast on a version mismatch
      # rather than spending the bandwidth to fail later.
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    };
  };
}
