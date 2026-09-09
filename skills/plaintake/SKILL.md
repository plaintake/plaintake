---
name: plaintake
description: Use when the user wants to create, record, re-render, or verify a PlainTake demo video (a narrated, deterministic browser demo driven by a TypeScript defineDemo scenario), or to write or fix a *.demo.ts scenario file, or to diagnose a failing plaintake validate, run, render, or verify.
---

# PlainTake

## Overview

PlainTake turns a committed TypeScript scenario into one deterministic browser demo video —
1920×1080 @ 30 fps H.264 `demo.mp4` with captions by default, or 9:16/1:1 via `--aspect`
(render-time only, never a re-record) — locally, no network at render time. The loop: write
the scenario, `validate` (no browser), `run` (records), `verify`; `render` re-renders a bundle
later without a browser.

A scenario file is executed as code. Treat it exactly as you would a test file in the same
repository.

## When to use

Demos of a web app — your own (`--base-url`) or the bundled fixture (`--fixture`);
re-rendering a bundle (captions soft ↔ hard); verifying a bundle's hashes; turning an
existing Playwright trace into a draft scenario (`plaintake import`, CLI only).

Not PlainTake: OS screen recording, page or microphone audio (sound is synthesized narration
only), non-deterministic content, any other viewport. macOS arm64 and Linux x64 only.

## MCP or CLI

If the `demo_validate`/`demo_run`/`demo_render`/`demo_verify` MCP tools are connected, prefer
them — descriptions self-contained, paths sandboxed to `--workspace`. Otherwise the CLI with
`--json`: result on stdout, diagnostics on stderr. Same workflow either way.

## Quick reference

| Command | Purpose |
|---|---|
| `plaintake validate <file>` | Check a scenario. No browser. Always first. |
| `plaintake run <file> --output <dir> (--base-url <url> \| --fixture)` | Record + render. Exactly one target. |
| `plaintake render <dir> [--subtitles hard\|soft] [--aspect 16:9\|9:16\|1:1]` | Re-render the frozen plan. No browser. |
| `plaintake verify <dir>` | Re-hash every artifact against the manifest. |
| `plaintake inspect <dir>` | Summarize a bundle — cues, chapters, narration. |
| `plaintake import <trace.zip> --output <draft.demo.ts>` | Draft a scenario from any Playwright trace — yours, or a bundle's own `trace/`. CLI only. |
| `plaintake doctor` / `install-browser` / `install-voice` | Toolchain check / Chromium / voice model. |

- `--subtitles` defaults to `soft` — read mistake 1 before embedding anything.
- Exit codes: `0` ok · `1` scenario/assertion · `2` args · `3` toolchain · `4` capture ·
  `5` render · `6` hash.
- Bare `plaintake` and `--help` print usage and exit `2` — on a pipe that is the design, not
  a failure.
- The video lands at `<output>/output/demo.mp4`, beside `captions/captions.{srt,vtt,ass}`,
  `manifest.json` and the Playwright `trace/` (no trace for handoff runs).
- `plaintake import` drafts with placeholder subtitles and whatever the trace recorded being
  typed — secret-looking fields are redacted, everything else lands verbatim. Read the draft
  before committing it.

`demo` methods: `step` (one user-visible action; `target` positions the cursor/camera and
**never acts**; `run` does the work), `assert`, `chapter`, `mask`, `waitFor`, `pause`,
`handoff` (a person takes the browser).

Recording, rendering, MCP, narration, both caption modes and MP4 chapter markers are free on
every tier; a licence buys camera zoom and credit removal/custom outro (`plaintake licence`
prints where you stand). Custom outro branding comes from `config.json`: `--config <path>` if
given, else the nearest `plaintake.config.json` walking up from the working directory (commit
one per product repo), else `~/.config/plaintake/config.json`.

## Example

Save as `create-api-key.demo.ts` (any `*.demo.ts`), then validate, run, verify — `--subtitles
hard` because a demo video usually ends up embedded:

```ts
import { defineDemo } from '@plaintake/scenario';

export default defineDemo({
  schema: 'agent-demo.scenario/v1',
  id: 'create-api-key',
  title: 'Create an API key',
  viewport: { width: 1920, height: 1080, deviceScaleFactor: 1 },
  locale: 'en-US', timezoneId: 'UTC', colorScheme: 'light', reducedMotion: 'reduce',
  async run({ page, demo, baseURL }) {
    await demo.mask({ id: 'secret', selector: '[data-testid="api-key-value"]' });
    await demo.chapter('Organization settings');
    await demo.step({
      id: 'open-settings', title: 'Open organization settings',
      subtitle: 'Open the organization settings.', holdMs: 1500,
      target: page.getByRole('link', { name: 'API Keys' }), action: 'click',
      run: () => page.goto(`${baseURL}/settings`, { waitUntil: 'load' }),
    });
    await demo.assert({
      id: 'settings-visible', title: 'Settings heading is visible',
      run: () => page.getByRole('heading', { name: 'Organization settings' }).waitFor(),
    });
  },
});
```

```sh
plaintake validate create-api-key.demo.ts
plaintake run create-api-key.demo.ts --output out/create-api-key --fixture --subtitles hard --json
plaintake verify out/create-api-key --json
```

Swap `--fixture` for `--base-url http://localhost:3000` to record your own app, and adjust
the selectors. The `@plaintake/scenario` import resolves in the installed binary with nothing
installed (a fallback ships inside it); the npm package adds editor autocomplete and takes
precedence; a source checkout needs it installed in your project.

## Common mistakes

1. **Soft captions are invisible where demos get shared.** The default `--subtitles soft`
   muxes a track no browser, Slack, X, LinkedIn or GitHub embed renders — a silent video with
   no visible words. `--subtitles hard` for anything posted or embedded; `captions.srt` and
   `.vtt` are written either way.
2. **Camera zoom and narration are frozen at record time.** A run without them cannot be
   re-rendered into them — re-record. Caption mode is the opposite: any bundle re-renders
   soft ↔ hard.
3. **Exactly one run target.** `--base-url` or `--fixture`, never both, never neither (exit 2).
4. **A `handoff` needs a person, a visible browser and a real terminal.** Declare `handoff:
   'preflight'` (or `'session'`) in the scenario **metadata**, not on the call — it is read
   before Chromium starts. Refused with `--fixture`, over MCP without elicitation, and
   through a pipe — exit 2, nothing launched; don't retry, hand the user the exact
   `plaintake run` command. Preflight handoffs reach neither video nor trace; `session` ones
   are filmed.
5. **`--voice` requires `--speech on`** — refused, not ignored.
6. **Set `holdMs` and speakable subtitles.** Narration runs ≈20 characters/second with a
   1200 ms floor; without holds the video is a frozen frame with captions scrolling over it.
7. **Register `demo.mask` before the element exists**, with a CSS selector, not a Locator —
   that is what keeps the secret out of every frame.
8. **Determinism: no `Date.now()`, `Math.random()`, or external network**, and erasable
   TypeScript only (no `enum`, `namespace`, parameter properties, decorators) — `validate`
   names the offender before a browser opens. Pass `{ timeout: 0 }` to Playwright calls
   inside `until`, so the DSL's `timeoutMs` governs.

## Deeper reference

Full DSL — metadata, `preflight`/`warmup`, the `intro` card, camera framing, handoff modes:
<https://github.com/plaintake/plaintake/blob/main/docs/scenarios.md>. Metadata schema:
<https://github.com/plaintake/plaintake/blob/main/schema/scenario.schema.json>. When in
doubt, the MCP tool descriptions and `plaintake --help` are authoritative.
