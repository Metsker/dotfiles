---
name: svelte-pixi-game-proto
description: Scaffold and structure a fast-iteration 2D game prototype with Svelte 5 UI, PixiJS v8 rendering, a deterministic headless sim, and emoji placeholder sprites. Use when starting a new browser game prototype, wiring Pixi into Svelte, or when the user asks for a game idea test bed with hot reload. Triggers on: game prototype, svelte + pixi, autobattler, emoji sprites, headless sim, game scaffold.
---

# Svelte + Pixi game prototype

Battle-tested pattern (built for the gacha-tower prototype, `~/gamedev/pixi-js/gacha`).
Core idea: **game logic is a deterministic headless sim; Pixi only renders it;
Svelte owns every non-diegetic screen.** This keeps logic testable without a
browser, lets "instant resolve"/idle features reuse the same code, and makes
balance tunable via unit tests.

## Scaffold (bun)

```sh
bun x create-vite@latest tmp-app --template svelte-ts
cp -r tmp-app/. . && rm -rf tmp-app src/lib src/assets
bun install && bun add pixi.js && bun add -d @types/bun
```

- package.json scripts: add `"test": "bun test src"`.
- tsconfig.app.json: add `"bun"` to `types` so `bun:test` type-checks.
- Delete template cruft, replace App.svelte/app.css.
- Hot reload = Vite default. Nothing to configure.

## Layered layout

```
src/sim/     types.ts, engine.ts, content.ts, sim.test.ts  <- pure TS, ZERO pixi/svelte imports
src/state/   game.svelte.ts   <- Svelte 5 runes singleton: class with $state fields, export const game = new Game()
src/pixi/    battleScene.ts   <- async mount(host, ...): Promise<{ setSpeed, destroy }>
src/ui/      *.svelte views   <- menus, pickers, HUD; a screen switcher in App.svelte
```

Rules that make it work:
- Sim: fixed timestep (`DT = 0.1`), no `Math.random`, `step(state): Effect[]`
  returns renderable effects (hit/heal/death/spawn) each tick; `runBattle()`
  loops step headlessly for tests, farming math, instant resolve.
- Store: plain class in `.svelte.ts` with `$state` fields; explicit `save()`
  to localStorage in each action beats reactive persistence magic.
- Balance = tests: freeze the intended win/lose matrix ("boss X falls to
  counter comp, resists naive comp") in `bun:test`; tune content numbers
  until green. Tuning loop: scratch script printing result+duration per comp.
- Beware runaway-growth passives (stacking buffs): they beat any linear
  challenge eventually - cap them or bosses stop being puzzles.

## Pixi v8 in a Svelte component

```ts
const app = new Application();
await app.init({ width, height, background: '#14141f', antialias: true,
  resolution: window.devicePixelRatio, autoDensity: true });
host.appendChild(app.canvas);            // AFTER init; app.canvas not app.view
(window as any).app = app;               // for Playwright / devtools
app.ticker.add((tk) => {                 // callback gets Ticker, not delta
  acc += (tk.deltaMS / 1000) * speed;    // fixed-timestep accumulator
  while (acc >= DT && !sim.done) { acc -= DT; applyEffects(step(sim)); }
  lerpPuppetsAndBars();
});
// teardown (component unmount AND retry-remount):
app.destroy({ removeView: true, releaseGlobalResources: true },
  { children: true, texture: true, textureSource: true });
```

CRITICAL when several Applications coexist (e.g. a main battle plus a
picture-in-picture preview): `releaseGlobalResources: true` drains pools
shared by ALL pixi apps and silently breaks the survivors. Keep a
module-level live-scene counter and only pass `true` for the last one out.

Svelte side: `onMount(() => { start(); return () => handle?.destroy(); })`
where `start()` destroys any previous handle first - gives free "Retry".

## Emoji sprites

`new Text({ text: '🐻', style: { fontSize: 52, fontFamily: ['Noto Color Emoji',
'Apple Color Emoji', 'Segoe UI Emoji', 'sans-serif'] } })` renders full-color
emoji on canvas in real browsers. One emoji per unit + a 6px Graphics HP bar
(clear + 2 rects per frame) is a complete prototype art style. Juice on the
cheap: lunge = decaying x-offset toward foe on attack; hit = decaying scale
bump; damage numbers = short-lived floating Texts.

## Verification

Expose `window.game` (store) and `window.app` (Pixi). Drive the real app and
assert on state, not pixels. On NixOS the Playwright MCP's chrome channel is
absent; use `playwright-core` (dev dep) + nix chromium:
`nix-shell -p chromium --run 'which chromium'` then
`chromium.launch({ executablePath })` in a bun script. Beware substring text
selectors matching battle-log lines (e.g. `text=Victory` hits "victory in
4.2s" before the verdict overlay renders) - wait for overlay-only elements.
