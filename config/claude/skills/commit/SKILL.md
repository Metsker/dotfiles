---
name: commit
description: Commit the working tree as one or more themed git commits, delegating the commit message to a cheaper model. Use when the user asks to "commit", "make a commit", "commit my changes", or "commit this". Groups unrelated changes into separate commits. Never pushes unless explicitly asked.
---

# Commit

Turn the current working tree into well-scoped git commit(s). Message writing is delegated to Haiku. **Never push.**

## Process

1. **Survey the changes.** Run in one batch:
   - `git status --short` and `git diff --stat` — overview
   - `git diff` (unstaged) and `git diff --staged` (already staged) — read the actual changes
   - Untracked files count too; they must be `git add`ed to be included.

   If there is nothing to commit, say so and stop.

2. **Decide grouping — single vs. multiple commits.**
   - **One commit** when the changes are a single logical unit (one feature, one fix, or tightly related edits).
   - **Multiple themed commits** when the changes span clearly distinct concerns (e.g. a config change + an unrelated docs edit + a separate bugfix). Group by concern.
   - Prefer *fewer, meaningful* commits — don't over-split. Group at the **file/path level** (not hunks) so staging stays reliable.
   - Briefly state the grouping you chose, then proceed (the user already asked you to commit — don't wait for confirmation).

3. **For each group, in order:**
   1. Stage exactly that group's paths: `git add <path> <path>…` (include relevant untracked files). **Never `git add -A` when making themed commits** — it would sweep in other groups.
   2. Read what is now staged: `git diff --staged`.
   3. **Delegate the message to Haiku.** Use the **Agent tool with `model: "haiku"`**, passing the staged diff inline and these rules verbatim:
      - Output ONLY the commit message as raw text — no code fences, no preamble, no explanation.
      - Subject line: imperative mood, concise (aim ≤ 50 chars), saying *what* changed.
      - Add a short body (a line or two) only if the change genuinely needs context; otherwise subject only. Keep it short.
      - **No AI attribution of any kind** — no "Generated with Claude", no `Co-Authored-By`, no emoji trailer, no mention of AI/Claude/Anthropic.
   4. Commit with the returned message and **nothing appended**: `git commit -m "<subject>"` (add a second `-m "<body>"` only if Haiku returned a body). Do not add any trailer.

4. **Report** the commit(s) created: `git log --oneline -n <count>`.

## Never push

Do **not** run `git push` — not even after committing — unless the user explicitly asked to push in their message. If they didn't, stop after committing.

## Guardrails

- Commit to the **current branch**; don't create branches unless asked.
- Don't commit obvious secrets, credentials, or large build artifacts — flag them and leave them unstaged instead.
- If some changes were already staged and others weren't, reconcile: fold them into the right group, or ask if it's unclear.
- Keep this deterministic — only *you* generate the message (via Haiku); never fall back to a hardcoded or templated message.
