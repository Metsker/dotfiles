---
name: writing-commit-messages
description: Uses Linux kernel commit message guidelines. Use when writing or editing Git commit messages.
---

# Writing Commit Messages

Use Linux kernel-style commits:

- Format subjects as `subsystem: imperative summary`, e.g. `ui: add profile overlay toggle`.
- Keep subjects concise and lowercase after the subsystem unless a proper noun requires capitalization.
- Use the imperative mood: `add`, `fix`, `remove`, `update`; avoid `added`, `adds`, or gerunds.
- Write a body only when the subject leaves a real question open - why now, what
  broke, what a reader would otherwise misread. Skip it when the subject already
  explains the change.
- One short paragraph is the default for a body; two is the maximum.
- State the reason, not the diff. Never narrate the symptom in detail.
- Keep the body wrapped to about 75 columns.
- Never add a `Co-Authored-By:` trailer or any other attribution footer.

## Committing

- Commit on the branch that is already checked out. Never create, switch, or
  merge branches on your own initiative - "commit this" means commit it here,
  on the current branch, including when that branch is `master`/`main`. Branch
  only when explicitly asked to.
