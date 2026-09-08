# PlainTake — demo videos you can re-run

> Turns a committed TypeScript file into a narrated browser demo video — locally, with no
> network at render time and nothing to sign up for.

You write the demo as code. PlainTake drives a real Chromium through it, times the
narration, renders the captions, and hands you the video plus everything needed to prove how
it was made. Re-run it after a UI change and you get the same demo again, updated.

**Website:** [plaintake.github.io](https://plaintake.github.io) ·
**Download:** [latest release](https://github.com/plaintake/plaintake/releases/latest) ·
**Buy a licence:** [plainlab.gumroad.com/l/plaintake](https://plainlab.gumroad.com/l/plaintake)

Each run produces:

- `demo.mp4` — one H.264 video, captions as a selectable track by default, or `--subtitles
  hard` to burn them into the pixels instead
- `captions.srt`, `captions.vtt`, `captions.ass` — standalone caption files
- an evidence bundle: the scenario source, the raw capture, a Playwright trace, the semantic
  event timeline, the exact render plan, the toolchain versions, and a SHA-256 manifest you
  can re-verify at any time

**The output is silent by default, so the captions carry the whole demo — and where the video is
going decides which kind you want.** `--subtitles soft`, the default, muxes a selectable track
that desktop players render. **`--subtitles hard` burns the words into the pixels, and that is
the one to pass for anything you are going to post or embed**: no browser renders an
in-container caption track, and neither do Slack, X, LinkedIn or GitHub, so a soft track leaves
a silent video with no visible words in exactly the places demo videos get shared — and most of
them are watched muted. The `.srt` and `.vtt` files are written on every run either way, for a
`<track>` tag or a translation source.

**It can also make the video talk, free on every tier.** `--speech on` reads every caption aloud with a voice
model that runs on your own machine — no network, no account, no API key — and holds each step
open long enough to finish the line. `--speech file` speaks WAVs you supply instead, so a human
voiceover, or a cloud voice you already pay for, gets into the video without PlainTake ever
holding a credential. The captions stay either way: a video that talks is exactly the case where
a muted viewer would otherwise get nothing.

## What it looks like

![PlainTake recording a release-approval demo: the cursor moves to each target and the camera zooms in to follow it](assets/demo-preview.gif)

The full narrated video, and the free-tier stills and manifest this preview is drawn from, are
in [`docs/samples/`](docs/samples/). The landing-page video was recorded by PlainTake from a
scenario — the exact source, the command, and every flag it used are published in
[`docs/site-demo/`](docs/site-demo/).

More videos made with PlainTake are on
[YouTube](https://www.youtube.com/@plainlabdev).

---

## Before you install

| Requirement | Notes |
|---|---|
| **FFmpeg, with libass** | Installed separately. Read the next paragraph — this is the one thing that goes wrong. |
| Chromium | Downloaded once by `plaintake install-browser`, about 350 MB |
| Node.js | **Not needed.** The download contains its own. |

### FFmpeg must have libass

Burning captions into the pixels needs an FFmpeg built with libass. **Homebrew's default
`ffmpeg` formula is built without it**, so it has no `ass` or `subtitles` filter and hard
subtitles are impossible. `ffmpeg-full` has it, but it is keg-only — installing it is not
enough, it must also be linked:

```bash
brew uninstall --ignore-dependencies ffmpeg
brew install ffmpeg-full
brew link --force --overwrite ffmpeg-full
```

On Debian and Ubuntu, `apt install ffmpeg` already has libass.

Either way, confirm it before doing anything else:

```bash
plaintake doctor
```

It exits non-zero with install instructions if anything is missing, and tells you which
FFmpeg and libass it found.

---

## Install

Two builds: **macOS arm64** (Apple Silicon) and **Linux x64**. No Windows build, and no macOS
Intel build.

```bash
# 1. Download the tarball for your platform, the checksums, and the installer
VERSION=1.7.0
BASE=https://github.com/plaintake/plaintake/releases/download/v$VERSION
curl -LO $BASE/plaintake-$VERSION-darwin-arm64.tar.gz   # or -linux-x64
curl -LO $BASE/SHA256SUMS
curl -LO $BASE/install.sh

# 2. Check what you downloaded is what was published
shasum -a 256 -c SHA256SUMS --ignore-missing

# 3. Install
sh install.sh plaintake-$VERSION-darwin-arm64.tar.gz
```

That installs to `~/.local/share/plaintake` and symlinks `plaintake` into
`~/.local/bin`. Override either with `PLAINTAKE_PREFIX` and `PLAINTAKE_BINDIR`. If
`~/.local/bin` is not on your `PATH`, the installer says so.

Then, once:

```bash
plaintake install-browser     # downloads Chromium
plaintake doctor              # checks FFmpeg
plaintake                     # the menu
```

**Without the installer.** The tarball is a self-contained tree and the binary finds its own
resources, so this works too:

```bash
tar -xzf plaintake-$VERSION-darwin-arm64.tar.gz
./plaintake-$VERSION-darwin-arm64/bin/plaintake doctor
```

**Upgrading** is the same three steps. The installer replaces the whole tree rather than
merging into it — a half-upgraded install with a new binary and an old vendored Playwright is
worse than no install. Your settings and licence live in `~/.config/plaintake` and are not
touched.

**Uninstalling** is `rm -rf ~/.local/share/plaintake ~/.local/bin/plaintake`, and
`rm -rf ~/.config/plaintake` if you also want the settings and licence gone.

### Why FFmpeg and Chromium are not included

- **FFmpeg**, because the builds this needs are GPL (via libx264), and keeping it a separate
  executable is what keeps those terms off PlainTake and therefore off what you make with
  it. See [`NOTICE.md`](NOTICE.md).
- **Chromium**, because it is ~350 MB with its own licence set, and Playwright's cache is
  shared with any other Playwright install you already have.

---

## For humans

### The menu

`plaintake` with no arguments opens a terminal menu: record a demo, browse recordings,
settings, licence, toolchain check.

**Recordings** lists every recording under the current directory and, for the one you pick,
offers: play the video, open the folder, show the details, verify the hashes, re-render, or
delete. Deleting asks first and names the size, and refuses anything that is not a recording.

It only starts on a real terminal. Piped, or given a command, you get usage and a non-zero
exit — so an agent running `plaintake` never sits waiting on a prompt.

### Commands

```
plaintake validate <scenario.ts>
plaintake run      <scenario.ts> --output <dir> (--base-url <url> | --fixture)
                                  [--subtitles soft|hard] [--cursor on|off]
                                  [--camera off|zoom] [--aspect 16:9|9:16|1:1]
                                  [--speech off|on|file] [--voice <id>]
                                  [--config <path>]
plaintake check    <scenario.ts> (--base-url <url> | --fixture) [--output <dir>]
plaintake render   <bundleDir> [--subtitles soft|hard] [--aspect 16:9|9:16|1:1]
plaintake verify   <bundleDir>
plaintake diff     <bundleDirA> <bundleDirB>
plaintake inspect  <bundleDir>
plaintake prune    [--older-than <duration>] [--keep-last <n>] [--scenario <id>] [--yes]
plaintake doctor
plaintake install-browser
plaintake install-voice [--voice <id>]... [--all-voices]
plaintake activate <licence-key>
plaintake licence
plaintake --version
```

| Command | What it does |
|---|---|
| `validate` | Loads a scenario and checks it, without opening a browser |
| `run` | Records, times the captions, renders, hashes, and writes a recording |
| `check` | Records and asserts without rendering — no FFmpeg needed, fast enough for every pull request |
| `render` | Re-renders from a recording's frozen plan. No browser, no network, no clock |
| `verify` | Re-hashes every file against the manifest |
| `diff` | Semantic diff between two bundles — steps, assertions, target position/name, timing and captions. No frame comparison |
| `inspect` | Reports the video, captions, chapters, output sizes and toolchain. Read-only |
| `prune` | Deletes recordings under the working directory, selected by age, count or scenario. Dry-run unless `--yes`. No MCP tool |
| `doctor` | Checks FFmpeg, libass, x264 and the filters that are needed, and reports whether the voice model is installed |
| `install-voice` | Downloads the voice model `--speech on` needs. Once, and only if you want narration |
| `activate` | Verifies a licence key with Gumroad once and saves it locally. Headless alternative to the TUI's *Enter a licence key* |
| `licence` | Prints the current licence state — Free or Pro. Read-only |

`run` needs exactly one target: `--base-url http://localhost:3000` for your own app, or
`--fixture` for the bundled demo app the shipped examples record against.

`--cursor on` draws a pointer that glides between the scenario's targets and ripples on
clicks; `off`, the default, records none. It is drawn when the video is rendered, from the
recording's frozen plan, so two renders of the same recording stay byte-identical.

`--camera zoom` (Pro) eases the frame in on whatever each step already targets, so the button
being clicked fills the screen instead of sitting in a corner of a full-page shot. The path is
computed from the recorded steps — the same ones the captions and chapters come from — and
frozen into the plan alongside them, so it is as repeatable as everything else here and no
model chose it. `off`, the default, films the raw viewport. Captions and the closing card
never zoom either way.

`--aspect 9:16` (or `1:1`) fits the finished video to a vertical or square feed. The whole 16:9
picture is scaled into a box inside the taller frame and the space left over becomes a flat dark
band — nothing is cropped away — and the captions move off the video and into that band, where
they get more room than they have ever had over the picture. What gets recorded does not change:
capture is always 1920×1080 whatever you pass, and `16:9` is the default and the video this tool
has always rendered. Since the shape is chosen at render time, a recording you already have can
often be re-cut with `plaintake render <bundleDir> --aspect 9:16` without recording it again — the
same thing that makes switching subtitle modes a re-render rather than a re-record. "Often"
because a caption line is wrapped to fit its frame at record time, and the letterboxed frame is
narrower: a 16:9 recording whose captions run long enough is refused rather than re-cut into
words that would run off the edge, naming the offending line. `run --aspect` from the start always
avoids this, because the captions are wrapped for the right frame from the first take.

Recording for more than one product? Commit a `plaintake.config.json` at each product's repo
root with its own outro branding (Pro) — `run` finds the nearest one walking up from the
working directory, otherwise falls back to this machine's global config. `--config <path>`
picks a file outright; a missing or invalid one is a usage error rather than a silent
fallback.

Add `--json` to any command for a machine-readable result on stdout. Diagnostics always go to
stderr, and the two are never mixed.

| Exit | Meaning |
|---:|---|
| 0 | Success |
| 1 | Scenario or assertion failed |
| 2 | Invalid arguments |
| 3 | Missing toolchain dependency |
| 4 | Capture failure |
| 5 | Render failure |
| 6 | Verification or hash failure |

### Writing a demo

Scenario files import `@plaintake/scenario`. The installed binary ships a fallback copy, so
this runs with nothing else installed — `npm install --save-dev @plaintake/scenario` in your own project
only if you want editor autocomplete while writing one; your copy then takes precedence over
the built-in fallback.

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

`demo` also has `waitFor`, `handoff` and `pause`, and a scenario can declare an opening title
card (`intro`) or per-page camera framing (`camera`). `plaintake validate` checks all of it —
metadata shape, determinism rules, stable ids — with no browser. The complete field-by-field
reference, with every `demo` method and every rule, is
**[`docs/scenarios.md`](docs/scenarios.md)**.

### Demos of an app behind a login

A one-time code or a CAPTCHA cannot be scripted. A demo can stop and hand you the real browser
window instead, and carry on once you are done — declared with `handoff: 'preflight'` (or
`'session'`, if the challenge is part of the demo itself) in the scenario's metadata, and
`demo.handoff()` in the matching phase. You act in the browser, never in PlainTake: it
never asks for a password, and a recording made this way stores no Playwright trace at all.
Full details, including which mode to use and why: **[`docs/scenarios.md`](docs/scenarios.md)**.

### Multiple actors

A demo with more than one person in it — an admin who sets something up, a customer who
finishes it — can be named as two actors on one continuous recording, rather than forced
through a single page pretending to be both. `demo.actor(id)` introduces each one with its
own browser context; `demo.turn(actor)` hands the browser between them, drawing a persistent
corner badge that names whoever is active and, optionally, a full-frame transition card
between turns. Only one actor's context is ever active at once — capture stays exactly one
browser context, one page, turn by turn — which is what keeps a multi-actor recording exactly
as reproducible as a single-actor one. The badge and the transition card are both free on
every tier, and a `session`-phase handoff works from any actor's turn, not only the default one.

### What a recording contains

```text
artifacts/create-api-key/
├── scenario/scenario.ts        the exact source that ran
├── raw/session.webm            the raw capture
├── trace/trace.zip             a Playwright trace you can open
├── events/events.ndjson        what happened, and when
├── captions/captions.{srt,vtt,ass}
├── render/render-plan.json     the frozen plan, including the FFmpeg arguments used
├── output/demo.mp4             the one video, in the mode you asked for
├── logs/                       one log per FFmpeg run
├── manifest.json               a SHA-256 of every file
└── manifest.sha256             a hash of the manifest itself
```

Because the plan is frozen, `plaintake render` on an old recording needs no browser, no
network and no clock — and produces the same bytes it did the first time, on the same machine
and FFmpeg build. `plaintake verify` re-checks every hash, including the manifest's own.

Nothing is deleted automatically. Recordings accumulate until you remove them, and the
Recordings panel in the menu is how you do that.

---

### Free and Pro

| | Free | Pro |
|---|---|---|
| Every recording, rendering and MCP feature | ✅ | ✅ |
| Spoken narration — a local voice model, or your own audio | ✅ | ✅ |
| Selectable caption track as well as burned-in | ✅ | ✅ |
| Closing credit card | 3s *Made with PlainTake* | removed |
| Your own outro text and colours | ❌ | ✅ |
| MP4 chapter markers from `demo.chapter()` | ✅ | ✅ |
| Multiple actors, each their own context (`demo.actor()`/`demo.turn()`) | ✅ | ✅ |
| Camera that zooms toward each step's target | ❌ | ✅ |
| Price | free | one-time, perpetual |

**Buy a licence: [plainlab.gumroad.com/l/plaintake](https://plainlab.gumroad.com/l/plaintake)** —
the current price is on that page.

Then `plaintake` → *Licence* → *Enter a licence key*, or headlessly with
`plaintake activate <licence-key>`. Either way it makes one request to Gumroad and caches the
answer; nothing afterwards touches the network. `plaintake licence` prints the current state.
One payment, no subscription, and install it on as many of your own machines as you need.

**Chapter markers are free on every tier.** They come only from `demo.chapter()` calls and are
frozen into the recording as it is made — a demo recorded while chapters needed a licence
re-renders without them, so record it again to add chapters.

**The camera is the one capability that still needs a licence,** and it freezes the same way:
the shot list is worked out while the recording is made, so a recording made on Free has none,
and re-rendering it cannot add one. If you want the zoom on a demo you already recorded,
record it again.

**Narration is free on every tier,** in both modes. `--speech on` reads your captions aloud with
a local voice model, `--speech file` speaks WAVs you supply, and neither needs a licence — a
demo that reads itself aloud is an accessibility default, not a finish.

**Captions are free in every form,** and always were in most of them. `captions.srt` and
`captions.vtt` sit beside the video whatever you paid, and so does `--subtitles
soft`, which muxes the track *into* the MP4 for the desktop players that render one — now the
default. Pass `--subtitles hard` for anything headed to a browser, a chat thread or a muted
autoplay embed, none of which show an in-container track. The caption arguments for both modes
are frozen into every bundle, so any recording you already have can be re-rendered either way
without recording it again.

**The videos are yours on both tiers.** No ownership claim, no licence back to us, no
restriction on selling what you make. See [`LICENSE`](LICENSE) §3.

### What it does not do

Stated up front rather than discovered later:

- **The only sound is the captions read aloud** — no microphone, no page audio, no system
  audio, no music, no sound effects. `--speech on` needs a one-time 93 MB voice-model
  download. There are 28 English voices and no per-voice tuning; speed is a scenario-level
  `speech.speed` dial (0.5–2.0×), not a per-step or per-voice one, and there is no per-step
  override; the pronunciation dictionary is US English only, so a non-English scenario
  gets captions and no voice rather than an accent reading the wrong sounds. A video that talks
  is longer than the same demo recorded silent, because each step waits for its line to finish.
- **macOS arm64 and Linux x64 only.** No Windows build. No macOS Intel build.
- **Chromium only**, one tab, one page.
- **Capture is always 1920×1080 at 30 fps.** No other capture size, no other frame rate.
  `--aspect` changes the shape of the finished video and nothing else: `9:16` and `1:1`
  letterbox that same capture instead of cropping it, and leaving the flag off gives you the
  16:9 video this tool has always produced.
- **The cursor is optional and synthetic.** `--cursor on` draws one pointer shape with click
  ripples, generated from the scenario's targets — it is not your real mouse, there are no
  styles to configure, and `off` (the default) films none.
- **The camera zooms, and that is all it does.** `--camera zoom` crops toward the rect a step
  already targets and eases between shots. It never decides *what* is interesting — no
  saliency, no model, no scene detection — so a step with no target moves nothing. The zoom is
  upscaled from the same 1920×1080 capture, so it is capped at 1.6× before the text turns to
  mush, and it costs render time. `off` is the default and films the raw viewport.
- **Captions are written by you**, never transcribed.
- **Chapter markers come only from `demo.chapter()`** — never invented from step titles.
- **A `session` handoff is filmed.** No pause, no resume, nothing cut out — so a code the page
  shows in the clear while you work is in the finished video. `preflight` is the mode that
  avoids that, and `demo.mask()` covers a field you name and nothing else, not a toast and not
  the URL bar. A demo recorded this way is also not reproducible: your own timing is an input to
  it, though re-rendering the recording afterwards is as reproducible as any other.
- **A handoff opens a visible browser**, which draws text on slightly different pixels than the
  headless one and asks for `/favicon.ico`. An app without a favicon logs a 404 that fails the
  run; the recorder log explains it, and `allowedConsoleErrors` is where you silence it.
- **Nothing prunes old recordings on its own.** `plaintake prune` deletes on request — dry-run
  unless you pass `--yes` — but there is no automatic retention policy and no MCP tool for it.
  Deleting is a deliberate act, whether that is the TUI's confirmation or `--yes` on the CLI.
- The licence check runs on your own machine in a binary you hold, so it is
  tamper-*evident*, not tamper-proof. It is a receipt, not a lock, and a licensing failure
  never blocks a recording — it falls back to the free tier and says why.

### Support

- **Something is broken:** [open an issue](https://github.com/plaintake/plaintake/issues/new/choose).
  Please include the output of `plaintake doctor --json`, which names your version, FFmpeg
  and libass.
- **Purchases, keys and refunds:** through
  [Gumroad](https://plainlab.gumroad.com/l/plaintake), which handles payment.

This repository is the download and issue channel.

---

## For agents

PlainTake includes a local MCP server over stdio — four tools, no network, no credentials,
no account. If your agent shells out to CLIs instead of speaking MCP, the same four
operations (`validate`/`run`/`render`/`verify`) are plain commands: see [Commands](#commands)
above and pass `--json` for a machine-readable result.

**Claude Code**, in your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "plaintake": {
      "command": "plaintake",
      "args": ["mcp", "--workspace", "/abs/path/to/your/project"]
    }
  }
}
```

**Codex**, in `~/.codex/config.toml`:

```toml
[mcp_servers.plaintake]
command = "plaintake"
args = ["mcp", "--workspace", "/abs/path/to/your/project"]
```

`--workspace` is a sandbox root: every path a tool accepts must resolve beneath it, and
traversal, absolute paths outside it and symlink escapes are all refused.

It is optional: omitted, the root is the server's cwd — the directory the client launched
from, which in Claude Code is your project — so a config shared across projects can omit it
and follow the client. Pass it when the client may spawn the server from somewhere
unrelated, or to pin the root explicitly. It constrains file paths only; the recorded app
is chosen per call by `demo_run`'s `baseURL` or `fixture`.

⚠️ **Scenario files are executed as code** by `validate` and `run`. The sandbox constrains
which paths the tools accept, not what a loaded scenario may do. Treat a scenario file exactly
as you would treat a test file in the same repository, and do not point the tools at a
directory whose contents you would not run.

A demo that declares `handoff` **needs a visible browser window and a terminal** — and whether
an agent can run one depends on its client. The server is local, so the window opens on your
screen either way. A client that supports elicitation relays the question into the chat: it
tells you the window is open, you do the sign-in or the CAPTCHA in the browser, and you answer
*done* in the chat when you are. The question carries a single checkbox and nothing else, so
there is still nowhere to type a secret — the agent can validate, run, render and verify the
whole recording. A client without elicitation is refused immediately, with nothing launched,
and starting the recording is yours: run `plaintake run` in a terminal. The tool description
says which case you are in.

**Writing a scenario without reading this project's source:** the four MCP tool descriptions
are self-contained — `demo_validate`'s description spells out the full `defineDemo()` shape, every `demo`
method, and the determinism rules, so an agent that only ever sees the tool list can still
write a valid one. For more depth than a tool description carries, or for validating outside
an MCP session entirely, use **[`docs/scenarios.md`](docs/scenarios.md)** (the full DSL
reference) and **[`schema/scenario.schema.json`](schema/scenario.schema.json)** (the metadata
schema as JSON Schema).

**A skill your agent can carry:** [`skills/plaintake/`](skills/plaintake/) is a self-contained
agent skill — the `SKILL.md` format Claude Code, Codex and their kin read — covering the whole
workflow: writing a scenario, `validate` → `run` → `verify`, and the mistakes that cost a
re-record. Copy the folder into `.claude/skills/` (Claude Code) or `~/.agents/skills/` (Codex).
It defers to the MCP tool descriptions and `docs/scenarios.md` for depth rather than
duplicating them.

---

PlainTake is proprietary software; see [`LICENSE`](LICENSE) for the terms and
[`NOTICE.md`](NOTICE.md) for the third-party components it uses. Noto Sans is bundled under the
SIL Open Font License 1.1 and Playwright is redistributed under Apache-2.0. FFmpeg is a
separately installed external executable and is deliberately not redistributed.

&copy; 2026 PlainLab
