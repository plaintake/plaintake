# How the quickstart video was taken

The quickstart tutorial (install PlainTake, validate a scenario, record it, watch the MP4 and
verify the bundle) was recorded by PlainTake itself, from this folder. Nothing was
screen-recorded, edited or re-taken, and **every command on screen really ran**.

## A real terminal and a real browser

The scenario declares a `terminal` with `browser: true` (PlainTake 1.27.0 and later). So the
video takes turns between two actors: a live shell drawn in a terminal page, and an ordinary
browser. The scenario switches between them with `demo.turn`, and each switch is a hard cut.

- **The terminal** starts in a fresh working directory holding what the
  [install guide](../../README.md#install)'s download step leaves behind: the release tarball,
  `SHA256SUMS` and `install.sh`. The video checks the checksum, runs the installer, puts
  `~/.local/bin` on `PATH` and from then on uses the installed binary. It runs
  `plaintake validate`, `plaintake run … --fixture` and `plaintake verify` against the example
  scenario, [`examples/release-approval.demo.ts`](https://github.com/plaintake/plaintake/blob/main/examples/release-approval.demo.ts).
  The terminal's `HOME` is a throwaway directory PlainTake creates for the run, so the install
  touches nothing on the recording machine.
- **The browser** fills the time the nested `plaintake run` spends recording. It shows the
  scenario file being recorded, read from the terminal's working directory by
  [`serve.mjs`](serve.mjs) and rendered by [`pages/code.html`](pages/code.html). Once the run
  has finished, [`pages/watch.html`](pages/watch.html) plays the MP4 that run just wrote. The
  listing and the video on screen are the actual files, not copies.

The one step not filmed is the download itself, because a recording never opens a socket. The
tarball in the working directory is built from the same checkout, so the version on screen is
the one being released.

## The scenario

[`quickstart.demo.ts`](quickstart.demo.ts) is the exact source that ran. It has an intro card,
five chapters (Install, Validate, Record, The scenario, The bundle), narrated steps and two
cuts each way between terminal and browser. Three details are worth copying:

- **Preload before the cut.** The browser's pages are loaded with the raw `web.page.goto`
  while the terminal still holds the turn. That way each cut lands on a rendered page instead
  of a blank one, and the player has already fetched the MP4.
- **Steps in the browser's turn go through the browser actor** (`web.step`, `web.click`).
  `demo.step` belongs to the default actor, which here is the terminal, and is refused while
  the browser holds the turn.
- **Mind the badge corner.** A multi-actor recording draws the actor's name ("Terminal",
  "Browser") in the top-left corner. The terminal page starts its grid below the badge on its
  own. A web page does not, so the pages' headers start to the right of it.

## The command

```sh
make quickstart-demo
```

This builds the release tarball for this platform (`make binary`) and recreates the terminal's
working directory: the tarball, `SHA256SUMS`, `install.sh`, the example scenario and this
folder's `plaintake.config.json`. It then starts the pages server and runs

```sh
plaintake run public/docs/quickstart-demo/quickstart.demo.ts \
  --output artifacts/quickstart-demo \
  --base-url http://127.0.0.1:4173 \
  --subtitles soft --cursor on --speech on \
  --config public/docs/quickstart-demo/plaintake.config.json
```

`--base-url` is the browser actor's target. The terminal needs no target of its own.

It also sets `PLAYWRIGHT_BROWSERS_PATH`, which the scenario lists in `terminal.env`. The
terminal's clean `HOME` has no Chromium, so this points the freshly installed binary at the
recording machine's Chromium. In the video, that variable stands in for a one-time
`plaintake install-browser`.

What each flag contributed:

- `--subtitles soft`: a selectable caption track. That suits YouTube, where the `.vtt` sidecar
  is uploaded as closed captions. For anywhere that ignores in-container tracks, re-render with
  `plaintake render --subtitles hard`.
- `--cursor on`: the pointer moves to each step's declared `target`, and jumps rather than
  glides at a cut.
- `--speech on`: the narration, synthesised locally from the steps' subtitles. If a run reports
  `speech.slow`, run `plaintake warm artifacts/quickstart-demo` and record again.
- `--config plaintake.config.json`: pins the outro card to **Made with PlainTake**. The nested
  run picks up the same file from its working directory, so the credit inside the player
  matches the one the tutorial ends on.

Note that there is no `--camera zoom`. At its zoom cap the camera's frame is narrower than the
code lines this tutorial films. With no Pro flags at all, the command runs as written on the
Free tier.

## One honest caveat

This recording is **not byte-identical across runs**, for two reasons. The nested run's output
(timings, file sizes) is real and differs a little each time. And the player plays a real
`<video>` element, which adds frame-level jitter. Each run still passes `plaintake verify`, and
re-rendering the frozen bundle is unaffected. It is the same exclusion `make reproduce` makes
for any arbitrary app.

## Publishing to YouTube

For the **@plainlabdev** channel, following the convention used by the landing-page video:

- Upload `artifacts/quickstart-demo/output/quickstart-demo.mp4`.
- YouTube does **not** display the soft `mov_text` track. Upload
  `artifacts/quickstart-demo/captions/captions.vtt` as an English caption file (Studio →
  Subtitles → Add language → English → Upload file → With timing), or nobody will see the
  narration text.
- YouTube takes only JPG or PNG thumbnails:
  `ffmpeg -i <poster> -frames:v 1 -q:v 2 quickstart-thumb.jpg`.
- Publish as Unlisted first, check the captions, then make it Public.
