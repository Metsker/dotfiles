# Noctalia plugins

Personal Noctalia plugins, written in Luau. Noctalia loads this directory through a
`path` plugin source named `local`, which outranks the built-in `official` and
`community` sources, so a plugin here overrides an upstream plugin with the same id.

```sh
noctalia msg plugins source list   # confirms this directory is registered
noctalia msg plugins list          # shows which plugins are installed and enabled
```

## Layout

Each immediate subdirectory is one plugin, named after the part of the id following
the `/` (so `metsker/window-info` lives in `window-info/`). A plugin directory holds
a `plugin.toml` manifest, one `.luau` script per entry, a `README.md`, and
`translations/en.json` when it has user-facing strings.

`noctalia.d.luau` and `.luaurc` are copied from the upstream `official-plugins` repo
and drive luau-lsp; they are tracked here so type checking works on a fresh checkout.
Refresh both with `scripts/noctalia-refs-update.sh`.

## Entry kinds

A manifest declares entries as TOML array-of-table sections, each pointing at a
script: `[[widget]]` for a bar widget, `[[service]]` for a headless singleton,
`[[shortcut]]` for a control-center tile, `[[panel]]` for a popup surface, and
`[[launcher_provider]]` for a launcher search source. The `example` plugin in
`../refs/official-plugins/example/` demonstrates all of them in one manifest.

## Development loop

Edits to `.luau` files hot-reload automatically. Manifest changes need a config
reload, and a newly added plugin needs to be enabled once:

```sh
noctalia msg config-reload
noctalia msg plugins enable metsker/<plugin>
```

Drive an entry's `onIpc` handler to test it without clicking through the UI. The
target selects which live instances receive the event - `focused`, a connector, or
`all`; a service has no output, so it only matches `all`:

```sh
noctalia msg plugin metsker/window-info:window focused refresh
noctalia msg panel-toggle metsker/<plugin>:<panel-entry>
```

Runtime errors and `log` output land in `~/.cache/noctalia/noctalia.log`.

## API level

`plugin.toml` declares `plugin_api`, the minimum host API a plugin needs. The
installed Noctalia accepts levels 3 through 28; raising a plugin's level makes it
disappear on any host below it. The authoritative list of levels and the feature
each one added is `../refs/noctalia/src/scripting/plugin_api.h`.

## Reference material

`../refs/` holds gitignored shallow clones, refreshed by
`scripts/noctalia-refs-update.sh`:

- `refs/official-plugins/` - the `example` plugin, `noctalia.d.luau`, and the
  `validate-plugins.py` script that upstream CI runs on submissions.
- `refs/noctalia-docs/src/content/docs/noctalia/plugins/development/` - the plugin
  development docs as Markdown: manifest, entries, runtime API, declarative UI,
  workflow and publishing.
- `refs/noctalia/src/scripting/` - the C++ implementation, authoritative wherever
  the docs are thin or stale.

## Publishing

These plugins are consumed as a local path source and need no `catalog.toml`. To
distribute them, move them into a repo of their own, add a `catalog.toml` indexing
every plugin, and register it with
`noctalia msg plugins source add <name> git <url>`. Submitting to the shared store
means a PR against [community-plugins](https://github.com/noctalia-dev/community-plugins);
`official-plugins` is core-team only.
