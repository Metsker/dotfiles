---
name: miniapp-multiplayer
description: Turn a seeded single-player browser game into a shared-channel Telegram mini app with live pari-mutuel odds and a chat bot. Use when adding multiplayer, Telegram, a mini app, or crowd-priced betting to a deterministic game.
---

# Seeded multiplayer for a Telegram mini app

A pattern for taking a browser game whose match is **deterministic from a seed**
and making it a channel everybody watches at once, priced by the crowd rather
than by the game, playable from a chat as well as from the app.

Do not start writing. Walk the decision tree below with the owner first, one
question at a time, each with a recommended answer. Look every *fact* up in the
repository - the decisions are the owner's, the facts are yours.

---

## The one insight everything hangs off

**If the match is a pure function of a seed, the server never streams the match.**

It sends `{seed, phase, startedAt}` and every client computes the rest. That single
property collapses four hard problems at once:

| the usual problem | why it disappears |
|---|---|
| keeping clients in sync | they all run the same seed |
| bandwidth for a live match | nothing about the match is sent |
| a socket dying on mobile | there is no socket to die |
| joining late | `advanceTo(now - startedAt)` in one gulp |

So the *first* thing to verify in any candidate game: can the simulation run
headless, without a canvas, from a seed? If a test suite already runs matches in
Node, the answer is yes and it is already proven.

**Verify it, do not assume it.** Import the sim in the target runtime and run one
match before designing anything on top of it.

---

## Step zero: does this game take input while it is being played?

Ask before anything else, because the answer decides whether the rest of this
skill applies at all.

**No input during play** - an autobattler, a race already run, a hand already
dealt. The seeded trick works and everything below follows.

**Continuous input** - anything a player steers. The trick does **not** transfer:
the server must be authoritative and tick continuously, and the client must
simulate too, or every input waits a full round trip. Sections 8 and 9 below are
replaced by ordinary authoritative-server netcode - tick rate, input buffering,
prediction and reconciliation - which is a much larger problem than this skill
covers.

What survives either way: sections 1-6 and 10-11, and the whole of the bot.

### Which forces the language question, and answers it

When the client predicts, **the simulation runs in two places**. That, not
throughput, is what picks the backend language:

- **The client's language (usually TypeScript)**: the two places are the same
  file. They cannot disagree.
- **A second language with the model rewritten in it**: two implementations of one
  simulation that must agree tick for tick, forever. This is the worst outcome and
  it is the one people pick for performance reasons that turn out not to exist.
- **One language compiled twice** (Rust to WASM and native, say): principled, one
  implementation, two targets - and a full rewrite plus a boundary the renderer
  crosses every frame.

**Measure before choosing, and measure the simulation alone.** Most games already
have the counter: sample the tick's own cost *after* the update and *before* the
render, and read it at the busiest content the game can produce. Then benchmark
the target host against the dev machine with a plain float loop rather than
assuming it is slower.

A worked example: a browser dungeon crawler with 300 bodies on screen measured
**1-5 ms a tick**, and the Raspberry Pi 5 it would deploy to benchmarked at
**0.83x** the dev desktop - so a tenth of one core per room at 20 Hz, dozens of
rooms across four. No performance argument for a rewrite survived that. The real
constraint turned out to be the network path to the host, which no language fixes.

**And check whether a headless model exists at all before any of this.** If the
simulation imports the renderer, no server in any language can run it, the
language question is premature, and the extraction is both the real work and the
same work whichever answer would have won. It is worth doing on its own merits: it
usually puts thousands of untested lines under test for the first time.

## The decision tree, in dependency order

Each node names the default and what it costs. Ask them **one at a time**.

### 1. Shape - one global channel, or lobbies?

**Default: one global channel.** Everybody who opens the app is on the same match
on the same second. No lobbies, no matchmaking, no waiting for friends.

It is also the only shape crowd-priced odds work in, because a pool needs a crowd.
Private rooms are this channel with an access key and a clock of its own, so
building the channel first does not close the door.

### 2. Odds - fixed, or the crowd's money?

**Default: pari-mutuel.** Both sides' stakes go in one pot; a side's price is what
the pot would pay it. It moves live because it *is* the crowd's money, and the game
still forecasts nothing - the price is the crowd's read, not an oracle's.

**Paid at close, never locked.** A pool cannot honour a price it no longer has the
money for. Locking a price is the bookmaker model, and there is no bankroll behind
it.

### 3. The thin-crowd problem - the one everybody misses

A hobby channel has three players, not three hundred. **A lone bettor in a pure
pari-mutuel gets their own stake back.** That is not a game.

**Default: virtual liquidity.** Price as though a phantom `V` were already in the
pool at the game's own fixed price `p`:

    price_i = (T + V) / (S_i + V / p)

- No real money: the price is exactly `p`, so the single-player board is preserved.
- Real money past `V`: the crowd owns the price.

The existing fixed-odds table survives as the anchor instead of being deleted, and
single-player and multiplayer become the same game at two crowd sizes.

### 4. Currency - and the framing that keeps getting this wrong

**Default: play money.** A bankroll keyed to the platform's user id, a faucet, and
the leaderboard as the whole prize.

Real currency (Stars, TON, on-chain) turns a coding question into a licensing one:
platforms and app stores treat funded wagering as gambling and take the bot down
rather than warning it.

**Say this out loud and early: with play money there is no house.** No balance
sheet, no solvency, no business. So:

- `V` is not the house's money. It is **how much currency the game will mint into
  a thin pool to keep the price sane.**
- A rake is not revenue. It is a burn, and a burn with nothing to feed is ceremony.

Inflation is then not an accounting problem. It bites in exactly one place - a
board that only grows ranks longevity rather than skill - and it is fixed **on the
board**, with rolling windows and rate-based metrics, not by taxing every bet.

### 5. Multiple currencies - one pool or several?

If the game has more than one purse, a pari-mutuel needs one pot.

**Default: an explicit conversion table, used only to size the pool.** Every stake
converts into a common unit so everybody faces the same multiplier, and the coin
that went down is the coin that comes back. Nothing is ever exchanged.

Solvency then holds in the common unit and not per coin - the ledger mints and
burns. With play money that is a sentence, not a problem.

If a rate table is written beside an existing table minimum table, **add a check
that holds the two in agreement.** Two tables and one truth is a drift bug waiting.

### 6. Backend - who knows who won?

**A client that reports its own winner reports that it won.** The server must run
the real simulation.

**Default: the same source file the browser runs, in a runtime that can run it.**
Never a reimplementation in another language, and never a copy - a second copy of a
simulation is the thing that silently drifts.

Runtime facts to check before choosing, on the actual deploy target:

- `apt install nodejs` on Debian 13 gives **Node 20** - no native type stripping,
  no `node:sqlite`. The easy path gives a runtime that cannot run TypeScript at
  all.
- Node 24 needs NodeSource or a tarball; **Bun is one static binary** and brings
  `Bun.serve`, `bun:sqlite` and native TypeScript, so the service has no
  dependencies at all.
- **If Bun is chosen, the shared simulation must stay strippable by plain Node**
  when the existing test suite runs it that way: no enums, no namespaces, no
  parameter properties, no decorators.

Stand the new service **beside** whatever already works rather than replacing it.
A feature that has not been written yet should not have the working thing in its
blast radius.

### 7. Transport - a per-game decision, with one reframe first

The owner will ask: *"a WebSocket dies when the app is minimized - what do we do?"*

**Reframe before choosing.** The match is never streamed, so a dropped connection
costs nothing: one GET rebuilds the world. That turns transport from a correctness
problem into a latency-and-ops preference. **Nothing here is banned** - pick per
game, on the numbers below.

| | latency | reconnect | server state | ops cost |
|---|---|---|---|---|
| polling | the poll interval | nothing to reconnect | none | none |
| SSE | instant push | native, `Last-Event-ID` | one open stream per player | `proxy_buffering off` |
| WebSocket | instant, bidirectional | you write it, or a library | one socket per player | upgrade block, keepalives |

What actually decides it:

- **How live is the live part?** If it is two integers moving for a twenty-second
  window, polling at 1s is indistinguishable from a push. If it is a chat, a
  cursor, a shared input or anything reactive, a socket earns its keep.
- **Does the client ever need to be *told* something unprompted?** Polling cannot
  do that. A socket or SSE can.
- **What is between the client and the server?** Behind a tunnel or a
  connection-pooling proxy, one held connection per player is a real cost. On an
  ordinary host it is nothing.
- **Is bidirectional traffic frequent?** Occasional writes are fine as POSTs. A
  stream of them wants a socket.

Whichever is chosen, two things hold:

- **Backgrounding must not be a failure mode.** Resync on `visibilitychange` and on
  the platform's activation event, and make one GET able to rebuild full state. A
  reconnect that does not resync is a client confidently showing the wrong world.
- **Shape the state payload so any of the three can carry it**, so the choice stays
  reversible.

*Worked example - why `bet` chose polling:* the only live data was a two-integer
pool for twenty seconds a round, the deployment sits behind a reverse SSH tunnel
whose own nginx config records that handshakes there "were most of the wait", and
nothing ever needed pushing unprompted. Polling at 1s while betting, 15s during the
match as a presence heartbeat, once at settle.

**Watch for this collision:** if any reward is paid to "everyone watching", a
client that goes silent during the match is a client the server cannot see. Either
keep a heartbeat or hold a connection. Catch it at design time.

### 8. The clock - what does a late arrival see?

**Default: always running, fast-forward join.** Betting window, match for its true
length, settle, next. The server knows the true length the moment it picks the seed
because it can run the whole match in milliseconds.

Opening the app mid-match calls `advanceTo(elapsed)` and joins in sync.

*Implementation note:* the renderer needs a **silent catch-up flag**, or a
forty-second fast-forward fires forty seconds of effects at once. Anything the
renderer already reconciles against the model's own lists each frame will snap
correctly by itself.

### 9. Fairness - the mistake that ends the game on day one

**Every client ships the entire simulator.** A seed on the wire while betting is
open is a devtools console away from winning every round forever.

**Default: two seeds and a salted commit.**

    betting   { dealSeed, commit = sha256(salt + ":" + matchSeed) }
              the client runs the deal itself, so no payload of match data
    bell      { matchSeed, salt }
              anyone can verify the commit

Most seeded games already pass the seed to two different places - the deal and the
match - and simply happen to pass the same number. Splitting them is usually a
one-line change.

**The salt is load-bearing, and here is the number.** A 32-bit seed is 4.29 billion
values. Measured at 1.39M sha256/sec on one core: an unsalted commit is brute-forced
in **51 minutes on a laptop, under a second on a GPU** - and the table is built once
and decodes every round forever. Sixteen random bytes make it unsearchable.

What a commit does not do: hide the outcome from the *server*. Keep the derivation
in one function so player-submitted nonces can be mixed in later.

### 10. Identity

**Default: the platform's signed init data, and nothing else.** For Telegram:
`secret = HMAC-SHA256("WebAppData", bot_token)`, HMAC the sorted `k=v\n` check
string, compare to `hash`, **and check `auth_date` for freshness** or the string is
a replayable bearer token forever. About fifteen lines on WebCrypto.

The bankroll lives server-side. The client never holds money, so there is nothing
to tamper with, and there is no cookie, session or token to steal.

**No guest accounts.** Pooled money makes a forgeable identity profitable: a free
unlimited identity is a farmable board and an infinite faucet.

**The bot token is never in the repo and never in the bundle.** It is an
`EnvironmentFile` at mode 600 on the host.

### 11. Code structure

**Default: a second entry point, not a mode flag.** The two orchestrators genuinely
differ - one paced by a player, one by a server clock - and that is the *only* part
that differs. Everything else is imported unchanged.

    index.html -> main.ts -> App          (single-player, untouched)
    live.html  -> live.ts -> Live         (new)
                       \  /
                  the shared model and renderer

Threading a server clock through a large single-player orchestrator gives every
later bug a file with two masters. A separate repository is worse: the simulation
must never drift, and a second copy is how it does.

---

## The bot: a client, not an advertisement

A chat bot for this pattern can be a **complete client**, because an inline-keyboard
tap carries the tapper's user id **signed by the platform**. A tap is an
authenticated bet - no init data, no mini app, no leaving the chat.

`/match` posts one card that edits itself for the rest of the round, then goes
quiet. One message per request, never per round: a round every two minutes is ~720
messages a day.

### Card design - the constraints that decide the layout

- **Emoji are double-width and monospace does not align them.** A card mixing
  emoji into a code block drifts on every client. A bar of one repeated character
  aligns fine in proportional text, so the card needs no code block at all.
- **Two layouts, one message**: rosters as emoji while betting, per-entity health
  bars once the match starts.
- **The match state costs no simulation.** The server precomputes a timeline once
  at the bell - one snapshot a second - and the card reads the row at
  `now - startedAt`. No polling loop, and the card cannot drift from the app.

### Button constraints, all of them real

- `web_app` buttons open inline **only in private chats**. In a group, use a `url`
  button to `t.me/<bot>?startapp=…`.
- `callback_data` is capped at **64 bytes** - encode `round:side:stake`, no more.
- **Edits are throttled.** Coalesce taps into one edit every 3-4 seconds.
- Anyone in a group may tap, which is correct - each tap is that person's own bet.
  Create the account on first tap, so people play having never opened the app.
- **Long polling (`getUpdates`) over a webhook** unless there is a reason: outbound
  only, nothing inbound to route, no secret path to hold.

### Boards

**Scopes and windows, never one cumulative total.** Global and per-chat; today,
this week, all time. Per-chat membership is best defined as **bets placed from that
chat's card** - no membership table, no join step, no permission the bot lacks.

Rank per currency, never summed: a conversion rate that sizes a pool is not an
exchange, and adding purses together invents a net worth the game does not have.

**Toast only when a board record falls.** Personal bests fire constantly and become
wallpaper. Rare is what makes it mean something.

---

## Traps, with the numbers

**Do not print derived stat totals on the floor.** The intuition is that a
matchmaker keeping sides close makes a visible "level" harmless. Measured over 3000
real matches in one such game: **backing the higher stat total won 69.2% of the
time** (65.7% at one a side, 72.1% at three). Against a fixed x2-x3 board that is
+31% to +116% a bet - an unbounded money printer.

A pari-mutuel survives it (the crowd prices the favourite correctly); virtual
liquidity does not, because `V` is anchored at the fixed price and gets farmed.

**So: measure it before shipping it.** Run a few thousand headless matches and
correlate whatever you were about to display against the winner. It is twenty
minutes of work and it is the difference between a hint and a strategy.

**No maximum stake is usually correct.** A pari-mutuel polices itself: an all-in
into a thin pool prices at ~x1.01 and returns nothing, so a big stake only pays
when it goes against a crowd. A cap solves a problem the arithmetic already solves.

**A faucet should be a floor, not a handout.** Top a balance *up to* a number
rather than adding to it: nobody is stranded, nobody is paid for idling, and
minting is bounded by how many players are broke rather than by how many accounts
exist.

---

## Checklist for a new game

- [ ] Established whether the game takes input during play - it decides everything
- [ ] A headless model exists at all (the simulation does not import the renderer)
- [ ] The simulation runs headless from a seed - **verified by running one**
- [ ] If the client will predict: the language choice measured, not assumed - tick
      cost sampled before the render, host benchmarked against the dev machine
- [ ] The deal seed and the match seed can be different numbers
- [ ] A runtime on the deploy target that can run the simulation - **version checked
      on the actual host**, not assumed
- [ ] The new service stands beside what already works
- [ ] Whatever you planned to display has been measured against the winner
- [ ] Salted commit, with the salt sized against a brute-force estimate
- [ ] `auth_date` freshness checked, token in an `EnvironmentFile`
- [ ] Presence defined, if anything pays "everyone watching"
- [ ] Renderer has a silent catch-up path for fast-forward joins
- [ ] Any second constants table is held against the first by a check
- [ ] Boards are windowed and per-currency, not one cumulative total
