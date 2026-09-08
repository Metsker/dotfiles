---
name: obsidian-wiki
description: Turn raw capture notes in the Obsidian vaults at ~/notes/obsidian into structured, linked wiki notes. Use when asked to process the inbox queue, structure captured notes, extract concepts into a topic folder, or maintain a topic index there.
---

# Obsidian wiki

Raw capture and structured knowledge are two different layers, and the vault keeps them apart. A
capture is whatever landed in the queue: a voice transcript, a bullet dump, a half-formed idea in
Russian. A structured note is one subject, written so it still makes sense a year later, linked to
the notes around it. This skill is the pipeline from the first to the second.

The source is never the deliverable, and it is never destroyed. Every run leaves the raw file where
it was, with a frontmatter marker recording what came out of it.

## The vaults

Two vaults, both plain markdown under `~/notes/obsidian`, both inside one git repository at
`~/notes` - so every run is revertable, and committing after a run is part of the job.

| vault | queue | structured notes | topic index | vault index |
| --- | --- | --- | --- | --- |
| `brain` | `Inbox/<date>/<time>.md` and `Inbox/<name>.md` | `<Topic>/` at the vault root | `<Topic>/index.md` | `index.md` |
| `gamedev` | `<project>/inbox.md` | `<project>/` | `<project>/Main.md` | `index.md` |

`brain` is the general second brain, `gamedev` holds one folder per game project. Default to `brain`
when the user names neither and the material is not about a specific game.

There is no `raw/` or `wiki/` tree. Two empty directories with those names survive from the
SilverBullet migration and are scheduled for deletion; never file anything into them.

### The shape of `brain`

Topic folders sit directly at the vault root, capitalized, one subject each. As of the last survey:

- Reference collections, where every note follows one schema: `Nature/` (animal and phenomenon
  facts), `Japanese/` (one kanji per note - Meaning, Readings, Shape, Phrases), `ASL/` (one sign per
  note), `Music/` (theory, with Russian subfolders under `Music/Theory/`).
- Smaller topic folders: `Art/`, `Code/`, `Docs/`, `Linux/`, `Sport/`.
- Time-organized: `Inbox/`, `Journal/`.
- Project folders, which carry `status` and `description` on their index: `VPN/`, `Repositories/`,
  `Gamedev/`.
- `attachments/`, which is the configured attachment folder for the whole vault.

A new topic folder is a real decision, not a side effect of filing one note. Propose it in the plan
and let the user approve it; a folder with one note in it is worse than a note in an existing folder
with a good tag.

## The loop

1. **Read the queue.** List the files under `Inbox/` (or the project's `inbox.md`) that do not carry
   `status: processed`. Read them whole - a capture is short, and the structure only emerges from
   all of it.

2. **Survey what already exists**, before deciding anything. Three cheap commands:

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
   ls -d */             # topic folders in play
   ls */index.md        # which topics already have an index
   ```

   Then grep the vault for each subject the capture raises. A subject that already has a note gets
   extended, not duplicated - this is the step that decides whether the vault stays navigable or
   turns into near-duplicate stubs.

3. **Plan, and stop.** Print one line per proposed note before writing anything:

   ```
   create  Nature/Pistol Shrimp.md      cavitation bubble, 4 kPa snap, stuns prey
   extend  Linux/Mount Pi.md            + the bridge mirror path
   merge   Code/Acked Rpcs.md <- Rpc Acks   same subject under two names
   skip                                 "давай обсудим" - instruction to the agent, not content
   ```

   Wait for the user. They know which of these subjects is load-bearing and which is a passing
   thought; you do not.

4. **Write the notes.** One subject per file, in the format below.

5. **Update the topic index** so the new notes are reachable.

6. **Mark the source**, verify, commit.

## Note format

Obsidian conventions, matching what the rest of the vault already uses after the SilverBullet
migration:

```markdown
---
date: 2026-09-08
tags:
  - nature
  - fact
---

The pistol shrimp closes its oversized claw fast enough to collapse a cavitation bubble, and the
collapse - not the claw - is what stuns the prey. The bubble reaches thousands of kelvin for a
fraction of a millisecond, briefly making the animal one of the loudest things in the ocean.

Sound at that intensity is a defense as much as a weapon; see [[Mantis Shrimp Punch]] for the other
solution to the same problem.

![[pistol_shrimp.jpg]]
```

Rules that matter:

- **No `# H1`.** Obsidian uses the filename as the note title, so a heading that repeats it shows up
  twice in every view. Most of the vault has no H1 and should stay that way. The exception is hub
  notes - `index.md`, `Main.md` - where an H1 names the section a reader has navigated into.
  Section headings inside a note (`## Meaning`, `## Readings`) are normal and stay.
- **Tags are a YAML list**, never a comma-separated string. Obsidian's Properties view rewrites the
  string form, and Bases filters read the list.
- **Two tags: one topic, one type.** Both come from the vocabulary the vault already uses, below.
  Run the census in step 2 before inventing anything; a tag that appears once is usually a mistake,
  not a category.
- **Wikilinks are bare**: `[[Set Bonuses]]`, not `[[wiki/rpg/Set Bonuses|Set Bonuses]]`. Both vaults
  are set to `newLinkFormat: shortest`, so the short form resolves and stays readable. The path form
  survives from the SilverBullet era; do not add more of it. The exception is a filename that
  repeats across folders - `gamedev` has three `inbox.md`, so a bare `[[inbox]]` resolves to
  whichever one Obsidian picks. Link those by path with an alias: `[[rpg/inbox|inbox]]`.
- **Attachments embed by name alone**: `![[pistol_shrimp.jpg]]`. Every image lives in
  `brain/attachments/`, which is the configured attachment folder.
- **Callouts are `> [!note]`**, not SilverBullet's `> **note**`.
- Link liberally to notes that do not exist yet. An unresolved link is a legitimate marker of the
  next note to write - but say so in the plan, so the user is not surprised by red links.
- Write the note in the language of its subject, following the capture. Do not translate a Russian
  brainstorm into English, or the other way round.

## The tag vocabulary

Two axes. Every note gets one tag from each, except hub notes, which add `index`.

**Topic** - matches the folder: `nature`, `japanese`, `music`, `asl`, `art`, `code`, `linux`,
`sport`, `docs`, `journal`, `vpn`, `repositories`, `steam`, `unity`, `physics`, `marketing`, and in
`gamedev`: `rpg`, `bet`, `loot`.

**Type** - what kind of note it is, from what the vault actually contains:

| tag | what it marks |
| --- | --- |
| `fact` | a closed piece of reference: one animal, one phenomenon |
| `kanji` | a character note in `Japanese/`, with the fixed schema |
| `lesson` | teaching material worked through in order |
| `theory` | a rule or system, mostly in `Music/` |
| `asl-sign` | one sign in `ASL/`; this one is fused topic and type, and carries no separate `asl` tag |
| `mechanic` | a game rule, in `gamedev` |
| `concept` | a design idea that is not yet a rule |
| `question` | an open question with no answer yet |
| `index` | a hub note holding a base block |
| `project` | a project hub, alongside `index` |
| `inbox` | an unprocessed capture |

Use `fact`, never `facts` - the plural existed once as a stray on an index note and was removed.
The small topic folders (`Linux/`, `Art/`, `Docs/`) carry only a topic tag, with no type; that is
fine, and better than inventing a type to fill the slot. `Music/Theory/` carries two Cyrillic tags,
`ступени` and `интервалы`. Leave them alone unless the user asks to rename them, but do not create
more mixed-script tags - a query written from memory will not find them.

If a capture genuinely needs a type the table does not have, propose it in step 3 with the reason,
and add it here once the user agrees.

## The topic index

Each topic folder has one index, and it is a Bases query rather than a hand-maintained list, so it
never falls out of date:

````markdown
---
tags:
  - index
  - nature
---

# Nature

```base
filters:
  and:
    - file.hasTag("nature")
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

`this` refers to the embedding note, so that second filter keeps the index out of its own table.
Bases is a core plugin and is already enabled in both vaults; no community plugin other than LiveSync
is installed, so never reach for Dataview syntax.

A view accepts `type`, `name`, `filters`, `groupBy`, `summaries`, `order`, `sort` and `limit`.
**`sort` is valid but missing from the published Bases documentation** - it is a list of
`{property, direction}` where direction must be `ASC` or `DESC`, and the Obsidian view parser accepts
it. Do not remove it as a mistake. Anything not in that list is passed through as opaque view data
and will silently do nothing.

`file.hasTag()` is variadic and matches nested tags, so `file.hasTag("nature")` would also catch
`#nature/facts` if hierarchical tags are ever introduced.

An index only needs hand-written prose when the ordering carries meaning the query cannot express - a
reading order, or a hierarchy of concepts. Add that above the base block, not instead of it.

## Marking the source

The raw file stays byte-for-byte intact below its frontmatter. Only the frontmatter grows:

```yaml
---
status: processed
processed: 2026-09-08
wiki:
  - "[[Pistol Shrimp]]"
  - "[[Mantis Shrimp Punch]]"
---
```

A partially processed capture gets `status: partial` and a `remaining:` line naming what was left.
Half a capture processed silently is worse than none, because the marker claims otherwise.

## Verify, then commit

`check.js` walks a vault and reports case-duplicate paths, malformed frontmatter, notes with no
frontmatter, unresolved links and unresolved embeds. Run it after writing, and fix what it names:

```sh
node ~/.claude/skills/obsidian-wiki/check.js brain
```

It exits nonzero when it finds a problem, so it also works as a gate. Unresolved links you created
deliberately as stubs are expected - the report lists them, and you say which ones were intentional
rather than silently ignoring the output.

Then commit in `~/notes`, following the repo's commit style:

```sh
cd ~/notes && git add -A && git commit -m "nature: extract the pistol shrimp facts from the capture"
```

## What is left from the migration

The SilverBullet debt was cleared on 2026-09-08: the case-duplicate `gamedev` folders were merged
into lowercase, the empty `raw/`, `wiki/` and `Database/` trees were deleted, the root-level strays
were filed, and the 260 path-form kanji links were rewritten to the bare form. Two things remain,
both deliberate:

- **`Japanese/石.md` links to `[[虫]]`, which does not exist yet.** A stub marking the next kanji
  note to write. `check.js` reports it; that is expected.
- **`Journal/2026-06-17.md` links to `[[Gamedev/Projects/Glyphs]]`, a dead SilverBullet path.** A
  journal entry is a record of what was written on a day. Do not rewrite it to make a checker happy.

Folder case is now uniform in `gamedev` - `bet`, `loot`, `rpg`, all lowercase. Keep it that way.
Both vaults sync through LiveSync, and case-only duplicates are a known failure mode once a
case-insensitive platform (Android, iOS, Windows) is in the mix, reported as duplicated folders and
as bulk lowercasing of names. `check.js` fails on any case-duplicate path, so a regression is caught
before it syncs.

Note that `brain/Docs/` holds live secrets in plain text - an API key, a national ID number, and the
`tgburner.md` account credentials. Never quote their contents into a commit message, a summary, or
anything that leaves the machine.

## Guardrails

- **Never delete or rewrite raw content.** Rephrasing belongs in the structured note; the capture is
  the record of what was actually said.
- **Never touch `.obsidian/`.** Vault config, plugins and workspace state are not yours.
- Do not restructure existing folders as part of processing a note. Moving notes is its own task with
  its own confirmation.
- Do not invent facts to round out a note. A capture that raises a question the user never answered
  becomes an open question in the note, not a plausible-sounding answer.
- A capture is often addressed to you rather than to the vault - "давай обсудим", "сделай из этого
  промпт". That is an instruction, not content: act on it or raise it, but do not file it as a note.
