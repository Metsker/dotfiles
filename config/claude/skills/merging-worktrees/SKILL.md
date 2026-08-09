---
name: merging-worktrees
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
4. Stop here. Leave the worktree and its space alone unless cleanup was asked for.

Review before merging with `git diff <target>...<branch>` (three dots - against the
merge base).

## Cleanup, only when asked

Cleanup is all three: the checkout goes, the branch goes, the space closes. Closing
the space is part of the job, not a follow-up to hand back to the user.

Find the workspace id with `herdr worktree list --json`, then run these from the main
checkout, in this order. The last one kills the panes this session runs in, so
everything else must be done and reported before it:

1. `git worktree remove --force <path>` - drops the checkout and leaves the space
   alone, so there is still a shell to run the rest in.
2. `git branch -d <branch>` - `-d` refuses if unmerged, which is the check you want.
3. `herdr workspace close <id>` - last, as a call of its own.

`herdr worktree remove --workspace <id> --force` does the lot in one command, but it
kills the panes at once, so the branch never gets deleted. Use it only when the branch
is meant to survive.

To keep the files and only close the space, run step 3 alone. Reopen later with
`herdr worktree open --cwd <repo> --branch <branch>`.

If a worktree directory was deleted by hand, run `git worktree prune`.

## In this repo

- A merge that bumps `config/nvim` brings only the gitlink. Run
  `git submodule update --init` in the main checkout afterwards.
- Never run `nh os switch` from a worktree - `home.nix` links `~/.config` by absolute
  path, so it would repoint every symlink at the worktree. Rebuild from the main
  checkout only.
