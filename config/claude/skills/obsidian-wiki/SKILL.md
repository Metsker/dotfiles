---
name: obsidian-wiki
description: Turn raw capture notes in the Obsidian vaults at ~/notes/obsidian into structured, linked wiki notes. Use when asked to process the raw queue, structure captured notes, or extract concepts into the wiki there.
---

# Obsidian wiki

Raw capture and structured knowledge are two different layers, and the vault keeps them in two
different trees. A capture is whatever landed in the day: a voice transcript, a bullet dump, a
half-formed idea in Russian. A wiki note is one subject, written so it still makes sense a year
later, linked to the notes around it. This skill is the pipeline from the first to the second.

The source is never the deliverable, and it is never destroyed. Every run leaves the raw file where
it was, with a frontmatter marker recording what came out of it.

## The vaults

Two vaults, both plain markdown under `~/notes/obsidian`, both inside one git repository at
`~/notes` - so every run is revertable, and committing after a run is part of the job.

| vault | queue | structured notes |
| --- | --- | --- |
| `brain` | `Raw/YYYY-MM-DD.md`, plus named captures `Raw/<name>.md` | `Wiki/<Topic>/` |
| `gamedev` | `<project>/inbox.md` | `<project>/` |

`brain` is the general second brain, `gamedev` holds one folder per game project. Default to `brain`
when the user names neither and the material is not about a specific game.

### The shape of `brain`

Three top-level folders - `Raw/`, `Wiki/` and `Sensitive/` - plus `attachments/`. That is the whole
vault.

`Raw/` is the daily note folder, and Obsidian's Daily notes core plugin is pointed at it in
`.obsidian/daily-notes.json`. One note per day, `tags: [journal]` and a `date:` property. Captures
made during a day live inside that day's note under a `## HH:MM` heading. A capture with no natural
day - a work transcript, a long dump - stays a named file in `Raw/` tagged `inbox`.

`Wiki/` holds one folder per topic:

- Reference collections, where every note follows one schema: `Wiki/Nature/` (one animal or
  phenomenon per note), `Wiki/Japanese/` (one kanji - Meaning, Readings, Shape, Phrases),
  `Wiki/ASL/` (one sign), `Wiki/Music/` (theory, with Russian subfolders under `Music/Theory/`).
- Smaller topic folders: `Wiki/Art/`, `Wiki/Code/`, `Wiki/Gamedev/`, `Wiki/Linux/`, `Wiki/Sport/`.

`Sensitive/` is a third top-level folder, a sibling of `Raw/` and `Wiki/` and deliberately outside
the knowledge tree. It is **not knowledge**: it holds an API key, a national ID number and account
credentials in plain text, tagged `docs`. Never quote its contents into a commit message, a summary,
a report or anything else that leaves the machine, and never file a note into it. It sits outside
`Wiki/` so that greps and queries over the wiki do not return secrets - keep it that way.

A new topic folder is a real decision, not a side effect of filing one note. Propose it in the plan
and let the user approve it; a folder with one note in it is worse than a note in an existing folder
with a good tag.

**`Wiki/Nature/`, `Wiki/Japanese/` and `Wiki/ASL/` are fed by a daily cron job, not written by
hand.** The job runs off this machine - the vault is reachable from a Raspberry Pi over the LiveSync
bridge (see `Wiki/Linux/Mount Pi.md`) - and delivers one fact, one kanji or one sign per day. Two
consequences: new notes appearing in those folders with no commit from anyone are normal, and if
those folders are ever moved or renamed again, the job keeps writing to the old path and silently
recreates it. Say so before proposing any move that touches them.

### No index notes in `brain`

`brain` has no `index.md` anywhere, at the vault root or in a topic folder, and this is deliberate.
The folder tree is the navigation: `Wiki/Nature/` in the file explorer is the same list a base query
would render. Do not create index notes, folder notes or maps of content in `brain` unless the user
asks for one.

`gamedev` is different and keeps its indexes - `gamedev/index.md` and `<project>/Main.md` - because
its projects need prose and a hand-written reading order, not a file listing.

## The loop

1. **Read the queue.** List the files in `Raw/` that have no `wiki:` key at all, plus any that carry
   `status: partial`. Read them whole - a capture is short, and the structure only emerges from all
   of it.

   Expect most of the queue to yield nothing. `Raw/` is where the day is recorded, and a day is
   usually a list of finished tasks - a record, not raw material. Marking ten days reviewed and
   extracting one note is a normal run; inventing notes to justify the run is the failure mode to
   avoid here.

2. **Survey what already exists**, before deciding anything. Two cheap commands:

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
   ls -d Wiki/*/          # topics in play
   ```

   Then grep the vault for each subject the capture raises. A subject that already has a note gets
   extended, not duplicated - this is the step that decides whether the wiki stays navigable or
   turns into near-duplicate stubs.

3. **Plan, and stop.** Print one line per proposed note before writing anything:

   ```
   create  Wiki/Nature/Pistol Shrimp.md    cavitation bubble, 4 kPa snap, stuns prey
   extend  Wiki/Linux/Mount Pi.md          + the bridge mirror path
   merge   Wiki/Code/Acked Rpcs.md <- Rpc Acks   same subject under two names
   skip                                    "давай обсудим" - instruction to the agent, not content
   ```

   Wait for the user. They know which of these subjects is load-bearing and which is a passing
   thought; you do not.

4. **Write the notes.** One subject per file, in the format below.

5. **Mark the source**, verify, commit.

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

The `obsidian-markdown` skill covers Obsidian's syntax in general - wikilinks, embeds, callouts,
properties. What follows is only where this vault has settled on one option among several, or
differs from the default advice.

Rules that matter:

- **No `# H1`.** Obsidian uses the filename as the note title, so a heading that repeats it shows up
  twice in every view. Most of the vault has no H1 and should stay that way. Section headings inside
  a note (`## Meaning`, `## Readings`) are normal and stay, as are the `## HH:MM` headings that
  separate captures inside a daily note.
- **Tags are a YAML list**, never a comma-separated string. Obsidian's Properties view rewrites the
  string form, and Bases filters read the list.
- **Two tags: one topic, one type**, from the vocabulary below. Run the census in step 2 before
  inventing anything; a tag that appears once is usually a mistake, not a category.
- **Wikilinks are bare**: `[[Set Bonuses]]`, not `[[Wiki/rpg/Set Bonuses|Set Bonuses]]`. Both vaults
  are set to `newLinkFormat: shortest`, so the short form resolves and stays readable, and it
  survives a folder move untouched. The path form survives from the SilverBullet era; do not add
  more of it. The exception is a filename that repeats across folders - `gamedev` has three
  `inbox.md`, so a bare `[[inbox]]` resolves to whichever one Obsidian picks. Link those by path
  with an alias: `[[rpg/inbox|inbox]]`.
- **Attachments embed by name alone**: `![[pistol_shrimp.jpg]]`. Every image lives in
  `brain/attachments/`, which is the configured attachment folder and stays at the vault root.
- **Callouts are `> [!note]`**, not SilverBullet's `> **note**`.
- Link liberally to notes that do not exist yet. An unresolved link is a legitimate marker of the
  next note to write - but say so in the plan, so the user is not surprised by red links.
- Write the note in the language of its subject, following the capture. Do not translate a Russian
  brainstorm into English, or the other way round.

## The tag vocabulary

Two axes. Every wiki note gets one tag from each.

**Topic** - matches the folder: `nature`, `japanese`, `music`, `art`, `code`, `linux`, `sport`,
`gamedev`, `docs`, and in `gamedev`: `rpg`, `bet`, `loot`.

**Type** - what kind of note it is, from what the vault actually contains:

| tag | what it marks |
| --- | --- |
| `fact` | a closed piece of reference: one animal, one phenomenon |
| `kanji` | a character note in `Wiki/Japanese/`, with the fixed schema |
| `lesson` | teaching material worked through in order |
| `theory` | a rule or system, mostly in `Wiki/Music/` |
| `asl-sign` | one sign in `Wiki/ASL/`; fused topic and type, carries no separate `asl` tag |
| `mechanic` | a game rule, in `gamedev` |
| `concept` | a design idea that is not yet a rule |
| `question` | an open question with no answer yet |
| `project` | a project hub in `gamedev` |
| `index` | a hub note holding a base block - `gamedev` only |
| `journal` | a daily note in `Raw/` |
| `inbox` | a named capture in `Raw/` with no natural day |

Use `fact`, never `facts`. The small topic folders (`Wiki/Linux/`, `Wiki/Art/`) carry only a topic
tag with no type; that is fine, and better than inventing a type to fill the slot.
`Wiki/Music/Theory/` carries two Cyrillic tags, `ступени` and `интервалы`. Leave them alone unless
the user asks to rename them, but do not create more mixed-script tags - a query written from memory
will not find them.

If a capture genuinely needs a type the table does not have, propose it in step 3 with the reason,
and add it here once the user agrees.

## Marking the source

The raw file stays byte-for-byte intact below its frontmatter. Only the frontmatter grows:

```yaml
---
tags:
  - journal
date: 2026-09-08
wiki:
  - "[[Pistol Shrimp]]"
  - "[[Mantis Shrimp Punch]]"
---
```

**A daily note never gets `status: processed`.** Since journal and capture live in the same file,
part of it is a record of the day that is not meant to become anything, so the file is never "done".
The `wiki:` list is the marker: it records what came out, and it grows if more is extracted later.
Named captures in `Raw/` - a work transcript, a dump - can be finished, and those do take
`status: processed`.

A day that was read and yielded nothing gets `wiki: []`. The empty list is what separates "reviewed,
nothing in it" from "never looked at", and without it every future run re-reads the same finished
task lists. It is the same key rather than a second one, so there is one concept to remember, and a
day marked this way still gains real entries later if something in it turns out to matter.

**There is no archive.** A processed day stays exactly where it is. `Raw/` sorted by name is an
unbroken record of the year, and moving days out of it once they are reviewed would split that
timeline on an axis that has nothing to do with time. It would also take those days out of the
Daily notes plugin's previous/next navigation, which looks in the configured folder.

A partially processed capture gets `status: partial` and a `remaining:` line naming what was left.
Half a capture processed silently is worse than none, because the marker claims otherwise.

## Verify, then commit

Two checks, and they answer different questions. `obsidian unresolved` is authoritative for links,
because it reads the index Obsidian actually resolves against rather than a guess at its rules.
`check.js` covers what the app does not report - case-duplicate paths, malformed frontmatter, notes
with no frontmatter, unresolved embeds:

```sh
obsidian vault=brain unresolved
node ~/.claude/skills/obsidian-wiki/check.js brain
```

If the two disagree about a link, Obsidian is right and the checker needs fixing.

It exits nonzero when it finds a problem, so it also works as a gate. Two links in `brain` are
expected to fail and should be left alone:

- `Wiki/Japanese/石.md` links to `[[虫]]`, a stub marking the next kanji note to write.
- `Raw/2026-06-17.md` links to `[[Gamedev/Projects/Glyphs]]`, a dead SilverBullet path inside a
  dated entry. A daily note is a record of what was written that day; do not rewrite it to make a
  checker happy.

Then commit in `~/notes`, following the repo's commit style:

```sh
cd ~/notes && git add -A && git commit -m "nature: extract the pistol shrimp facts from the capture"
```

## The vault is live

Both vaults sync through LiveSync, and the user edits them in Obsidian while you work. Files can
appear, move or vanish mid-session, and `.trash/` collects what Obsidian deletes.

**Create and delete notes with the `obsidian` CLI, never by writing to disk.** Obsidian does not
watch the vault for new files - its inotify watches sit on config and cache paths only, not on the
vault root and not on any topic folder (checked against `/proc/<pid>/fdinfo`, with the watch limit
nowhere near exhausted). It indexes by scanning at startup and by observing changes made through
the app. A file that appears on disk from outside produces no event, and nothing prompts a rescan:
`touch` does not help, and neither does waiting. Such a note can be committed, pass `check.js`, and
still not exist as far as Obsidian or LiveSync are concerned - it never reaches the phone or the Pi
mirror, and clicking its link creates an empty stub instead of opening it. This has happened.

The CLI goes through the app, so the index and the sync both see the change:

```sh
obsidian vault=brain create path="Wiki/Linux/Zen settings.md" content="..." silent
obsidian vault=brain delete path="Wiki/Linux/old note.md"
obsidian vault=brain move path="Wiki/Art/note.md" to="Wiki/Code/note.md"
```

Measured: a note created this way is on disk at once, `obsidian file path=...` finds it
immediately, and it reaches the Pi mirror within seconds. Deleting the same way removes it locally
and on the mirror, leaving a copy in `.trash`. `name=` rejects a path - use `path=` for anything
inside a folder, and `silent` to stop the note opening in the app.

The `obsidian-cli` skill covers the rest of the command surface. Editing an already-indexed file on
disk is still fine; it is creation and deletion that change the shape of the index.

So a run is not finished when `check.js` passes. Diff the vault against the mirror before saying it
is done:

```sh
cd ~/notes/obsidian/brain && find . -name '*.md' -not -path './.obsidian/*' | sed 's|^\./||' | sort > /tmp/local.txt
ssh raspberrypi 'cd ~/livesync-bridge/data/brain && find . -name "*.md" | sed "s|^\./||" | sort' > /tmp/mirror.txt
diff /tmp/local.txt /tmp/mirror.txt
```

If they differ, say so and ask the user to **restart** Obsidian - a restart is what triggers the
scan; reopening a pane or touching the file does nothing. Warn them which way each difference
points: a file the mirror has and the vault does not can come back on that rescan rather than being
deleted.

A 0-byte note whose name matches a wikilink is Obsidian creating an empty file because the link did
not resolve - someone clicked a red link. It is evidence the target is missing from the index, not a
note to keep. A filename ending in ` 2` - `index 2.md`, `Zen settings 2.md` - is either a LiveSync
conflict copy or a second such stub, and is never a real note. Neither is worth keeping, but check
the byte count before deleting either.

Two things follow. Re-survey rather than trusting a listing from earlier in the session, and never
plan a folder move without saying it out loud first: case-only duplicates are a known LiveSync
failure mode once a case-insensitive platform (Android, iOS, Windows) is in the mix, reported as
duplicated folders and as bulk lowercasing of names. `check.js` fails on any case-duplicate path, so
a regression is caught before it spreads.

## Guardrails

- **Never delete or rewrite raw content.** Rephrasing belongs in the wiki note; the capture is the
  record of what was actually said. A junk capture gets flagged for the user, not removed.
- **Never touch `.obsidian/`.** Vault config, plugins and workspace state are not yours.
- Do not restructure existing folders as part of processing a note. Moving notes is its own task with
  its own confirmation.
- Do not invent facts to round out a note. A capture that raises a question the user never answered
  becomes an open question in the note, not a plausible-sounding answer.
- A capture is often addressed to you rather than to the vault - "давай обсудим", "сделай из этого
  промпт". That is an instruction, not content: act on it or raise it, but do not file it as a note.
