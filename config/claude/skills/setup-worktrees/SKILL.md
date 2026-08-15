---
name: setup-worktrees
description: Make a fresh git worktree runnable by linking the main checkout's dependencies instead of installing per worktree. Use when a dev server, test run, or build fails in a worktree with missing modules.
---

# Setup Worktrees

A new worktree is a checkout of tracked files only. `node_modules/` is gitignored, so
it is simply not there and every `npm run` in a fresh worktree fails on the first
import.

Link it rather than install it. Branches off the same repo share a `package.json`, so
a second install is a second copy of the whole dependency tree for the same answer.

Run from inside the worktree - the first entry of `git worktree list` is always the
main checkout:

```bash
ln -sfn "$(git worktree list --porcelain | head -1 | sed 's/^worktree //')/node_modules" node_modules
```

It refuses rather than clobbers if a real `node_modules` directory is already there.
Verify with whatever the worktree is for - `npm run dev`, `npm test`.

The same holds for any gitignored directory the build needs and git does not carry:
`.venv`, `vendor/`, a downloaded asset cache. Link the main checkout's.

## Build caches that live outside the worktree

A tracked config can point the cache at a path relative to the repo root, so it lands
outside the checkout and `git status --ignored` never lists it - it looks linked when
nothing is. Cargo is the expensive case:

```toml
# .cargo/config.toml, tracked, so every worktree carries it
[build]
target-dir = "../.cache/my-cargo-target"
```

That resolves per checkout, so the worktree compiles the whole dependency tree again -
tens of minutes and gigabytes for a Tauri app. Link the resolved directory, not the
one inside the worktree:

```bash
rm -rf ../.cache/my-cargo-target
ln -s "$(git worktree list --porcelain | head -1 | sed 's/^worktree //')/../.cache/my-cargo-target" ../.cache/my-cargo-target
```

Registry crates are keyed by their own source, so they are reused; local crates stay
separate units keyed by path and coexist in the one directory. Cargo takes a file lock
on it, so builds in the main checkout and a worktree now serialize rather than run in
parallel. Swap it while nothing is compiling.

## Install for real when the branch changed the deps

The link is one tree for every worktree, so a branch that adds, removes, or bumps a
dependency needs its own:

```bash
rm node_modules && npm install
```

Tell the user, since it costs disk and the link has to come back after the branch
lands.

## Caches inside node_modules

Tooling that caches under `node_modules/` now has every worktree writing to one
directory, each run invalidating the last one's work. Vite is the common case -
`node_modules/.vite` - and the fix is in the project's config rather than here:

```js
// vite.config.ts
cacheDir: '.vite',   // gitignore it
```

A config change lands on one branch, so it only takes effect in worktrees that carry
it. Until then the symptom is a harmless "Forced re-optimization of dependencies" on
every start.

## Name the tab after the branch

Every worktree serves the same app on its own port, so the browser ends up with a row
of identical tabs. Tag the title with the branch at dev time - it costs one plugin and
never ships, since `apply: 'serve'` leaves the build alone:

```ts
// vite.config.ts
import { execSync } from 'node:child_process'
import { defineConfig, type Plugin } from 'vite'

const branchTitle: Plugin = {
  name: 'branch-title',
  apply: 'serve',
  transformIndexHtml: (html) =>
    html.replace(/<title>(.*?)<\/title>/, (_, title) => {
      const branch = execSync('git branch --show-current', { encoding: 'utf8' }).trim()
      return `<title>${title} [${branch}]</title>`
    }),
}

export default defineConfig({ plugins: [svelte(), branchTitle] })
```

`git branch --show-current` reads the worktree's own HEAD, so each server tags itself.
Multi-entry projects get every page tagged - `transformIndexHtml` runs per HTML entry.
