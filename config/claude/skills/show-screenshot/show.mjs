#!/usr/bin/env node
/**
 * Show PNGs to the user, in a herdr pane beside the conversation.
 *
 * Two modes, one file. Without `--draw` it is the outer half: it works out how
 * wide the pictures want to be, opens (or reuses) a pane on the right at that
 * width, and runs itself in there with `--draw`. With `--draw` it is the inner
 * half, writing kitty graphics escapes to a real tty - which is the whole reason
 * for the split, since an agent's own Bash calls have no terminal to write to.
 *
 * The pane never takes more than half the tab, whatever the pictures ask for: the
 * conversation is the thing being read and a picture is what is being glanced at.
 * Pictures that will not fit across that half are laid out in shelves and wrapped
 * onto a second line, at whatever size lets the whole set stand in the pane.
 *
 * PNG only: `f=100` is the one format the protocol takes as a file. Convert
 * anything else first (`magick in.jpg out.png`).
 */
import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

/** A terminal cell is about twice as tall as it is wide. Override if yours is not. */
const CELL = Number(process.env.HERDR_CELL_ASPECT) || 2
/** The most of the tab the viewer may take. Half, and it is a ceiling not a target. */
const HALF = 0.5
const SELF = fileURLToPath(import.meta.url)

/** Width and height out of the PNG header - the two big-endian u32 at byte 16. */
function dims(file) {
  const buf = readFileSync(file)
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error(`${file}: not a PNG`)
  return { file, buf, w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) }
}

const herdr = (...args) => execFileSync('herdr', args, { encoding: 'utf8' })
const json = (...args) => JSON.parse(herdr(...args)).result

/** How many columns an image wants when it is drawn `tall` rows tall. */
const wide = (img, tall) => Math.max(4, Math.round((tall * CELL * img.w) / img.h))

/**
 * The biggest the set can be drawn and still stand inside `cols` x `rows`.
 *
 * Every picture in a shelf is the same height, so its width is its own aspect
 * ratio and nothing else. Heights are tried from the tallest down and the first
 * one whose shelves fit is taken - which is why wrapping is not a fallback but a
 * candidate: three tall shots wrap to two shelves only when two shelves let them
 * be drawn bigger than one squeezed row would.
 */
function plan(imgs, cols, rows) {
  let last = null
  for (let tall = rows; tall >= 2; tall--) {
    const shelves = []
    let shelf = []
    let used = 0
    for (const img of imgs) {
      const c = Math.min(cols, wide(img, tall))
      const add = shelf.length ? c + 1 : c
      if (shelf.length && used + add > cols) {
        shelves.push(shelf)
        shelf = []
        used = 0
      }
      shelf.push({ img, c })
      used += shelf.length > 1 ? c + 1 : c
    }
    if (shelf.length) shelves.push(shelf)
    last = { tall, shelves }
    // A gap row between shelves, and none after the last one.
    if (shelves.length * (tall + 1) - 1 <= rows) return last
  }
  return last
}

const drawing = process.argv[2] === '--draw'
const files = process.argv.slice(drawing ? 3 : 2)
if (!files.length) {
  console.error('usage: show.mjs <image.png>...')
  process.exit(2)
}
const imgs = files.map(dims)

if (drawing) {
  // Inside the viewer pane, on a real tty. Planned against the pane as it really
  // is rather than as the outer half asked for it - a pane can be resized by hand.
  const rows = Math.max(4, (process.stdout.rows || 24) - 2)
  const { tall, shelves } = plan(imgs, (process.stdout.columns || 80) - 1, rows)
  const out = []
  for (const shelf of shelves) {
    for (const { img, c } of shelf) {
      const b64 = img.buf.toString('base64')
      for (let i = 0; i < b64.length; i += 4096) {
        const part = b64.slice(i, i + 4096)
        const last = i + 4096 >= b64.length
        // C=1 keeps the cursor put, so the next picture can be stepped in beside it.
        const head = i === 0 ? `a=T,f=100,C=1,c=${c},r=${tall},` : ''
        out.push(`\x1b_G${head}m=${last ? 0 : 1};${part}\x1b\\`)
      }
      out.push(`\x1b[${c + 1}C`)
    }
    out.push(`\r\x1b[${tall + 1}B`)
  }
  process.stdout.write(`${out.join('')}\n`)
  process.exit(0)
}

const mine = process.env.HERDR_PANE_ID
if (!mine) {
  console.error('not inside herdr (no HERDR_PANE_ID) - send the files instead')
  process.exit(1)
}

const { layout } = json('pane', 'layout', '--pane', mine)
const rows = Math.max(4, layout.area.height - 2)
const cap = Math.floor(layout.area.width * HALF)
// What one shelf of them would like, and then the ceiling. Under it the pane is
// only as wide as the pictures; over it they wrap inside the half they are given.
const asked = imgs.reduce((n, i) => n + wide(i, rows), imgs.length - 1) + 1
const want = Math.max(20, Math.min(asked, cap))
// `--ratio` is the share kept by the pane being split, so the viewer gets the rest.
const ratio = Math.max(0.15, Math.min(0.85, 1 - want / layout.area.width))

// One viewer at a time: a second picture replaces the first rather than halving it.
for (const p of json('pane', 'list').panes) {
  if (p.tab_id === layout.tab_id && p.label === 'imgview') herdr('pane', 'close', p.pane_id)
}
const { pane } = json('pane', 'split', '--pane', mine, '--direction', 'right',
  '--ratio', String(ratio), '--no-focus')
herdr('pane', 'rename', pane.pane_id, 'imgview')
// The pane is a fresh shell; give it a moment to be ready for a line.
await new Promise((r) => setTimeout(r, 600))
herdr('pane', 'run', pane.pane_id, 'node', SELF, '--draw', ...files)
const shape = plan(imgs, want - 1, rows)
console.log(`${pane.pane_id} · ${want} of ${layout.area.width} columns · ` +
  `${files.length} image(s) in ${shape.shelves.length} row(s), ${shape.tall} tall`)
