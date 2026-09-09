# Writing a scenario: full reference

The [README](../README.md) has a short version of this. This is the complete one — every
metadata field, every `demo` method, and the rules a scenario has to follow — for whoever
wants the depth: a human writing one by hand, or an agent with no other context than this file
and [`schema/scenario.schema.json`](../schema/scenario.schema.json).

Starting from an existing Playwright trace instead of a blank file?
`plaintake import <trace.zip> --output <draft.demo.ts>` drafts one — placeholder subtitles,
timings not imported, secret-looking values redacted — and the draft is finished by hand,
which is what this document is for.

A scenario is one file, one default export. `@plaintake/scenario` is only needed for editor
autocomplete while writing one — `npm install --save-dev @plaintake/scenario` in your project and your
copy takes precedence; without it, the installed binary's own fallback copy is what runs:

```ts
import { defineDemo } from '@plaintake/scenario';

export default defineDemo({
  schema: 'agent-demo.scenario/v1',
  id: 'create-api-key',
  title: 'Create an API key',
  viewport: { width: 1920, height: 1080, deviceScaleFactor: 1 },
  locale: 'en-US',
  timezoneId: 'UTC',
  colorScheme: 'light',
  reducedMotion: 'reduce',

  async run({ page, demo, baseURL }) {
    await demo.mask({ id: 'secret', selector: '[data-testid="api-key-value"]' });
    await demo.chapter('Organization settings');
    await demo.step({
      id: 'open-settings',
      title: 'Open organization settings',
      subtitle: 'Open the organization settings.',
      holdMs: 1500,
      run: () => page.goto(`${baseURL}/settings`, { waitUntil: 'load' }),
    });
    await demo.assert({
      id: 'settings-visible',
      title: 'Settings heading is visible',
      run: () => page.getByRole('heading', { name: 'Organization settings' }).waitFor(),
    });
  },
});
```

## Metadata

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema` | `'agent-demo.scenario/v1'` | yes | The only value accepted today. |
| `id` | lowercase kebab-case string | yes | Authored and stable. Never generate it — it names the scenario across every run. |
| `title` | non-empty string | yes | Shown in `validate`/`inspect` output. |
| `language` | string, min length 2 | no, defaults to `'en'` | The narration/caption language tag. |
| `viewport` | `{width:1920,height:1080,deviceScaleFactor:1}` | yes | The only supported viewport; every field is a literal. |
| `locale` | `'en-US'` | yes | The only supported locale. |
| `timezoneId` | `'UTC'` | yes | The only supported timezone. |
| `colorScheme` | `'light'` | yes | The only supported scheme. |
| `reducedMotion` | `'reduce'` | yes | The only supported value — recordings must not depend on CSS motion. |
| `allowedConsoleErrors` | string array | no, defaults to `[]` | Exact console error strings this scenario tolerates. Anything else fails the run. |
| `handoff` | `'none' \| 'preflight' \| 'session'` | no, defaults to `'none'` | See [Handing the browser to a person](#handing-the-browser-to-a-person). |
| `handoffTimeoutMs` | integer, 5000–300000 | no, defaults to `120000` | How long a handoff waits for a person before giving up. 300000 (5 minutes) is a hard ceiling — past that a wait is indistinguishable from a hang. |
| `intro` | object | no | See [The opening card](#the-opening-card). |
| `camera` | object | no | See [Framing](#framing). |
| `speech` | object | no | Scenario-level narration speed. See [Narration speed](#narration-speed). |
| `pronunciations` | `Record<string, string>` | no | Text substituted into narration before synthesis, so a caption can read one thing while the voice says another. See [Pronunciation hints](#pronunciation-hints). |

The machine-readable version of this table is
[`schema/scenario.schema.json`](../schema/scenario.schema.json).

## The `demo` DSL

Everything below is a method on the `demo` object `run()` receives, alongside `page` (a
Playwright `Page`) and `baseURL` (the string passed to `--base-url`/`fixture`).

| Method | Signature | Purpose |
|---|---|---|
| `chapter` | `(title: string) => Promise<void>` | Marks a chapter boundary on the timeline. Holds an establishing beat before the next step starts. The MP4 chapter markers derived from the events are free on every tier. |
| `step` | `({id, title, subtitle?, target?, action?, highlight?, holdMs?, run}) => Promise<void>` | The unit of narrated action. `run` performs it; `target` (a `Locator`) is recorded for the cursor/camera/highlight to read, never used to act; `action` (`'click' \| 'type' \| 'point'`) tells the cursor what to draw; `highlight` (`boolean \| { label? }`) dims everything but `target` — see [Highlighting](#highlighting). |
| `assert` | `({id, title, run}) => Promise<void>` | A checked expectation. A rejection fails the run; it does not stop the recording. |
| `mask` | `({id, selector, reason?}) => Promise<void>` | Hides a CSS selector's contents in every frame it could appear in, from the moment it is registered — register it *before* the element exists so nothing is ever visible. A selector, not a `Locator`, is what makes that possible. |
| `waitFor` | `({id, title, until, timeoutMs?}) => Promise<void>` | Waits on a condition that prompts nobody — a push notification, an emailed link, a background job. Needs no window and no terminal; works headless and in CI. |
| `handoff` | `({id, title, detail?, until?, timeoutMs?, mask?}) => Promise<void>` | Hands the real browser window to a person. Requires `handoff` in the scenario's metadata; only available in `run()` when `handoff: 'session'`, and in `preflight()` always. See below. |
| `pause` | `(ms: number) => Promise<void>` | An explicit, recorded pause. Prefer this over `page.waitForTimeout`: it races the run's abort signal and appears on the timeline. |
| `explain` | `({id, title, narration, scene, cues?, voice?}) => Promise<void>` | A full-frame, narrated motion-graphics cut-away in the middle of the recording. See [Explaining while demoing](#explaining-while-demoing). |

Pass `{ timeout: 0 }` to whatever Playwright call sits inside a `waitFor`'s or `handoff`'s
`until`, so the DSL's own `timeoutMs` is the only deadline — otherwise Playwright's own 30s
default fires first and blames the locator instead.

Two more hooks can sit beside `run()` in the same `defineDemo()` call:

- **`preflight({ page, demo, baseURL })`** — runs before recording and tracing start, and
  hands the page back on `about:blank`. Only `waitFor` and `handoff` are available on its
  `demo` — there is no video timeline yet, so `chapter`/`step`/`assert`/`mask` would have
  nothing to write to. This is where a sign-in belongs: nothing it does reaches the video or
  the trace.
- **`warmup({ page, demo, baseURL })`** — runs after `preflight`'s hand-back and before
  recording begins. Same restricted `demo` as `preflight`, for the same reason. Use it to
  navigate to the page the video should open on, when starting cold would film a blank load.

## Rules that matter in practice

- **`id` values are authored and stable.** Never generate them.
- **Set `holdMs`.** Narration is timed at roughly 20 characters/second with a 1200ms minimum,
  so a step that finishes in 40ms still needs its caption on screen for over a second. Without
  holds the video becomes a frozen frame with captions scrolling over it.
- **Masks take a CSS selector, not a `Locator`**, so they can be registered before the element
  exists — that is what makes "masked before the secret is ever visible" true.
- **No `Date.now()`, no `Math.random()`, no external network.** A scenario must be
  deterministic: the same scenario run twice should produce the same ordered steps, captions
  and assertions.
- **Erasable TypeScript only** — no `enum`, `namespace`, parameter properties, or decorators.
  Node's type-stripping loader cannot erase them, and `validate` rejects them by name before a
  browser opens.

## The opening card

```ts
intro: {
  lines: ['CSV to PDF mail merge', 'no sign-up'],
  narration: 'This is a free C S V to PDF mail merge, and it needs no sign-up.',
  durationMs: 3000,
},
```

- **`lines`** — one or two lines, centred on a flat background. Available on every tier.
- **`narration`** — optional, read aloud by the same voice as a step's `subtitle` when the run
  has `--speech` on.
- **`durationMs`** — optional, and a floor rather than a duration: if the spoken line needs
  longer, the card lengthens to fit rather than cutting it off. Defaults to 3s, capped at 15s.

## Framing

```ts
camera: { maxZoom: 1.35, minDwellMs: 1000 },
```

Every field is optional; the defaults are what the camera has always used, so a scenario that
says nothing is framed exactly as before this existed.

- **`maxZoom`** (1–1.6, default 1.6) — the zoom ceiling. At 1.6x, 37% of the frame is
  discarded, which crops a busy layout at the edge; 1.3–1.4x keeps more context.
- **`margin`** (0–2, default 0.3) — breathing room kept around each target, as a fraction of
  the target per side. The gentler alternative to lowering `maxZoom`.
- **`easeMs`** (133–2000, default 800) — how long a camera move takes.
- **`minDwellMs`** (0–5000, default 0) — settled time guaranteed on screen for a targeted step,
  on top of the ease.

## Highlighting

```ts
await demo.step({
  id: 'open-settings',
  title: 'Open settings',
  target: page.getByRole('button', { name: 'Settings' }),
  action: 'click',
  highlight: { label: 'Click Settings' },
  run: () => page.getByRole('button', { name: 'Settings' }).click(),
});
```

Dims everything on screen except `target`'s rect, with an optional callout label beside it.
Free on every tier — unlike the camera, there is no licence gate and nothing to turn on at
the CLI or in `demo_run`; a step's own `highlight` field is the only switch.

- `highlight: true` — spotlights `target` with no label.
- `highlight: { label: 'text' }` — spotlights `target` and draws `text` beside it.
- Absent (the default) — no highlight, exactly what every scenario written before this field
  existed already renders.

`highlight` needs a measurable `target`: if the step's bounding-box measurement fails —
best-effort, and rare — the run still completes, but the highlight is reported as a
diagnostic rather than silently skipped, so the gap is visible in `demo_run`'s diagnostics
rather than only in the missing pixels.

## Explaining while demoing

```ts
await demo.explain({
  id: 'key-scope',
  title: 'Where the key lives',
  narration:
    'Every key you create here is scoped to this settings tier, and it never leaves ' +
    'your browser session.',
  scene: {
    type: 'process',
    nodes: [
      { id: 'browser', label: 'Your browser' },
      { id: 'settings', label: 'Settings tier' },
    ],
    connections: [{ id: 'scope', from: 'browser', to: 'settings' }],
  },
  cues: [{ atPhrase: 'settings tier', action: 'reveal', target: 'settings' }],
});
```

`demo.explain()` cuts away from the recording to a full-frame, narrated motion-graphics
scene — compiled and rendered by the sibling [PlainMotion](https://plainmotion.dev) CLI,
which must be on `PATH` at record time (`plaintake doctor` reports whether it is). The
cut-away is a boundary on the timeline, the same mechanism a multi-actor `demo.turn()`
uses to hand the browser between two windows: the screencast pauses, the scene plays, and
recording resumes on the same page with nothing excised. Free on every tier, like every
authoring verb — the only licence interaction is PlainMotion's own, and it is invisible to
an author: a free-tier PlainMotion compile would otherwise freeze its own closing credit
card into the middle of the video, so PlainTake refuses that combination with the
activation command named, rather than shipping a scene with someone else's credits in it.

- **`id`** — becomes the directory the frozen scene lives in (`explain/<id>/`) and the
  generated scene's own id, so it follows PlainMotion's own rule: lower-case alphanumeric
  and hyphens, starting alphanumeric.
- **`title`** — a human label shown in `inspect` and diagnostics. Never drawn in the video.
- **`narration`** — what the scene says, and the only source of both the audio and the
  caption: there is no separate caption field, because two strings that are supposed to
  say the same thing eventually disagree. The narration is also the scene's clock — an
  explain scene always speaks, and lasts exactly as long as it takes to say this line.
- **`scene`** — which motion-graphics layout to draw, and its content:

  | `type` | Fields | Shows |
  |---|---|---|
  | `title` | `headline`, `subtitle?` | A title card. |
  | `process` | `nodes` (2–5, `{id,label}`), `connections?` (`{id,from,to,label?}`), `direction?` (`'horizontal' \| 'vertical'`), `title?`, `caption?` | A left-to-right (or top-to-bottom) flow. |
  | `comparison` | `left`/`right` (`{heading,points}`), `title?` | Two columns, side by side. |
  | `diagram` | `src` (an svg path, relative to the scenario file), `title?`, `caption?`, `regions?` | An author-supplied svg, imported as-drawn. |
  | `recap` | `items` (strings), `title?` | A closing bullet list. |

  Geometry is deliberately absent from every one of these — where a pixel lands is the
  scene layout's decision, exactly as it is in a `plainmotion.yaml`. An author says what
  exists and what the narration points at, never inches or coordinates.
- **`cues`** (optional) — `{atPhrase, action, target}`, timing an animation to a phrase in
  `narration` rather than to a numeric offset: rewording the line moves the cue with it
  instead of silently drifting out of sync. `action` is one of `reveal`, `hide`,
  `emphasize`, `deemphasize`, `draw`, `focus`; `target` names an id the scene itself
  declares (a node, a connection, or a comparison side). A phrase absent from the
  narration, or a target the scene never declared, is refused at record time.
- **`voice`** (optional) — speaks this scene with a different voice than the run's
  `--voice` default, under the same declaration rule as a step's own `voice`: it must be
  the default or an entry in `speech.voices`, or the run is refused with the fix named.
  Meaningful only when `--speech on` is doing the speaking.

## Narration speed

```ts
speech: { speed: 1.15 },
```

A multiplier applied to every synthesised line in the recording — the opening card's
`intro.narration` and every step's `subtitle` alike. Optional; absent means 1x, exactly what
every scenario recorded before this field existed already got. Only read when a run has
`--speech on`; a scenario recorded flat (or with `--speech file`, where there is no engine)
carries this harmlessly.

- **`speed`** (0.5–2.0, default 1) — 1.0 is unchanged speech; below 1 is slower, above 1 is
  faster. This range is not a measurement — PlainTake has not benchmarked how far Kokoro's
  output stays intelligible past either end — it is a conservative default picked because most
  TTS engines expose a multiplier over roughly this range. A scenario that genuinely needs more
  is a reason to revisit the bound with real data, not to work around it.

This is scenario-level only: there is no per-step override and no `--speed` CLI flag. Voice
*did* become per-step (see below) because a switched voice is a lookup into a set pre-loaded at
engine-open, already paid for by the declaration; speed has no such set, and one multiplier per
recording is the dial anyone has asked for. Pitch and SSML are likewise out of scope.

## Multiple voices

```ts
speech: { voices: ['am_michael', 'bf_emma'] },
```

The voices this scenario may switch between mid-run, beyond the default `--voice` picks. A
step takes one with `demo.step({ voice })`, an actor with `demo.actor('guide', { voice })`;
the step's name wins over the actor's, the actor's over the run default. A voice that is
neither the default nor in the list is refused at record time, with the one-line fix in the
message.

Declared up front so every voice's assets are checked — and the whole set pre-loaded — before
the browser opens, rather than a dead step mid-recording. Memory is why the list is yours to
keep short: each additional voice holds roughly +250 MB resident while the engine is open. A
scenario that declares voices but supplies a WAV for every step never opens the engine at all
and pays none of this.

Every voice in one recording must be the same language: the run's pronunciation dictionary is
configured once, and a mix is refused with both sides named. Today that language is English —
PlainTake ships only licence-clean pronunciation data, which exists for English alone, so the
model's 27 non-English voices are refused by name, each with its language and the reason.

## Pronunciation hints

```ts
pronunciations: { SQL: 'sequel', API: 'A P I' },
```

A text-substitution dictionary applied to a line's narration immediately before synthesis —
**never** to its caption. `SQL` keeps reading `SQL` in the subtitle track; the voice says
`sequel`. This is a different thing from the vendored en-us phoneme dictionary
`plaintake install-voice` fetches: that one is a fixed grapheme-to-phoneme table the engine
consults for every word it speaks; this one is authored per scenario and only ever substitutes
the whole words you list.

- Matching is **word-boundary, case-insensitive**: `SQL` matches `sql` and `SQL` but not the
  `SQL` inside `SQLite` — a naive substring replace would wrongly rewrite that too. The
  replacement is used exactly as written, not case-adjusted to match what it replaced.
- A dictionary key must be non-empty. A value may be empty, which mutes the matched word out of
  the spoken line entirely — a narrow, deliberate way to drop a filler word from the audio
  without also dropping it from the caption.
- Only applies where the model is actually doing the speaking. A step whose narration comes from
  an author-supplied WAV (`--speech file`, or a file dropped into `narration/` under `--speech
  on`) is already-recorded audio; there is no text left to substitute into, so this dictionary
  never touches it.

## Handing the browser to a person

A one-time code or a CAPTCHA cannot be scripted. Declare `handoff: 'preflight'` (or
`'session'`) in the metadata, then call `demo.handoff()` from the matching phase:

```ts
export default defineDemo({
  // ...metadata...
  handoff: 'preflight',
  handoffTimeoutMs: 120_000,

  async preflight({ page, demo, baseURL }) {
    await page.goto(`${baseURL}/login`);
    await demo.handoff({
      id: 'sign-in',
      title: 'Sign in, including any 2FA',
      detail: 'The browser window is yours. Come back here when the dashboard is up.',
      until: () => page.waitForURL('**/dashboard', { timeout: 0 }),
    });
  },

  async run({ page, demo, baseURL }) { /* already signed in */ },
});
```

`preflight` is the mode to reach for — it reaches neither the video nor the trace. `session`
puts the wait inside the recording, filmed exactly as it happened, which is right only for a
step-up challenge that is genuinely part of the demo. Either way, the only thing that comes
back from the prompt is *done*, *gave up*, or *never mind* — there is nowhere for a secret to
go. A `session` handoff also accepts a `mask` (a selector, applied the same way `demo.mask`
is) for a field the person fills in.

## Worked example

The scenario at the top of this file — masks, chapters, steps, an assertion — is a real one;
its recorded output (stills, captions, manifest) is in [`docs/samples/`](samples/README.md).
`plaintake validate <file>` checks any scenario, yours included, against everything on this
page with no browser.
