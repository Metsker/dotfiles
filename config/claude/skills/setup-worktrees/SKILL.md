---
name: setup-worktrees
description: Make a fresh git worktree runnable when a dev server, test run, or build fails there with missing modules. Measures whether a plain install already shares the bytes before reaching for a symlink.
---

# Setup Worktrees

A new worktree is a checkout of tracked files only. `node_modules/` is gitignored, so
it is simply not there and every script in a fresh worktree fails on the first import.

The instinct is to link the main checkout's `node_modules` rather than install a second
copy. Measure before you do. A package manager that hardlinks out of a global store has
already solved this, and the link then saves nothing while risking a silent misbuild.

## Install first, and measure what it cost

```bash
bun install          # or pnpm install
```

Numbers from a 123-package bun workspace, cold - no `node_modules` anywhere in the
worktree:

```
116 packages installed [42.00ms]        no network

main checkout's node_modules            154M
worktree's node_modules                 150M
both together, hardlinks counted once   157M
```

The second install cost 3MB and 42ms. Everything else is the same disk blocks: bun
hardlinks package contents out of `~/.bun/install/cache`, so the file in the worktree
and the file in the main checkout are one inode with two names. There is nothing left
for a symlink to save.

pnpm works the same way, out of its own content-addressed store. npm and yarn classic
do not - their cache spares the download but the tree is copied, so a second install
there is a second full copy on disk. That is the case where a link still pays, and the
recipe is below.

## Isolated layouts: why a partial link is worse than none

bun workspaces and pnpm do not build a flat `node_modules`. The root holds only a
content-addressed store, and every workspace package carries its own small
`node_modules` of symlinks into it:

```bash
ls node_modules            # flat: hundreds of package directories
                           # isolated: one entry, .bun or .pnpm
```

Linking just the root there brings the store but none of the per-package link trees or
their `.bin`, so the first script still dies on `vite: command not found`. Linking the
per-package directories too is worse, and quietly: a workspace dependency is a relative
link out of the package -

```
miniapps/rpg/node_modules/@tiled/core -> ../../../../shared/core
```

- and a symlinked *directory* resolves that against the link's target, not the
worktree. Demonstrate it on any branch by dropping a file into the shared package and
asking whether the consumer can see it:

```bash
echo '// only on this branch' > shared/core/src/MARKER.ts
ls miniapps/rpg/node_modules/@tiled/core/src/MARKER.ts
```

Installed per worktree, the marker is there and `@tiled/core` resolves to the
worktree's own `shared/core`. With the per-package tree linked to the main checkout's,
the same path resolves to `<main>/shared/core` and the marker is gone - the branch is
compiling the main checkout's shared code, with no error and no warning. That is the
exact failure a worktree exists to prevent, and nothing reports it.

Install instead. It is milliseconds.

## What sharing a store does *not* break

Worth knowing, because it is the intuitive fear and it is wrong: the store itself is
safe to share. It is keyed by name and exact version, so a branch pinning a different
version *adds* an entry beside the old one rather than replacing it -

```
node_modules/.bun/pixi.js@8.19.0     <- the branch's
node_modules/.bun/pixi.js@8.20.1     <- still there, main's links still resolve
```

- and neither the worktree's install nor the main checkout's afterwards prunes what the
other needs. Even a worktree whose `package.json` declares no workspaces at all left the
69-entry store untouched and the main checkout building.

So the argument against the link is not corruption. It is that it buys 3MB, and that
the per-package trees above will silently lie to you. The one real cost of a shared
store is that it only grows: the stray `pixi.js@8.19.0` above was 80MB, and nothing ever
collects it.

## When a link is the right answer

Where the build product is not content-addressed and rebuilding costs real time, link
it. Cargo is the expensive case, and a tracked config makes it easy to miss: it can
point the cache at a path relative to the repo root, so it lands outside the checkout
and `git status --ignored` never lists it - it looks linked when nothing is.

```toml
# .cargo/config.toml, tracked, so every worktree carries it
[build]
target-dir = "../.cache/my-cargo-target"
```

That resolves per checkout, so the worktree compiles the whole dependency tree again -
tens of minutes and gigabytes for a Tauri app. Link the resolved directory, not the one
inside the worktree. Run from inside the worktree; the first entry of
`git worktree list` is always the main checkout:

```bash
rm -rf ../.cache/my-cargo-target
ln -s "$(git worktree list --porcelain | head -1 | sed 's/^worktree //')/../.cache/my-cargo-target" ../.cache/my-cargo-target
```

Registry crates are keyed by their own source, so they are reused; local crates stay
separate units keyed by path and coexist in the one directory. Cargo takes a file lock
on it, so builds in the main checkout and a worktree now serialize rather than run in
parallel. Swap it while nothing is compiling.

The same shape holds for anything gitignored, expensive, and not shared by the tool
itself: a downloaded asset cache, a model checkpoint, `vendor/`. A `.venv` is usually
*not* one of these - it carries absolute paths in its scripts and its `pyvenv.cfg`, so
link it and the worktree runs the main checkout's interpreter prefix. Recreate it and
let pip's wheel cache do the sharing.

For those, the plain link:

```bash
ln -sfn "$(git worktree list --porcelain | head -1 | sed 's/^worktree //')/<dir>" <dir>
```

`ln -sfn` refuses rather than clobbers if a real directory is already there.

## Undoing a link that should have been an install

```bash
rm node_modules && bun install
```

`rm`, never `rm -rf` - the target is a symlink, and the recursive form empties the main
checkout's tree through it. If the per-package trees were linked too, clear those first:

```bash
find . -maxdepth 3 -name node_modules -not -path ./node_modules -exec rm -rf {} +
```

## Caches inside node_modules

A shared `node_modules` also means shared tool caches under it, each run invalidating
the last one's work. Vite is the common case - `node_modules/.vite` - and the fix is in
the project's config:

```js
// vite.config.ts
cacheDir: '.vite',   // gitignore it
```

An isolated layout does not have this problem: Vite resolves `node_modules/.vite`
against the package it is building, and under bun or pnpm that directory is already the
worktree's own. Setting `cacheDir` there is harmless but buys nothing.

## Name the tab after the branch

Every worktree serves the same app, and with a port pinned in config they land on
adjacent ports rather than the same one - so the browser ends up with a row of
identical tabs. Tag the title with the branch at dev time. It costs one plugin and
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
