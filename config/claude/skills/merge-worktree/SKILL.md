---
name: merge-worktree
description: Merge a herdr-created git worktree back into the main checkout and clean it up. Use when asked to merge, land, or finish a worktree branch.
---

# Merging Worktrees

Worktrees live in `~/.herdr/worktrees/<repo>/<branch>`; the main checkout stays on its
own branch and never switches. Merge from the main checkout, never by checking the
worktree branch out twice - git forbids that.

## Steps

1. In the worktree, commit everything (see `writing-commit-messages`).
2. Rebase onto the target branch: `git rebase <target>`. Resolve conflicts here, where
   the broken state is isolated.
3. From the main checkout: `git merge --ff-only <branch>`. It refuses instead of
   producing a surprise merge commit if the rebase was skipped or incomplete.
4. Clean up, below. A merged worktree is done, and leaving the checkout behind is a
   stale copy of the branch to confuse the next session.

Review before merging with `git diff <target>...<branch>` (three dots - against the
merge base).

## Cleanup, unless told to keep it

Runs by default once the merge lands. Skip it only when the user said to - "keep the
worktree", "leave it open", or plans to keep working on the branch.

Cleanup is all four: the processes go, the checkout goes, the branch goes, the space
closes. Closing the space is part of the job, not a follow-up to hand back to the user.

**Step 4 is not a confirmation point.** It ends the pane this session runs in, which
reads like the kind of thing to check before doing and is not one: the merge has landed,
the files are in the main checkout, and what is left is an empty room. Stopping after
step 3 to offer step 4 leaves the job three quarters done and hands back the one part
that was asked for. Print the report and then close, in the same turn - reporting first
is what makes closing unasked safe, not a request for permission to close.

`herdr worktree list` prints `path`, `branch` and `open_workspace_id` for every worktree
of the current repo - one call has every id the steps below need. Run them from the main
checkout, in this order. The last one kills the pane this session runs in, so everything
else must be done and reported before it:

1. Close every pane of the worktree's space but this one. A process that outlives the
   checkout writes its files back into the path step 2 removes - see below:

   ```bash
   self=$(herdr pane current | jq -r .result.pane.pane_id)
   herdr pane list --workspace <id> |
     jq -r --arg self "$self" '.result.panes[] | select(.pane_id != $self) | .pane_id' |
     xargs -r -n1 herdr pane close
   ```

   Nothing matches `$self` when this session lives in another space, so every pane
   closes and step 4 has nothing left to do.
2. `git worktree remove --force <path>` - drops the checkout and leaves the space
   alone, so there is still a shell to run the rest in.
3. `git branch -d <branch>` - `-d` refuses if unmerged, which is the check you want.
4. `herdr workspace close <id>` - last, as a call of its own.

`herdr worktree remove --workspace <id> --force` does the lot in one command, but it
kills the panes at once, so the branch never gets deleted. Use it only when the branch
is meant to survive.

To keep the files and only close the space, run step 4 alone. Reopen later with
`herdr worktree open --cwd <repo> --branch <branch>`.

If a worktree directory was deleted by hand, run `git worktree prune`.

## Why the panes go first

Step 2 deletes the directory while the space is still open, so anything still running
there writes its files back into the path git just removed. Vite is the loud case: it
resolves its cache dir once per config load, and with the worktree's `package.json` gone
it falls back from `node_modules/.vite` to `<root>/.vite`, then `mkdir -p`s the whole
worktree path to hold it. Tiled drops a `.tiled-session` on exit. The directory
reappears owning nothing but cache, and git no longer knows about it.

Killing the panes first covers every such tool, so this should not happen. To clear
leftovers from a cleanup that skipped step 1 - one level per branch, and a live worktree
always has a `.git` file:

```bash
find ~/.herdr/worktrees -mindepth 2 -maxdepth 2 -type d -not -name '.*' '!' -exec test -e {}/.git ';' -print
```

Check the list, then swap `-print` for `-exec rm -rf {} +`. `-not -name '.*'` keeps the
shared caches `setup-worktrees` links next to the worktrees, like `<repo>/.cache`. The
path is outside any project, so auto-mode stops for approval - ask rather than skip it.

## In this repo

- A merge that bumps `config/nvim` brings only the gitlink. Run
  `git submodule update --init` in the main checkout afterwards.
- Never run `nh os switch` from a worktree - `home.nix` links `~/.config` by absolute
  path, so it would repoint every symlink at the worktree. Rebuild from the main
  checkout only.
