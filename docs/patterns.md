# Patterns for recording a real app

[`scenarios.md`](scenarios.md) is a contract: everything on it is enforced by `validate`
before a browser opens. This page is deliberately the opposite — recipes for the
*application* side of a recording, which PlainTake cannot check because they live in your
app, your fixtures and your mail server. Nothing here is required. Everything here was
learned from real scenarios recording real products, where the alternative was a flaky
recording or a demo that only worked on the machine that wrote it.

## What belongs here, and what belongs in the scenario

The rule of thumb: if `validate` could check it, it belongs in the DSL or the scenario
schema. If it works only because your app behaves a certain way, it belongs here. Seeding a
database, polling a mail server, switching personas mid-recording — PlainTake sees none of
that; it sees a page that responds deterministically to scripted actions. These patterns are
how you make the page deserve that description.

## Waiting for email: poll, never single-shot

A demo that creates an account usually needs the email it sends. Point the app's SMTP at a
local sink — [Mailpit](https://mailpit.axllent.org/) is the usual choice — and read the
message out of its HTTP API from `waitFor`. **`waitFor` invokes `until` exactly once** — it
is never re-evaluated, and any resolution ends the wait successfully, including a `false`
return; only a rejection, or the `timeoutMs` deadline, fails it. So the polling has to be
`until`'s own job, not something `waitFor` does on its behalf — a single GET that returns
`false` when the message is not there yet does not get retried, it just *succeeds* early,
with nothing found:

```ts
let code: string | undefined;

await demo.waitFor({
  id: 'otp-arrives',
  title: 'The one-time code arrives',
  until: async () => {
    // The loop is load-bearing: `until` runs once, so this is the only retry the message
    // gets. `waitFor`'s own `timeoutMs` below is what eventually stops it, not a count or a
    // deadline in here — `{ timeout: 0 }` on each Playwright call keeps its own 30-second
    // default from firing first and blaming the wrong thing.
    for (;;) {
      const search = await page.request.get(
        'http://localhost:8025/api/v1/search?query=welcome%40demo.example',
        { timeout: 0 },
      );
      if (search.ok()) {
        const { messages } = (await search.json()) as { messages: Array<{ ID: string }> };
        const latest = messages.at(-1);
        if (latest !== undefined) {
          const message = await page.request.get(
            `http://localhost:8025/api/v1/message/${latest.ID}`,
            { timeout: 0 },
          );
          const { Text } = (await message.json()) as { Text: string };
          const match = /\b(\d{6})\b/.exec(Text);
          if (match !== null) {
            code = match[1];
            return;
          }
        }
      }
      await page.waitForTimeout(500);
    }
  },
  timeoutMs: 30_000,
});
```

The one thing not to do is fetch once and assert. A single GET races SMTP delivery — the
message is milliseconds away but not there yet, and the scenario fails a recording that would
have succeeded a heartbeat later. In a test suite that is a retry; in a recording it is a
whole re-record. Email is the case this shape was built for.

Two details that keep the poll deterministic: search for a recipient address your seed
created (the next section's fixed address, not `admin@example.com`, which every prior
test run has already mailed), and read the *last* match, so a stale message from an earlier
run cannot answer for this one. Clearing Mailpit between runs
(`DELETE /api/v1/messages`) is the belt-and-braces version of the same discipline.

## Seeding: idempotent SQL with fixed ids

A recording needs the app in a known state before the first frame. However you usually talk
to your database — a `psql` invocation in the script that wraps the recording, or an admin
endpoint hit from `preflight` — the seed must have three properties:

1. **Fixed identifiers, never generated.** `gen_random_uuid()` in a seed produces a different
   tenant on every run, and the demo that links to tenant `9f3c…` today links to nothing
   tomorrow. Hardcode the UUIDs in the seed and let the scenario quote them.
2. **Idempotent writes.** `INSERT … ON CONFLICT (id) DO NOTHING`, so re-running the seed
   after a failed recording corrects a half-seeded state instead of failing on the rows that
   did land.
3. **Reset, don't accumulate.** A `DELETE` of the seeded rows ahead of the `INSERT` (or a
   `TRUNCATE … CASCADE` on the demo tenant's tables) makes the tenth run look exactly like
   the first — no "test tenant (9)" appearing in a picker on camera.

The state you are aiming at is the one the determinism rule already promises: the same
scenario, run twice, produces the same ordered steps, captions and assertions. The scenario
cannot deliver that promise alone; the seed is the other half of it.

## Switching personas

Two people in one video — an admin configures, a user reacts — is what `demo.actor()` exists
for: a second browser context per actor, a filmed hand-off with a transition card, and no
shared cookie jar to manage. The worked version is `examples/multi-actor-registration.demo.ts`
in the source repository.

If the app supports only one signed-in session per browser, the fallback is clearing cookies
between personas:

```ts
await page.context().clearCookies();
await page.goto(`${baseURL}/login`);
```

Do this where the camera isn't. In `preflight` it reaches neither video nor trace; in `run`
it is filmed, login and all — which is right only when signing in *is* the demo. What never
works is switching personas inside a step: a step is one narrated action by one person, and
a cookie jar emptying mid-step is a recording that lies about who is acting.

## Showing a terminal

There are two ways, and which one fits depends on whether the terminal *is* the demo.

### A live terminal: declare `terminal:`

When the thing being shown is a CLI or a TUI, declare `terminal` in the scenario. PlainTake
starts the command in a real PTY, draws it with xterm.js in a local page, and films that
page like any other — so captions, narration, the cursor, the camera, highlights and
chapters all work unchanged. The scenario's `run` is handed a `term`:

```ts
export default defineDemo({
  // ...the usual schema, id, viewport, locale, timezoneId, colorScheme, reducedMotion
  terminal: {
    command: ['./bin/mycli', 'menu'],   // argv, never a shell string; omit for an interactive bash
    cwd: '.',                           // relative to the scenario file
    env: ['API_TOKEN'],                 // copied from your environment; nothing else is
    secrets: ['API_TOKEN'],             // values masked as bullets; must also be in env
  },
  async run({ demo, term }) {
    if (term === undefined) throw new Error('a terminal scenario is handed term');
    await term.waitForText('Quit', { timeoutMs: 10_000 });
    await term.press('1', { title: 'Check status', subtitle: 'Press 1 for status.', holdMs: 2500 });
    await term.waitForText('all green', { timeoutMs: 10_000 });
    await demo.step({
      id: 'point-status', title: 'Status', subtitle: 'Status is green.',
      target: term.getByText('all green'), action: 'point', highlight: true, holdMs: 2500,
      run: async () => {},
    });
    await term.press('q', { title: 'Quit', subtitle: 'Quit the app.', expectExit: true });
  },
});
```

Record it with **no target**: `plaintake run mycli.demo.ts --output out/mycli`. A terminal
scenario refuses `--base-url` and `--fixture` (exit 2) because it starts its own page —
unless it declares `browser: true` to share the video with a web app, see
[Terminal and browser together](#terminal-and-browser-together). The interactive `plaintake`
menu runs terminal scenarios too: it skips the target question, or asks only for the
browser's URL when the scenario needs one.

What makes it work, and what bites:

- **Give every step a `holdMs` (or narration).** A terminal step finishes almost instantly —
  a keypress is milliseconds — so without a hold the steps bunch up at the start and the
  captions run on past the last thing the terminal drew, over a frozen final frame.
- **Strings match literally.** `term.waitForText('1.5 (beta)')` and `term.getByText(...)`
  look for exactly those characters; pass a `RegExp` when you want a pattern.
- **Key spellings are Playwright's.** `term.press('Enter')`, `'Space'`, `'Ctrl+C'`, and a
  space-separated sequence for a chord prefix: `'Ctrl+B c'`. `term.type(text)` types
  character by character at a fixed pace; `term.run(line)` types the line and presses Enter.
- **Say when the program is meant to end.** A process that exits during a step without
  `expectExit: true` fails the recording (exit 4), naming the step — so a crash is never
  filmed as a finished demo.
- **The environment is clean.** A temporary `HOME`, a `$ ` prompt, and a fixed `PATH`
  (`/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`). Your dotfiles do not
  load and your variables do not leak in: list each one the program needs in `env`, and add
  `'PATH'` there to inherit your own `PATH` instead.
- **Secrets come from the environment and are never typed.** Each `secrets` value is
  replaced with bullets before xterm draws it. As a backstop the screen is also sampled after
  each step and wait and once at the end — a sample, not a continuous watch, so a value that
  flashes up and is gone between samples is not caught by it. If a sample finds a value, the
  recording stops and **nothing is kept** — no video, no bundle. Typing a declared secret with
  `term.type`, `term.run` or `term.press` is refused (exit 2), because the trace records
  keystrokes. An unset or empty secret refuses the run (exit 2).
- **Hooks that open a page are refused** (exit 2): `preflight` and `warmup` would be handed
  the terminal page's address, and the page accepts one connection. Keep the page on the
  terminal throughout — a step that navigates it away fails the recording (exit 4). (With
  `browser: true` the refusal stands, for a different reason: a hook runs on the terminal's
  page and context, so a sign-in it made would never reach the web actor's own context.)
- **The program must print something.** One that shows nothing within 30 s of starting (such
  as `cat`, waiting for input) fails the recording (exit 4); print a banner or prompt first.
- **`uiScale` is refused** (exit 2): the font size already follows `cols` × `rows`. Change
  the grid to make the text larger.

### Terminal and browser together

When the demo goes back and forth — run a command, check the web app, return to the shell —
declare `browser: true` in `terminal`. The terminal becomes an actor named `term`, the web app
is another actor, and they take strictly sequential turns on one continuous recording (capture
is still one browser context and one page at any instant). Record it with exactly **one**
of `--base-url` or `--fixture`: `baseURL` in `run()` is the web target, and the terminal
starts on its own.

```ts
terminal: { command: ['./bin/mycli', 'menu'], cwd: '.', browser: true, label: 'Shell' },
async run({ demo, term, baseURL }) {
  if (term === undefined) throw new Error('a terminal scenario is handed term');
  await term.waitForText('Quit', { timeoutMs: 10_000 });
  await term.press('1', { title: 'Check status', subtitle: 'Press 1 for status.', holdMs: 2000 });

  const web = await demo.actor('web', { label: 'Web' });
  await web.page.goto(`${baseURL}/settings`);          // preload off screen, so the cut lands on a page
  await demo.turn(web);                                 // a hard cut
  await web.click(web.page.getByRole('link', { name: 'API Keys' }), {
    id: 'open-keys', title: 'Open API keys', subtitle: 'Open the API keys page.', holdMs: 2000,
  });

  await demo.turn(term.actor, { card: { lines: ['Back to the terminal'] } });   // a carded return
  await term.press('q', { title: 'Quit', subtitle: 'Quit the app.', expectExit: true, holdMs: 2000 });
}
```

- **A turn is a hard cut by default.** Set `transition: 'card'` in `terminal` to make the
  "Now: <label>" card the default instead, and decide per turn with `{ card: {...} }` (a card)
  or `{ card: false }` (a cut). `card: true` is refused (exit 2). `label` names the terminal
  on cards and the corner badge (default `Terminal`); `label` and `transition` need
  `browser: true`.
- **Preload the page you cut to.** A cut shows the next actor's first frame at once, so
  `web.page.goto(...)` while the terminal still holds the turn — raw Playwright, nothing
  recorded — lets the cut land on a rendered page instead of a blank load.
- **`term.run`, `type`, `press` and `waitForText` are refused (exit 2) while the web actor
  holds the turn.** Turn back with `demo.turn(term.actor)` first.
- **Two things are narrower than they look.** The Playwright trace covers only the terminal's
  context. And `terminal.secrets` masks only what the terminal draws, never web pixels — use
  `demo.mask` for a secret on a web page.
- **The cursor jumps at a cut** rather than gliding across it, because the frame changes
  entirely.
- **Give a narrated step before a cut a `holdMs` close to its reading time.** If its caption
  outlasts the capture the cut freezes the outgoing actor's last frame for the difference, so
  the next actor's first cue still starts on the next actor's first frame.
- **Every joint is frame-exact in a terminal-and-browser scenario**, cut or card. A plain web
  scenario that only ever uses cards and explain scenes between actors (no terminal, no cut)
  keeps the older placement, which promises no bound: each actor's recording can run longer
  than its turn (by a few frames on a typical web page, and a turn under about a second is
  recorded as a full second), so frames of the neighbouring actor can show at a joint, and a cue
  that overruns its segment shifts everything after it. Add a cut, or lengthen `holdMs`, if
  that shows.

The same rules apply: no `preflight`/`warmup`, and `uiScale` must be 1. A bundle with a cut
cannot be re-rendered by a release older than the one that wrote it.

### The static option: draw the output into the page

When a CLI step is one moment inside a *web* demo and you do not need the real shell on
screen, drawing the output is lighter than a live terminal. (If you do, see the section above.)

PlainTake films a browser, never your desktop, so a CLI step — issuing a key, running a
migration, grepping a server log — has no pixels of its own. The recipe: run the real command
from the scenario (it is a Node module), then draw its output into the page as a
terminal-styled panel pinned over the app. The recorder films the panel like any other
element; nothing is faked, because what it shows is the command's actual stdout.

```ts
import { execFileSync } from 'node:child_process';
import type { Page } from '@playwright/test';

const cli = (...args: string[]) =>
  execFileSync('./bin/mycli', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });

const escapeHtml = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

async function showTerminal(page: Page, command: string, outputHtml: string) {
  const html =
    `<div class="demo-term-bar"><span></span><span></span><span></span><b>terminal</b></div>` +
    `<pre><span class="demo-prompt">$</span> ${escapeHtml(command)}\n${outputHtml}</pre>`;
  await page.evaluate((inner) => {
    document.getElementById('demo-terminal')?.remove();
    const el = document.createElement('div');
    el.id = 'demo-terminal';
    el.innerHTML = inner;
    document.body.appendChild(el);
  }, html);
}

const hideTerminal = (page: Page) =>
  page.evaluate(() => document.getElementById('demo-terminal')?.remove());

const TERMINAL_CSS = `
#demo-terminal { position: fixed; left: 50%; top: 50%; transform: translate(-50%, -50%);
  width: 1500px; z-index: 100000; background: #0f172a; color: #e2e8f0; border-radius: 12px;
  box-shadow: 0 30px 80px rgba(0,0,0,.45); overflow: hidden; }
#demo-terminal .demo-term-bar { background: #1e293b; padding: 12px 16px; display: flex;
  gap: 8px; align-items: center; }
#demo-terminal .demo-term-bar span { width: 13px; height: 13px; border-radius: 50%;
  background: #f87171; }
#demo-terminal .demo-term-bar span:nth-child(2) { background: #fbbf24; }
#demo-terminal .demo-term-bar span:nth-child(3) { background: #34d399; }
#demo-terminal .demo-term-bar b { margin-left: 12px; color: #94a3b8;
  font: 600 15px system-ui, sans-serif; }
#demo-terminal pre { margin: 0; padding: 24px 28px; font: 18px/1.55 ui-monospace, Menlo,
  monospace; white-space: pre-wrap; overflow-wrap: anywhere; }
#demo-terminal .demo-prompt { color: #34d399; }
#demo-terminal .demo-hl { color: #fbbf24; font-weight: 700; }
`;
```

Inside `run`, register the mask first, inject the style after the page has loaded, then give
each command its own step pointed at the panel:

```ts
await demo.mask({ id: 'cli-secret', selector: '#demo-terminal .demo-secret' });
await page.goto(baseURL, { waitUntil: 'load' });
await page.addStyleTag({ content: TERMINAL_CSS });

const out = cli('apikey', 'create', '--service', 'billing');
const key = /key:\s+(\S+)/.exec(out)?.[1] ?? '';
await showTerminal(
  page,
  'mycli apikey create --service billing',
  escapeHtml(out).replace(key, `<span class="demo-secret">${key}</span>`),
);
await demo.step({
  id: 'cli-create', title: 'Issue a key',
  subtitle: 'An operator issues a key with the CLI. It is printed exactly once.',
  holdMs: 4500,
  target: page.locator('#demo-terminal pre'), action: 'point',
  run: async () => {},
});
await hideTerminal(page);
```

What makes it work, and what bites:

- **Wrap secrets in a span, mask the span.** The mask is registered before the panel exists,
  as the mask rule requires, and matches every panel the scenario draws later. Highlight the
  line a viewer should read (`demo-hl`) the same way. Anything else the page echoes — an API
  explorer's generated `curl` line repeating a header, say — hide with CSS in the same style
  tag rather than chasing it with a mask.
- **Stay on the page.** An overlay keeps the app's state: form inputs, an expanded panel, a
  signed-in session. Navigating away to "show a terminal" and coming back loses it. A
  navigation also drops the injected style and panel, so re-inject after one.
- **Trim to one line per fact.** Log lines carry fields nobody reads (user agents, trace
  ids) that wrap the panel into a wall. Cut them with a regex before escaping, and keep the
  fields the narration mentions.
- **Assert on the output, not the pixels.** The command's stdout is in hand; `demo.assert` it
  (the key is absent from `list`, the log has three failures) so the recording fails when the
  CLI misbehaves instead of filming it.
- **Output that varies varies the video.** Fresh ids, keys and timestamps differ every run,
  so a re-record will not match the last one frame for frame. Mask or normalize whatever
  changes if you need stable renders.

## `allowedConsoleErrors` hygiene

The metadata field takes exact strings, and the exactness is the whole mechanism — a
near-miss (`"Failed to load widget"` vs the app's `"Failed to load widget: registry
unavailable"`) allows nothing and fails the run on noise you meant to tolerate. Three rules
keep the list honest:

- **Copy the string verbatim from the console**, never from memory or a truncated log line.
- **Keep it short.** Every entry is a claim that this error is expected *every* run. If the
  list is growing, the app is getting noisier and the recording is hiding it.
- **Beware strings that vary.** A message containing a port, a URL, or a timestamp is a
  different string on every machine and every day. Either normalize what the app logs, or
  fix the underlying error instead of allowing it.

When a console error outside the list does appear, the run fails truthfully: the result
carries the recording's real counts, the reasons include the error text, and the bundle is
kept at `<output>.failed` for inspection — see
[Metadata](scenarios.md#metadata) in the guide.

## Post-deploy smoke tests

`plaintake check` was built as a fast CI gate — record and assert, no FFmpeg, no render —
and the same shape works as a blackbox smoke test after a deploy: point it at the URL you
just shipped, and a nonzero exit means something the scenario checks for is actually broken.

```sh
plaintake check smoke-login.demo.ts --base-url https://app.example.com --output out/smoke-login --json
```

`--base-url` takes any `http(s)://` URL — a production one included; nothing in the CLI
restricts it to `localhost`. The assertions in the scenario are whatever Playwright code you
write (`demo.assert({ run: () => page.getByText('...').waitFor() })`), so "does the
dashboard render", "is the API key list non-empty", "did login redirect" are all reachable
today.

**Exit codes are the gate.** 0 means every assertion held; anything else blocks the deploy:

| Exit | Meaning |
|---|---|
| 0 | Passed. |
| 1 | An assertion failed, or an unexpected console error was logged. |
| 2 | Usage — a bad flag, a malformed scenario. No browser opened. |
| 3 | Toolchain — something the environment needs is missing. |
| 4 | Capture — the recording itself broke. This is the code a bad deploy usually produces: a step whose selector never appears because the page changed shape, a navigation that 502s, anything Playwright throws that is not an assertion. |
| 5 | Render — `check` never renders, so this does not apply to it. |
| 6 | Verification — likewise not reachable from `check`. |
| 7 | Drifted — the recording differs from `<name>.baseline.json` beside the scenario, or the scenario changed since the baseline was recorded. Only fires when a baseline file exists and `--no-baseline` was not passed. |

Whichever code fires, a `.failed` bundle is published beside the requested output —
`trace/trace.zip`, `events/events.ndjson` and `events/summary.json` all kept — so a failed
smoke check leaves something to open, not just a log line. `--json`'s `assertions` array
carries `{id, status, message}` for every assertion that ran before the failure, recovered
from that same `events/summary.json` when the failure happened too early for a normal
result to carry them.

**Repeated runs into a fixed `--output`.** Every `check` (like every `run`) archives what
was there before to a `.<timestamp>` sibling rather than overwriting it — useful history for
a one-off investigation, noise for a check that runs on every deploy. Pass `--no-archive` to
replace in place, or point `--output` at a scratch path and let `plaintake prune` reclaim it
on a schedule. Omitting `--output` entirely gives `check` a fresh temp directory every run,
which is the right default for a gate that only needs the exit code most of the time.

**Authenticating an unattended run.** There is no secrets or credentials field in a scenario
or in `plaintake.config.json` — a scenario is a plain Node module, so the ordinary way in is
reading `process.env` inside a `preflight` hook, which runs before both tracing and the
screencast start, so a sign-in there reaches neither the video nor the trace:

```ts
async preflight({ page, baseURL }) {
  await page.goto(`${baseURL}/login`);
  await page.getByLabel('Email').fill(process.env.SMOKE_TEST_EMAIL!);
  await page.getByLabel('Password').fill(process.env.SMOKE_TEST_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('**/dashboard', { timeout: 0 });
}
```

For a session prepared some other way, `demo.actor(id, { contextOptions })` merges into
Playwright's `browser.newContext()` — every option except `viewport`/`deviceScaleFactor`
(every context captures at the one fixed size, laid out at the scenario's `uiScale`) passes through, `storageState` included, so a
pre-authenticated state file works exactly as it would in a Playwright test.

**A headless run's trace is not a safe place for real credentials.** Its DOM snapshotter
records every `INPUT`/`TEXTAREA` value verbatim, with no exemption for `type="password"`,
and its HAR recorder captures cookies — the same reason an on-session handoff records no
trace at all. Use disposable, scoped-down test accounts for an automated smoke check, never
a real user's session, and treat a `.failed` bundle from an authenticated scenario as
sensitive until you have looked at what it captured.

**A few more differences from recording a demo, worth knowing before pointing this at a
real deployment:** every capture blocks service workers, so a PWA or an offline-first app
may behave differently than it does for a real visitor. `waitFor`'s `timeoutMs` is bounded
to [5 000, 300 000] ms — useful to know if a slow endpoint needs a longer wait than the
120 s default. And the determinism convention above (no `Date.now()`, `Math.random()`,
external network beyond `baseURL`) is not enforced by `validate` — nothing stops a scenario
from being flaky against a live app; a stable smoke check is on the same footing as a
stable Playwright test, for the same reasons.

## Fixtures live beside the scenario

A data file the scenario reads belongs in the repository beside it, addressed relatively:

```ts
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const tenant = JSON.parse(
  await readFile(join(import.meta.dirname, 'fixtures', 'tenant.json'), 'utf8'),
) as { name: string };
```

`validate` refuses machine-specific absolute paths (`/Users/you/…`) by line number, because
a scenario that embeds one works on the machine that wrote it and nowhere else — the
recording you hand a colleague fails on their disk with a path they cannot create.
`import.meta.dirname` is where the scenario itself lives, so the fixture travels with it
through any checkout.
