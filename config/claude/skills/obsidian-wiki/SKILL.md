---
name: obsidian-wiki
description: Turn raw capture notes in the Obsidian vaults at ~/notes/obsidian into structured, linked wiki notes. Use when asked to process the raw or inbox queue, structure captured notes, extract concepts into the wiki, or maintain a topic index there.
---

# Obsidian wiki

Raw capture and structured knowledge are two different layers, and the vault keeps them in
two different places. A capture is whatever landed in the queue: a voice transcript, a
bullet dump, a half-formed idea in Russian. A wiki note is one concept, written so it still
makes sense a year later, linked to the notes around it. This skill is the pipeline from
the first to the second.

The source is never the deliverable, and it is never destroyed. Every run leaves the raw
file where it was, with a frontmatter marker recording what came out of it.

## The vaults

Two vaults, both plain markdown under `~/notes/obsidian`, both git repositories - so every
run is revertable, and committing after a run is part of the job.

| vault | queue | wiki layer | topic index |
| --- | --- | --- | --- |
| `brain` | `raw/<topic>/*.md` | `wiki/<topic>/` | `wiki/<topic>/index.md` |
| `gamedev` | `<project>/inbox.md` | `<project>/` | `<project>/Main.md` |

`brain` is the general second brain, `gamedev` holds one folder per game project. Default
to `brain` when the user names neither and the material is not about a specific game.

`gamedev` has case-duplicate folders (`bet` and `Bet`, `loot` and `Loot`) left over from
SilverBullet. They are distinct directories on Linux and their contents were never merged.
Do not guess which one a note belongs in - ask, and do not merge them as a side effect of
processing a note.

## The loop

1. **Read the queue.** List the unprocessed files: everything in the queue that does not
   carry `status: processed`. Read them whole - a capture is short and the structure only
   emerges from all of it.

2. **Survey what already exists**, before deciding anything. Two commands, both cheap:

   ```sh
   cd ~/notes/obsidian/brain
   # tag census - only the tags block of each frontmatter, so base blocks and body
   # lists do not pollute the counts
   find . -name '*.md' -exec awk '
     FNR==1{fm=0; intags=0}
     /^---$/{fm++; next}
     fm==1 && /^tags:/{intags=1; next}
     fm==1 && /^[A-Za-z]/{intags=0}
     fm==1 && intags && /^ *- /{sub(/^ *- /,""); print}
   ' {} + | sort | uniq -c | sort -rn
   ls wiki/   # topics in play
   ```

   Then grep the vault for each concept the capture raises. A concept that already has a
   note gets extended, not duplicated - this is the step that decides whether the wiki
   stays navigable or turns into near-duplicate stubs.

3. **Plan, and stop.** Print one line per proposed note before writing anything:

   ```
   create  wiki/rpg/Set Bonuses.md          set bonuses at 3/5/8 pieces, no item selling
   extend  wiki/rpg/Gacha Economy.md        + crystal healing, + skin bonuses
   merge   wiki/rpg/Shop.md <- Rotating Shop  same mechanic under two names
   skip                                     "давай обсудим" - instruction to the agent, not content
   ```

   Wait for the user. They know which of these concepts is load-bearing and which is a
   passing thought; you do not.

4. **Write the notes.** One concept per file, in the format below.

5. **Update the topic index** so the new notes are reachable.

6. **Mark the source**, verify, commit.

## Note format

Obsidian conventions, matching what the rest of the vault already uses after the
SilverBullet migration:

```markdown
---
date: 2026-09-08
tags:
  - rpg
  - mechanic
source: "[[prompt for rpg bot]]"
---

# Set Bonuses

Items belong to sets of 3, 5 or 8 pieces, and wearing a whole set grants a bonus on top of
the individual items. The set size is the difficulty dial: a 3-piece set is reachable from
the [[Rotating Shop]], an 8-piece set is a collection goal spanning several locations.

Duplicate protection means a set can only be completed, never farmed - see
[[Loot Tables]] for what drops instead once a set is finished.

> [!note]
> Open question: do skins carry set bonuses of their own, or only cosmetics?
```

Rules that matter:

- **Tags are a YAML list**, never a comma-separated string. Obsidian's Properties view
  rewrites the string form, and Bases filters read the list.
- **One topic tag** matching the folder, **one type tag** from a closed set:
  `concept`, `mechanic`, `decision`, `reference`, `howto`, `question`. Reuse a tag the
  vault already has before inventing one - that is what the census in step 2 is for.
- **Wikilinks are bare**: `[[Set Bonuses]]`, not `[[wiki/rpg/Set Bonuses|Set Bonuses]]`.
  Both vaults are set to `newLinkFormat: shortest`, so the short form resolves and stays
  readable. The path form survives from the SilverBullet era; do not add more of it.
  The exception is a filename that repeats across folders - `gamedev` has three
  `inbox.md`, so a bare `[[inbox]]` resolves to whichever one Obsidian picks. Link those
  by path with an alias: `[[rpg/inbox|inbox]]`.
- **Attachments embed by name alone**: `![[thorny_devil.jpg]]`. Every image lives in
  `brain/attachments/`, which is the configured attachment folder.
- **Callouts are `> [!note]`**, not SilverBullet's `> **note**`.
- Link liberally to notes that do not exist yet. An unresolved link is a legitimate marker
  of the next note to write - but say so in the plan, so the user is not surprised by red
  links.
- Write the note in the language of its subject, following the capture. Do not translate
  a Russian brainstorm into English, or the other way round.

## The topic index

Each topic folder has one index, and it is a Bases query rather than a hand-maintained
list, so it never falls out of date:

````markdown
---
tags:
  - index
  - rpg
---

# RPG

```base
filters:
  and:
    - file.hasTag("rpg")
    - file.path != this.file.path
views:
  - type: table
    name: Notes
    order:
      - file.name
      - date
    sort:
      - property: date
        direction: DESC
```
````

`this` refers to the embedding note, so that second filter keeps the index out of its own
table. Bases is a core plugin and is already enabled in both vaults; no community plugin is
installed, so never reach for Dataview syntax.

An index only needs hand-written prose when the ordering carries meaning the query cannot
express - a reading order, or a hierarchy of concepts. Add that above the base block, not
instead of it.

## Marking the source

The raw file stays byte-for-byte intact below its frontmatter. Only the frontmatter grows:

```yaml
---
status: processed
processed: 2026-09-08
wiki:
  - "[[Set Bonuses]]"
  - "[[Rotating Shop]]"
  - "[[Gacha Economy]]"
---
```

A partially processed capture gets `status: partial` and a `remaining:` line naming what
was left. Half a capture processed silently is worse than none, because the marker claims
otherwise.

## Verify, then commit

`check.js` walks a vault and reports unresolved links, unresolved embeds and malformed
frontmatter. Run it after writing, and fix what it names:

```sh
node ~/.claude/skills/obsidian-wiki/check.js brain
```

It exits nonzero when it finds a problem, so it also works as a gate. Unresolved links you
created deliberately as stubs are expected - the report lists them, and you say which ones
were intentional rather than silently ignoring the output.

Then commit in `~/notes`, following the repo's commit style:

```sh
cd ~/notes && git add -A && git commit -m "rpg: extract the shop and set mechanics from the capture"
```

## Guardrails

- **Never delete or rewrite raw content.** Rephrasing belongs in the wiki note; the capture
  is the record of what was actually said.
- **Never touch `.obsidian/`.** Vault config, plugins and workspace state are not yours.
- Do not restructure existing folders as part of processing a note. Moving notes is its own
  task with its own confirmation.
- Do not invent facts to round out a note. A capture that raises a question the user never
  answered becomes an open question in the note, not a plausible-sounding answer.
- A capture is often addressed to you rather than to the vault - "давай обсудим", "сделай
  из этого промпт". That is an instruction, not content: act on it or raise it, but do not
  file it as a wiki note.
