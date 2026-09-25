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

## Showing a terminal: draw the output into the page

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
(every context captures at the one fixed size) passes through, `storageState` included, so a
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
