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
message out of its HTTP API from `waitFor`:

```ts
let code: string | undefined;

await demo.waitFor({
  id: 'otp-arrives',
  title: 'The one-time code arrives',
  until: async () => {
    const search = await page.request.get(
      'http://localhost:8025/api/v1/search?query=welcome%40demo.example',
    );
    if (!search.ok()) return false;
    const { messages } = (await search.json()) as { messages: Array<{ ID: string }> };
    const latest = messages.at(-1);
    if (latest === undefined) return false;
    const message = await page.request.get(`http://localhost:8025/api/v1/message/${latest.ID}`);
    const { Text } = (await message.json()) as { Text: string };
    const match = /\b(\d{6})\b/.exec(Text);
    if (match === null) return false;
    code = match[1];
    return true;
  },
  timeoutMs: 30_000,
});
```

The one thing not to do is fetch once and assert. A single GET races SMTP delivery — the
message is milliseconds away but not there yet, and the scenario fails a recording that would
have succeeded a heartbeat later. In a test suite that is a retry; in a recording it is a
whole re-record. `waitFor` re-evaluates `until` until it holds — that is the entire point of
it, and email is the case it was shaped by.

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
