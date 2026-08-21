---
name: miniapp-probe
description: Drive a Telegram mini app locally with a signed identity, in a real browser, without Telegram or a phone. Use when testing, debugging or verifying a change to a mini app's identity, shared purse, or anything a signed launch string reaches - and when deciding whether a self-signed test is trustworthy at all.
---

# Driving a Telegram mini app without Telegram

A launch string is an **HMAC with the bot token and nothing else**. Anyone holding
the token can mint a valid one for any player. That is why the token is the
secret, and it is also the whole trick: a mini app can be driven exactly as
Telegram drives it, on this machine, with nobody keeping an app open.

Telegram hands the signed string to the page **in the URL fragment**. If the app
reads nothing else of Telegram's, a browser at the right fragment is not an
approximation of the webview - it is the same input.

## Before trusting any of this: does the app use the WebApp object?

Check first, because it decides how much the loop is worth:

```
grep -rn "telegram-web-app.js" */index.html
grep -rn "enter(\|insets(\|inTelegram(\|haptic(\|WebApp" */src/
```

- **No hits** - the app consumes only the launch string. The browser loop below is
  exact, and a passing test means the thing works.
- **Hits** - the app also uses viewport, insets, haptics or the share sheet. The
  loop still covers identity and behaviour, but chrome is untested and a human has
  to look at it on a device.

In `metsker.dev`'s folder the three games have no hits and the shelf does.

## The loop

```
cd bet
BASE_PATH=/bet/ npm run build              # the base must match the path served
bun server/probe.ts --gold 4321 --blue 40  # prints one URL per built game, waits
```

Then open a printed URL with the browser tooling and assert against the DOM.
Read the numbers out of the page rather than trusting a screenshot:

```
document.querySelector('.corner.purse header').innerText   // what it shows
!!document.querySelector('.shut')                          // signed-out door
localStorage.getItem('tiled:purse')                        // must be null when signed in
```

Ctrl-c when done. The probe runs its own ledger on its own token against a
temporary database, so it cannot reach production, spend a real purse, or be
mistaken for a real player.

## What this can and cannot tell you

**It can** verify identity handling, the bank round trip, a purse shared between
games, what the screen actually shows, and every behaviour a signed string
reaches. Seed through the bank (`--gold`) rather than into the database, so the
state under test is state a game could really have produced.

**It cannot tell you what Telegram really sends.** The string is shaped the way
the signer chooses. A signer and a verifier that share a reading can agree with
each other and both be wrong - which is exactly how a mini app can refuse every
real player for months while every test passes.

So the loop has to be anchored to an observation, not to a reading:

1. **Count what really arrives.** Record, per request, the launch string's sorted
   field *names* and whether it verified. Names only - never a value; the string
   is a bearer token for as long as it verifies.
2. **Pin a check to that set.** Assert both that the test's string carries the
   observed set *and* that the set verifies, so the case cannot quietly stop being
   the real case while still passing.
3. **Watch for drift.** Arrivals with no verifications is broken; no arrivals is
   nobody playing. Nothing else can tell those apart, and an empty table looks
   exactly like a quiet week.

In this folder that is `npm run launches`, `OBSERVED` in `initdata.check.ts`, and
the `launches` table in `live.ts`.

## Traps, each of which has cost real time

- **A fragment added to an already-open page does not reload it.** Going from
  `/bet/` to `/bet/#tgWebAppData=…` is a same-document navigation, the launch
  string is never re-read, and the app stays signed out. Always load the fragment
  on a fresh navigation, or add a query to force one.
- **Sign from the rule, not from the verifier.** Telegram hashes every field
  except `hash` - *including* `signature`, its Ed25519 field, which is excluded
  from that other check and belongs in this one. A signer that imports the
  verifier's code proves only that the code agrees with itself.
- **A bundle built for another base serves a blank page**, not a broken one,
  because its assets ask for paths nobody is serving. Check the built index
  references the base you are serving under.
- **Read the DOM, not the picture.** A screenshot taken after a same-document
  navigation shows the previous state, and looks entirely plausible.
- **Kill only what you started**, by PID. Never by name pattern - a developer's
  own editor and servers answer to the same names.

## When it fails

An identity that will not verify has three usual causes, in order of likelihood:
a field dropped from the check string, the wrong token, and a stale `auth_date`
outside the freshness window. Doing the check through the protocol rather than a
UI is worth it for one reason: **the error has a name.** A web client says
"invalid" and logs nothing.
