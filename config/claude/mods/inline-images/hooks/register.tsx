import type { EngineInterface, Register } from 'claude-code'

// A line holding nothing but a markdown image of an absolute image path.
const LINE =
  /^[ \t]*!\[([^\]\n]*)\]\((\/[^)\s]+\.(?:png|jpe?g|webp|gif|bmp|tiff?|avif|heic|svg|ico))\)[ \t]*$/gim
const IS_PNG = /\.png$/i
// Kitty graphics take PNG or raw pixels only, so anything else goes through ImageMagick.
const MAGICK = 'magick'
const MAX_PIXELS = '1920x1920>'
const MAX_ROWS = 24
const MAX_COLUMNS = 120
// Image takes at most 2 MiB of bytes; a bigger PNG is handed over by path.
const MAX_INLINE = 2 * 1024 * 1024

const PROMPT = {
  id: 'inline-images:howto',
  scope: 'session',
  text: [
    '# Showing images',
    'This terminal draws images inline in your replies. To show the user a picture',
    '(a screenshot, chart, diagram or photo), put `![short alt text](/absolute/path.png)` on a',
    'line of its own in your reply. Absolute paths only; PNG, JPEG, WebP, GIF, BMP, TIFF, AVIF,',
    'HEIC, SVG and ICO are drawn, the non-PNG ones converted on the fly, so do not convert them',
    'yourself. Prefer this over describing what an image looks like.',
  ].join('\n'),
} as const

type Picture =
  | { width: number; height: number; source: { png: string } | { file: string; format: 'png' } }
  | { error: string }

const pictures = new Map<string, Promise<Picture>>()

function pngSize(base64: string) {
  const head = atob(base64.slice(0, 32))
  if (!head.startsWith('\x89PNG\r\n\x1a\n')) return undefined
  const u32 = (i: number) =>
    ((head.charCodeAt(i) << 24) |
      (head.charCodeAt(i + 1) << 16) |
      (head.charCodeAt(i + 2) << 8) |
      head.charCodeAt(i + 3)) >>>
    0

  return { width: u32(16), height: u32(20) }
}

async function load($: EngineInterface, path: string): Promise<Picture> {
  try {
    const { base64 } = await $.fs.read(path, { as: 'bytes' })
    const size = pngSize(base64)
    if (size === undefined || size.width === 0 || size.height === 0) return { error: 'not a PNG' }
    const isSmall = (base64.length * 3) / 4 <= MAX_INLINE

    return { ...size, source: isSmall ? { png: base64 } : { file: path, format: 'png' } }
  } catch (err) {
    return { error: err instanceof Error ? err.message : String(err) }
  }
}

// Keyed by mtime too, so a screenshot retaken under the same path draws anew.
async function picture($: EngineInterface, path: string): Promise<Picture> {
  let key: string
  try {
    key = `${path}@${(await $.fs.stat(path)).mtimeMs}`
  } catch {
    return { error: 'not found' }
  }
  if (!pictures.has(key)) pictures.set(key, IS_PNG.test(path) ? load($, path) : convert($, path, key))

  return pictures.get(key)!
}

async function convert($: EngineInterface, path: string, key: string): Promise<Picture> {
  try {
    const dir = (await $.env.get('XDG_RUNTIME_DIR')) ?? '/tmp'
    const out = `${dir}/inline-images-${await digest(key)}.png`
    if (!(await $.fs.exists(out))) {
      // [0] keeps the first frame of an animation or the first page of a TIFF.
      const argv = [MAGICK, `${path}[0]`, '-auto-orient', '-resize', MAX_PIXELS, out]
      const run = await $.process.run(argv).catch((err: unknown) => {
        const why = err instanceof Error ? err.message : String(err)
        throw new Error(`could not run ${MAGICK}, is ImageMagick 7 on PATH? (${why})`)
      })
      if (run.exitCode !== 0) {
        return { error: run.stderr.trim().split('\n')[0]?.slice(0, 160) || `magick exited ${run.exitCode}` }
      }
    }

    return load($, out)
  } catch (err) {
    return { error: err instanceof Error ? err.message : String(err) }
  }
}

async function digest(text: string) {
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)))

  return [...bytes.slice(0, 8)].map(b => b.toString(16).padStart(2, '0')).join('')
}

function fit(pic: { width: number; height: number }, room: number, aspect: number) {
  let columns = Math.min(room, MAX_COLUMNS)
  let rows = Math.round((columns * pic.height) / pic.width / aspect)
  if (rows > MAX_ROWS) {
    rows = MAX_ROWS
    columns = Math.round((rows * aspect * pic.width) / pic.height)
  }
  const clamp = (n: number) => Math.min(255, Math.max(1, n))

  return { columns: clamp(columns), rows: clamp(rows) }
}

export const register: Register = (on, options) => {
  // The mod API exposes no cell size, so the cell's shape is the user's to say.
  const aspect = typeof options.cellAspect === 'number' && options.cellAspect > 0 ? options.cellAspect : 2

  on('prompt.compose', async ($, e, next) => {
    if (!e.surfaces.includes('terminal')) return next(e)
    const { sections } = await next(e)

    return { sections: [...sections, PROMPT] }
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal') return next(e)
    const refs = [...e.props.text.matchAll(LINE)]
    if (refs.length === 0) return next(e)

    const { Box, Text, Image } = $.ui.resolve(e)
    const room = Math.max(10, (e.viewport?.columns ?? 80) - 4)
    const text = e.props.text.replace(LINE, '').replace(/\n{3,}/g, '\n\n').trim()
    const body = text === '' ? undefined : await next({ ...e, props: { ...e.props, text } })

    const images = await Promise.all(
      refs.map(async ([, alt = '', path = ''], i) => {
        const pic = await picture($, path)
        if ('error' in pic) {
          return (
            <Text key={`err-${i}`} dimColor>
              [image {path}: {pic.error}]
            </Text>
          )
        }

        return (
          <Image
            key={`img-${i}`}
            source={pic.source}
            {...fit(pic, room, aspect)}
            alt={`[image: ${alt || path}]`}
          />
        )
      }),
    )

    return (
      <Box flexDirection="column" gap={1}>
        {body}
        {images}
      </Box>
    )
  })
}
