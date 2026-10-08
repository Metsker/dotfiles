import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// A 1x1 PNG.
const PNG =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='

const message = (text: string) =>
  ({ component: 'AssistantMessage', requestId: 'msg-1', props: { text, isFirstOfReply: true } }) as const

function disk(on: On) {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text key="engine">{e.props.text}</Text>
  })
  const runs: (readonly string[])[] = []
  const isConverted = (path: string) => path.startsWith('/run/test/inline-images-')
  on('env.get', async ($, e) => ({ value: e.name === 'HOME' ? '/home/test' : '/run/test' }))
  on('fs.stat', async ($, e) =>
    ['/shots/a.png', '/shots/b.jpg', '/shots/c.gif', '/shots/broken.webp'].includes(e.path)
      ? { value: { kind: 'file', size: 70, mtimeMs: 1, isLink: false } }
      : { deny: 'ENOENT' },
  )
  on('fs.exists', async () => ({ value: false }))
  on('fs.read', async ($, e) =>
    e.path === '/shots/a.png' || isConverted(e.path) ? { value: { base64: PNG } } : { deny: 'ENOENT' },
  )
  on('process.run', async ($, e) => {
    runs.push(e.argv)
    if (e.argv[1]?.startsWith('/shots/c.gif') === true) throw new Error('spawn magick ENOENT')
    const isBroken = e.argv[1]?.startsWith('/shots/broken.webp') === true
    return {
      value: {
        exitCode: isBroken ? 1 : 0,
        stdout: '',
        stderr: isBroken ? "magick: improper image header `/shots/broken.webp'\nmore" : '',
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }
  })

  return runs
}

test('a JPEG is converted to a PNG and drawn', async ($, on) => {
  const runs = disk(on)
  const ui = await $.ui.mount({ plugin: 'inline-images', surface: 'terminal', ...message('![j](/shots/b.jpg)') })
  expect(await ui.find({ key: 'img-0' })).toBeDefined()
  expect(runs[0]?.[0]).toBe('magick')
  expect(runs[0]?.[1]).toBe('/shots/b.jpg[0]')
  expect(runs[0]?.at(-1)).toMatch(/^\/run\/test\/inline-images-[0-9a-f]{16}\.png$/)
  await ui.unmount()
})

test('the picture is sized by the cellAspect option', async ($, on) => {
  disk(on)
  const size = async () => {
    const ui = await $.ui.mount({ plugin: 'inline-images', surface: 'terminal', ...message('![a](/shots/a.png)') })
    const { columns, rows } = (await ui.find({ key: 'img-0' }))?.props ?? {}
    await ui.unmount()
    return { columns, rows }
  }
  // A square picture in 76 free columns: 38 rows at the default 2 is over the cap of 24.
  expect(await size()).toEqual({ columns: 48, rows: 24 })
})

test('a taller cell gives a square picture fewer rows', { options: { cellAspect: 4 } }, async ($, on) => {
  disk(on)
  const ui = await $.ui.mount({ plugin: 'inline-images', surface: 'terminal', ...message('![a](/shots/a.png)') })
  const { columns, rows } = (await ui.find({ key: 'img-0' }))?.props ?? {}
  expect({ columns, rows }).toEqual({ columns: 76, rows: 19 })
  await ui.unmount()
})

test('a missing magick says to install ImageMagick', async ($, on) => {
  disk(on)
  const ui = await $.ui.mount({ plugin: 'inline-images', surface: 'terminal', ...message('![g](/shots/c.gif)') })
  expect(await ui.find({ key: 'img-0' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /is ImageMagick 7 on PATH/ })).toBeDefined()
  await ui.unmount()
})

test('a failed conversion shows the first line of its error', async ($, on) => {
  disk(on)
  const ui = await $.ui.mount({ plugin: 'inline-images', surface: 'terminal', ...message('![w](/shots/broken.webp)') })
  expect(await ui.find({ key: 'img-0' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /improper image header/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /more/ })).toBeUndefined()
  await ui.unmount()
})

test('an image line draws an Image', async ($, on) => {
  disk(on)
  const ui = await $.ui.mount({
    plugin: 'inline-images',
    surface: 'terminal',
    ...message('Here it is:\n\n![the page](/shots/a.png)\n'),
  })
  expect(await ui.find({ key: 'img-0' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^Here it is:$/ })).toBeDefined()
  await ui.unmount()
})

test('a missing file says so instead of drawing', async ($, on) => {
  disk(on)
  const ui = await $.ui.mount({
    plugin: 'inline-images',
    surface: 'terminal',
    ...message('![gone](/shots/missing.png)'),
  })
  expect(await ui.find({ key: 'img-0' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /not found/ })).toBeDefined()
  await ui.unmount()
})

test('a relative path or an inline image is left as text', async ($, on) => {
  disk(on)
  for (const text of ['![x](shots/a.png)', 'see ![x](/shots/a.png) here']) {
    const ui = await $.ui.mount({ plugin: 'inline-images', surface: 'terminal', ...message(text) })
    expect(await ui.find({ key: 'img-0' })).toBeUndefined()
    await ui.unmount()
  }
})
