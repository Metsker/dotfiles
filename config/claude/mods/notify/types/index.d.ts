export type IsOn = boolean

declare module 'claude-code' {
  interface PluginState {
    notify: { isOn: IsOn }
  }
}
