---
name: show-screenshot
description: Show the finished work as a picture rather than describing it - capture a screenshot of the result and draw it in a herdr pane beside the conversation, over the kitty graphics protocol. Use whenever "show-screenshot" appears in a prompt, before or after the request, or arrives as a message of its own once the work is done; it is an instruction to end the turn with a screenshot. Also use when asked to show, display or look at an image, chart or diagram.
---

# Show Screenshot

`show-screenshot` in a prompt is not a question. It means: do the work as asked,
then **capture the result and show it**, and let the picture carry the report. It
is a whole sentence wherever it lands - appended to a request, in front of it, or
sent on its own after the work is finished, where it means "show me what you just
did".

Three steps, and the middle one is the one worth thinking about.

## 1. Do the work

Nothing about this changes the task. The screenshot is the last thing, not the
first, and a picture of a half-finished change is worse than no picture.

## 2. Capture the result

Shoot the thing that changed, in the state that shows the change - not the app's
front door. If a fix is about a button that folds onto two lines, the shot is that
button, and forcing the worst case beats waiting for it to turn up.

- **Look for the project's own recipe first.** A `run` skill, a probe script, a
  documented headless flow. A project that already knows how to stand itself up
  headlessly is faster and truer than anything improvised.
- **On this machine there is no browser on `PATH`.** The nix store has one:
  `nix build --no-link --print-out-paths nixpkgs#playwright-driver.browsers` holds
  `chromium-*/chrome-linux64/chrome`. Run it `--headless=new --no-sandbox
  --enable-unsafe-swiftshader --use-angle=swiftshader --remote-debugging-port=N`
  and drive it over CDP. `--screenshot` alone is not enough for anything that
  loads assets - it fires while the loading panel is still up.
- **Wait for the thing, not for a timeout.** Poll `document.body.innerText` or a
  selector for something only the finished state contains.
- Save PNGs to the session scratchpad, not into the project.

If the work has no visible surface, say so and skip the picture. A screenshot of
something unrelated is worse than a sentence.

## 3. Show it

```bash
node ~/.claude/skills/show-screenshot/show.mjs shot.png              # one
node ~/.claude/skills/show-screenshot/show.mjs before.png after.png  # side by side
```

That is the whole interface. It opens a pane on the right, sized to the pictures,
and draws them; a second call replaces what is in it rather than splitting again.
Still say in words what the picture shows - what was measured, what is fixed. The
shot is the evidence, not the whole answer.

## Why a pane and not stdout

An agent's Bash calls have no controlling terminal - `/dev/tty` opens with ENXIO -
and anything printed goes to the harness, which renders it as text. Kitty graphics
only work when the bytes reach a terminal, so the escapes have to be written by a
process the terminal owns. A herdr pane is exactly that: `herdr pane run` starts a
command on a real tty, and `show.mjs --draw` is what runs there.

The same reason is why `SendUserFile` is not an answer in a terminal - it draws a
file card, not pixels.

## What it needs

- `experimental.kitty_graphics = true` in `~/.config/herdr/config.toml`, and an
  outer terminal that speaks the protocol.
- `HERDR_PANE_ID` in the environment - it is how the script finds the pane to
  split. Outside herdr it says so and exits 1.
- **PNG only.** `f=100` is the one format the protocol takes whole. Convert first:
  `magick in.jpg out.png`.

## How it sizes the pane

`c` and `r` together tell the terminal to scale the image into exactly that box,
aspect ratio be damned, so the box has to be the right shape or the picture comes
out stretched. Every picture in a row is drawn the same height, which leaves its
width to its own aspect ratio and nothing else: `cols = rows * CELL * w/h`, where
`CELL` is how many times taller a cell is than it is wide.

`CELL` is measured, not guessed. The drawing half asks the terminal with `CSI 16 t`
and gets back `CSI 6 ; height ; width t` in pixels - 27 by 12 here, so 2.25, and a
hardcoded 2 would squeeze every picture by 11%. Only that half has a tty to ask on,
so what it measures is cached in `~/.cache/show-screenshot/cell-aspect` for the
outer half to size the pane by. `HERDR_CELL_ASPECT` overrides both, and 2 is the
fallback before anything has been measured.

**A picture is never made narrower to fit - it is made shorter.** The starting
height is whatever the pane is wide enough to hold at the picture's own ratio, so a
landscape shot in a tall thin pane comes out short and wide, not squeezed into the
full height.

**The pane never takes more than half the tab.** The conversation is the thing
being read; a picture is what is being glanced at. Under that ceiling the pane is
only as wide as the pictures actually want - one phone screenshot takes about 35 of
149 columns and leaves the rest alone.

Over it, they wrap. Heights are tried from the tallest down and the first one whose
rows fit the pane is taken, so wrapping is a candidate rather than a fallback: with
six phone shots in half of a 149-column tab, two rows of 16 beats one row of 11.
Three stay on one row at 22.

`herdr pane split --ratio` is the share kept by the pane being **split**, so the
viewer gets `1 - ratio`. Getting that backwards gives a 20-column picture and a
120-column shell.

The inner half plans again against the pane it really landed in, so resizing the
pane by hand and re-running redraws at the new size.

## Reading a picture the model cannot see

`herdr pane read` returns text, so a drawn image comes back as blank rows. That is
enough to know the escape went out and nothing else. To check what was actually
drawn - and check before claiming a change works - read the PNG with the Read tool.
The model sees the file even though the terminal is where the user sees it.

## The other two placements

`plugin.pane.open` can put a plugin-owned pane in a **popup** (session-modal,
floats over everything, never appears in `pane list`) or an **overlay** (a real
pane belonging to the active tab). Both are opened over the socket and need a
linked plugin with a `[[panes]]` entry declaring the placement; there is no
`popup.open` method, and the 0.8.0 CLI's `--placement` flag has no `popup` in it
even though the manifest and the API do.

Neither can be aimed anywhere: `--target-pane` is refused with *"overlay and popup
plugin panes target the active pane"*. Focus the tab you want it in first.

A split pane is the better default anyway - the picture stays up while the
conversation carries on beside it, where a popup has to be dismissed to type.

## When there is no terminal to draw on

Some clients are not a terminal at all. Fall back to `SendUserFile` with
`display: "render"`, **one image per call** rather than a composed strip, so each
one gets its own card at its own size.

## Cleanup

The viewer is an ordinary pane: `herdr pane close <id>`, and the id is printed when
it opens. It is named `imgview`, which is how the next call finds and replaces it.
