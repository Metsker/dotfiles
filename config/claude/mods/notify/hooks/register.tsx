import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

const isOn = atom({ plugin: 'notify', key: 'isOn' } as const, false)

// The file claude-notify (scripts/claude-notify.sh) looks for before it sends anything.
async function flagPath($: EngineInterface, sessionId: string) {
  const runtime = (await $.env.get('XDG_RUNTIME_DIR')) ?? '/tmp'
  return `${runtime}/claude-notify/${sessionId}`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'notify',
      description: 'Toggle Telegram notifications for this session',
      immediate: true,
    })
    const flag = await flagPath($, await $.session.id())
    const hasFlag = await $.fs.exists(flag)
    await update($, isOn, () => hasFlag)

    return next(e)
  })

  on('command.run', { command: 'notify' }, async $ => {
    const flag = await flagPath($, await $.session.id())
    if (await $.fs.exists(flag)) {
      await $.process.run(['rm', '-f', flag])
      await update($, isOn, () => false)

      return { text: 'Telegram notifications off.' }
    }
    await $.fs.write(flag, '')
    await update($, isOn, () => true)

    return { text: 'Telegram notifications on - idle and permission prompts go to Telegram.' }
  })

  // A /clear ends the session under a new id, so the flag goes with the old one.
  on('session.end', async ($, e, next) => {
    await $.process.run(['rm', '-f', await flagPath($, e.sessionId)])
    await update($, isOn, () => false)

    return next(e)
  })

  // The footer's mode labels are dim text only, so a green one means drawing the line ourselves.
  on('ui.render', { component: 'SessionMode' }, async ($, e, next) => {
    if (!(await read($, isOn))) return next(e)

    const { Text } = $.ui.resolve(e)
    const label = <Text color="success">Telegram</Text>
    const { modes } = e.props
    if (modes.length === 0) return label

    return (
      <Text>
        <Text dimColor>{`${modes.join(' & ')} & `}</Text>
        {label}
      </Text>
    )
  })
}
