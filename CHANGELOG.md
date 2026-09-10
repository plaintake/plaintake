# Changelog

`scripts/release.sh` reads the section for the version being released and uses it as the
GitHub release notes, so this file is the source of what a customer reads — not a summary
written afterwards.

## 1.10.0

**A demo in your colours.** A Pro licence already bought the closing card; it now buys the
demo's chrome too. Four optional fields in `plaintake.config.json`'s `branding` block —
`accentColor`, `captionTextColor`, `captionOutlineColor`, `captionBoxColor` — recolour the
synthetic cursor's fill and its click ripple, the highlight label's text, and the burned-in
caption plate. Each field is independent: set the accent alone and the captions keep their
tuned defaults, set the caption box alone and the cursor stays white. Every value is a
six-digit `#RRGGBB` string, and the fields are editable in the terminal UI on the settings
screen labelled *Branding and theme*. Pro-only, gated exactly like the card: the free tier
ignores theme fields entirely — a configured field is never partly honoured, the same policy
that keeps the credit unbypassable.

**Frozen at record time, like everything a licence buys.** The theme is resolved once, when
`plaintake run` reads the config and licence of that moment, and frozen into the bundle's
render plan. A themed bundle re-renders the same bytes on any machine, licensed or not, and
an `--aspect` re-cut keeps the theme. A run with no theme fields set — free or Pro —
produces bytes identical to 1.9.0's, so theming is additive and an unbranded workflow
changes not at all. One version note, in the honest direction: a PlainTake older than
1.10.0 re-rendering a themed bundle still draws the themed colours, because the caption and
cursor tracks are executed verbatim from the bundle — but a re-cut on that older binary
redraws them in the default colours, the same skew any new plan field has always had.

**Where colour exists, it follows the theme; where it doesn't, that's stated.** Caption
colours apply to the hard burn and the `.ass` sidecar; the soft `mov_text` track and the
`.srt`/`.vtt` sidecar carry no colour concept in their formats, so there is nothing to
theme there. The caption style's tuned metrics — font, outline width, box opacity, margins,
alignment — stay fixed; only the colours move. And the multi-actor corner badges stay
white in a themed demo: a separate track with fixed colours, deliberately out of this first
round, so a themed two-actor demo shows white badges rather than tinted ones. Recorded
here so it reads as a decision, not an oversight.

## 1.9.0

**Explain while demoing.** `demo.explain({id, title, narration, scene, cues?, voice?})` cuts
away from the recording to a full-frame, narrated motion-graphics scene — a title card, a
process diagram, a side-by-side comparison, an author-supplied svg, or a recap — and resumes
on the same page once it ends, the same boundary mechanism a multi-actor `demo.turn()` already
uses to hand the browser between two windows. Nothing about the recording's determinism or
re-renderability changes: the cut-away is compiled and rendered *after* capture finishes, by
the sibling [PlainMotion](https://plainmotion.dev) CLI, from a generated one-scene project
whose bytes are seeded from the same deterministic hash every other frozen artifact is. Free
on every tier, like every authoring verb — the one licence interaction is PlainMotion's own,
and it is invisible to an author: PlainMotion's free tier freezes a closing credit card into
its own compiles, which would be wrong twice over spliced into the middle of a PlainTake
video, so that one combination is refused with the shared activation key named, rather than
shipped with someone else's credits in it.

Cues (`{atPhrase, action, target}`) time a scene's animation to a phrase in its own
narration rather than to a number, so rewording a line moves the cue with it instead of
silently drifting out of sync — the same reasoning that keeps a step's caption and its
narration one string, never two.

**Explain scenes compose with everything else this recorder already does.** A cut-away
between two segments of one actor's own footage is exactly as legal as one between two
different actors' — the offset math that reserves screen time for a transition card reserves
it for an explain scene identically, and the two can be mixed freely in one recording.
Cursor, camera, chapters and captions carry on either side of a cut-away unaffected; the
badge track and every hand-off card in a multi-actor demo still land on the right frame with
an explain scene spliced in between. `plaintake doctor` reports whether the PlainMotion CLI
is on `PATH`, without failing an installation that never needed it — the overwhelming
majority of scenarios never call `demo.explain()` — and `plaintake inspect` lists the explain
scenes a bundle carries, by id and duration. Requires the plainmotion CLI on `PATH` at record
time only; a bundle that already carries a frozen explain segment re-renders without it, the
same way it re-renders without a browser.

## 1.8.0

**A demo can speak with more than one voice.** Declare the set as `speech.voices` in the
scenario's metadata, then give an actor (`demo.actor('narrator', { voice: 'bm_george' })`)
or a single step (`demo.step({ voice: 'af_bella' })`) its own. The step's name wins over
the actor's, the actor's over `--voice`, and an override naming a voice the scenario did
not declare is refused at record time with the line to add — every declared voice is
pre-loaded before the browser opens, at roughly +250 MB resident per extra voice, so the
set is declared rather than discovered. A one-voice scenario is unchanged: no
`speech.voices`, the `--voice` default applies, and the bundle it records is the one 1.7.0
would have.

**The narration language is plumbed end to end — and the honest refusal is sharper.**
The Kokoro model ships 55 voices in nine languages, and PlainTake still refuses the 27
non-English ones, each by name and each naming its language, because the pronunciation
dictionaries those languages need are derived from eSpeak (GPL) upstream, and PlainTake
ships only licence-clean pronunciation data, which exists for English alone. What changed
is everything around that refusal: the run's one narration language is derived from its
voices and threaded through the engine, the assets and the evidence bundle, and a voice
list that spans two languages is refused at record setup with both names in the message —
one run speaks one language. When a licence-clean dictionary for another language exists,
enabling it becomes a data drop, not a code change.

**One-time note for narrated runs: the clip cache re-keys.** Cache keys now carry the
language, so previously cached English clips are never hit again and the first narrated
run after upgrading re-synthesises each line once. The engine stamp is deliberately
unchanged — nothing about how a clip is synthesised changed, only the shape of its key,
and the new clips are the audio the old ones were.

**`plaintake import <trace.zip> --output <draft.demo.ts>`.** Drafts a scenario from any
Playwright trace — one of your own suite's, or a PlainTake bundle's own `trace/`. Only
navigation, click, fill, press, select, hover and scroll become steps; every other call
the trace recorded is accounted for in the result rather than dropped silently. The draft
is a starting point, stated in its header and in every result: subtitles are placeholders
(captions are authored, never transcribed), timings are the documented defaults, and
same-origin URLs are relativised to `${baseURL}` because the trace's origin carries a
port no scenario should name. The trace records everything typed into the page, so
`fill` values are redacted where the selector looks secret-bearing (password, token, API
key…) and every result carries the standing warning to review the draft before committing
it. Only the `trace.trace` entry is parsed — `trace.network`, where cookies and request
bodies live, is never read. CLI-only, like `prune`: the MCP tool list stays at four.

**The marketing site no longer contradicts the product.** The spec table's caption row
still said hard-burned-by-default three minor versions after the soft track became the
default; that row and the page's meta description are fixed, the 1.5–1.7 features
(multi-actor, `highlight`, `--aspect`, `check`/`diff`/`prune`, the intro card, narration)
are now listed, and a test asserts the caption-default claim so the row cannot drift
again.

## 1.7.0

**Multiple actors on one recording.** `demo.actor(id, opts?)` names a participant — an
admin, a customer, whoever the demo is about — and gives it its own `BrowserContext` and
`Page`; `demo.turn(actor, { card? })` hands the browser from whoever holds it to that actor.
Capture is still exactly one active context and one active page at any instant, so turns are
strictly sequential and never simultaneous: what changes is that a scenario can now name who
is at the keyboard rather than filming every participant through one shared page. Every
hand-off draws a persistent corner badge naming the active actor, and optionally a full-frame
transition card between the two actors' footage — card-less turns still get one, synthesised
as `Now: <label>`. Both are free on every tier, on the same "recorder feature, not a render
option" footing as chapters and highlight.

A `session`-phase handoff is now reachable from **any** actor's turn, not only the actor a
scenario defaults to when none are named — the four refusal checks and the on-camera
recording behave identically whichever actor calls `.handoff()`. A single-actor scenario is
unaffected: it takes exactly the same code path it always has, `demo.actor()`/`demo.turn()`
are additive to `DemoContext`, and nothing about an existing scenario's plan, events or
render changes because this feature exists.

## 1.6.0

**MP4 chapter markers are free on every tier.** A licence no longer buys the chapter
navigation — `demo.chapter()` is unchanged, and every recording now carries its markers in
the MP4 whatever tier made it, alongside the credit card that still marks the Free Tier.
Camera zoom and credit-removal/custom-outro remain what a licence buys.

The gate was deleted rather than stubbed to `true`, following the 1.3.0 change that made
narration and the soft caption track free, so there is no `chaptersEnabled` left to quietly
turn back on: the recorder derives the marks from the `chapter` events it has always
recorded, and the licence is never consulted.

**One caveat for existing bundles: chapters freeze at record time like everything else.** A
bundle recorded on 1.5.0 or earlier has no chapter marks in its frozen plan and re-renders
without them on 1.6.0 — exactly as it did before. To add chapters to a demo you recorded
while they were paid, record it again; the events were in the timeline all along, so nothing
about the scenario needs to change.

## 1.5.0

**Vertical and square demos: `--aspect 9:16` and `--aspect 1:1`.** The finished video can now
be fitted to a vertical or square feed. The whole 16:9 picture is scaled into a box inside the
taller frame and the space left over becomes a flat dark band — nothing is cropped away — and
the captions move off the video and into that band, where they get more room than they have
ever had over the picture. What gets recorded does not change: capture is always 1920×1080
whatever you pass, and `16:9` remains the default and produces the video this tool has always
rendered, byte for byte.

The shape is chosen at render time, so a recording you already have can often be re-cut with
`plaintake render <bundle> --aspect 9:16` without recording it again — the same property that
makes switching subtitle modes a re-render rather than a re-record. "Often", because a
caption's line breaks are chosen at record time against the width of the frame they are drawn
on: a 16:9 recording whose captions run long enough is refused rather than re-cut into words
that would run off the edge of the narrower frame, and the refusal names the offending line.
`run --aspect` from the start always avoids this, because the captions are wrapped for the
right frame from the first take. A refused re-cut leaves the bundle exactly as it was,
manifest still verifying; a successful one is a round trip, and `render --aspect 16:9`
returns the video to its original shape.

**`highlight`: dim everything except the thing you are talking about.** A step can ask for
the spotlight — `demo.step({ highlight: true })`, or `highlight: { label: 'Click Settings' }`
to draw a callout beside it — and the render dims the whole frame except the step's target,
faded in and out rather than snapped. Free on every tier, and it rides the same rails as the
cursor and the camera: the target rect is measured at record time and frozen into the plan,
so it renders identically on every re-render. A highlight needs a measurable `target`, and
when the rect cannot be measured or used the run says so as a diagnostic instead of silently
rendering nothing.

**`plaintake check`: the loop's fast gate.** `check` runs the same recording and assertion
pipeline as `run` and stops before the render half — no FFmpeg probe, no encode, no manifest —
so it succeeds on a CI runner with no FFmpeg installed at all, and it is fast enough for every
pull request. Same target rules as `run` (`--base-url` or `--fixture`), same exit codes, same
assertions failing the command.

**`plaintake diff` and `plaintake prune`.** `diff <bundleA> <bundleB>` names the semantic
drift between two recordings — steps, assertions, target position and name, step timing,
caption text; no frame comparison — which is the "what changed between last month's demo and
this one" question a hash match cannot answer. `prune` deletes recorded bundles under the
working directory, selected by `--older-than`, `--keep-last` and/or `--scenario`, dry-run
unless `--yes`. It exists on the CLI only: there is no MCP tool for it, ever.

**Narration gets a speed dial and a pronunciation dictionary.** `speech.speed` (0.5–2.0×) is
a scenario-level setting for the synthesised voice — no per-step override, deliberately — and
`pronunciations` is a word-boundary substitution applied before synthesis, so a caption can
keep reading "SQL" while the voice says "sequel". Both sit in the scenario's metadata, both
are inert when absent, and neither touches a caption's text: only how it is spoken.

**The run log now says at record time what review used to catch too late.** Two silences
became notes. A camera zoom whose capped window cannot contain its target reports
`camera.cropped` — how much of which axis falls outside the window — instead of stopping at
the clamp that named the bound but not the cost. And a step whose declared target is not on
the page when the step starts reports `target.unmeasured` instead of quietly burning the
probe's timeout and losing its cursor point and camera shot; that note names the fix, which
is to navigate between steps rather than inside `run()`.

**A quickstart that PlainTake recorded itself.** The release channel now carries
`docs/quickstart-demo/` — a sixty-two-second narrated tutorial of the whole loop (install,
write the scenario, validate, run, watch the bundle), built by `make quickstart-demo` from a
committed scenario. It is honest by construction: the video the tutorial's player embeds is
the real output of the exact command it teaches, and the repository's `examples/` gains
`release-approval.demo.ts`, the flow the tutorial teaches.

## 1.4.0

**A product's branding now travels with its repository.** The outro branding (Pro) comes from a
`config.json`, and until now that meant this machine's global one at
`~/.config/plaintake/config.json` — fine while you record demos for one product, wrong the moment
there are two. `plaintake run` now looks for a `plaintake.config.json` walking up from the
working directory first: commit one at each product's repo root and every scenario recorded from
inside that repository picks up that product's branding automatically, with nothing to remember
to switch and no way for last session's branding to bleed into this one. A discovered project
config replaces the global one outright — deliberately not a merge, so a repo's committed
branding is never quietly blended with whatever happens to be on the machine that ran it.

**`--config <path>` names a file outright,** ahead of both lookups. A path that is missing or
invalid is a usage error (exit 2), not a silent fallback: naming a file and having it quietly
ignored would defeat the point. Your licence stays tied to your machine either way — a project
config picks *what* branding a run uses, never *whether* it's honoured, and the TUI's settings
screen is untouched, reading this machine's global config as it always did.

**Long chaptered videos no longer render with scrambled chapters.** A soft-subtitled render —
the default — whose chapter markers ran past roughly the first 45 seconds came out with its
chapter list damaged: a title shifted a slot, a span collapsed to nothing, and only a warning
buried in the log to say so. The fault was a timestamp overflow inside FFmpeg's MP4 muxer,
reachable only when a soft caption track shares the file with chapters; the soft pass now pins
the container's clock to the same millisecond precision the chapter data itself is written in,
and the overflow cannot occur. Unchaptered videos, hard subtitles and the base render are
untouched, and branding is still decided once at record time and frozen into the plan: a
chapterless bundle re-renders to exactly the bytes it always did, while a chaptered one
re-renders to the video it should have produced all along.

## 1.3.0

**Spoken narration is free on every tier.** `--speech on` reads every caption aloud with a
voice model that runs on your own machine, and `--speech file` speaks WAVs you supply — both
of them used to need a licence, and neither does now. Nothing about how narration works has
changed: the same local Kokoro model, the same 28 English voices, the same frozen WAV muxed
into the MP4 and hashed into the manifest. What changed is who gets it. A demo that reads its
own captions aloud is an accessibility default rather than a finish, and the captions are
already the script whatever you paid.

Practically: `plaintake install-voice` is the only thing standing between a fresh install and a
talking demo, and it always was free. `doctor` reports whether the model is there. Existing
recordings are unaffected — narration was already frozen into the render plan rather than
checked at render time, so re-rendering any bundle produces exactly the same MP4 it did before.

**The selectable caption track is free too, and is now the default.** `--subtitles soft` muxes
a real `mov_text` track into the MP4 instead of burning the words into the pixels, and it also
needed a licence until now. **Every recording you have already made can become a soft one
without recording it again** — the render plan has always frozen the FFmpeg arguments for both
caption modes, precisely so that changing your mind is a re-render. `plaintake render <bundle>
--subtitles soft` on a demo you captured last year does it, and it no longer asks about a
licence, because `render` now reads nothing but the frozen plan.

**One thing to know about the new default.** An in-container caption track is rendered by
desktop players and by essentially nothing else: not a browser, not Slack, not X, not LinkedIn,
not a GitHub embed. PlainTake records silent video, so the captions are the whole script — which
means **if you are posting or embedding the video, pass `--subtitles hard`** and get the words
burned into the pixels as before. The CLI help, the MCP tool description and the README all say
so at the point you choose. `captions.srt` and `captions.vtt` are still written on every run
either way. Soft also needs no libass of its own, so the default render now succeeds on FFmpeg
builds where burn-in fails.

If you bought a licence for the narration or the caption track, it still buys the three things
it always did — MP4 chapter markers, the camera that zooms toward each step's target, and
removing the *Made with PlainTake* credit (or replacing it with your own text and colours) —
and this release does not touch any of them. A free recording still ends with the credit card,
narrated or not, whichever caption mode it used.

**Agents get a skill they can carry.** This repository now ships
[`skills/plaintake/SKILL.md`](skills/plaintake/SKILL.md) — a self-contained agent skill in the
`SKILL.md` format Claude Code, Codex and their kin read. Copy the folder into `.claude/skills/`
(Claude Code) or `~/.agents/skills/` (Codex) and the agent knows the whole workflow: writing a
scenario, `validate` → `run` → `verify`, and the mistakes that cost a re-record. It defers to
the MCP tool descriptions and `docs/scenarios.md` for depth rather than duplicating them.

## 1.2.1

**Licences can now be activated without the interactive app: `plaintake activate
<licence-key>`.** Activation lived only in the TUI's menu, so a headless machine — or an
agent driving the CLI, which has no way through a menu — could never enable Pro. `activate`
and a read-only `licence` are ordinary commands riding the exact path the TUI uses: one call
to Gumroad, then an HMAC'd local record that everything else reads offline. A rejected key
exits 2, an unreachable or unconfigured Gumroad exits 3, and `licence` always exits 0 —
Free is a state, not a fault. Both take `--json`, and the key itself is never echoed,
because stdout may end up in a log.

**`@plaintake/scenario` is on npm.** The docs have told you to install it for editor
autocomplete while writing demos; the package exists now — MIT, self-contained, its only
dependencies `zod` and `playwright-core`, and an installed copy takes precedence over the
fallback the binary ships. 1.2.0 was briefly on npm without its built files and was
withdrawn; the binary and the package carry the same version, which is why this release is
1.2.1.

## 1.2.0

**An agent can now write a valid scenario without ever reading this repo's source.** A
malformed scenario used to fail with a raw `ZodError` issue array — the same JSON blob in
both `validate`'s output and `demo_validate`'s `problems` field — so `defineDemo` now
rewraps it as prescriptive `field: message` text, and constraints that previously lived only
in doc comments (`handoffTimeoutMs`, `intro.durationMs`, every `camera` field) now say why in
the message itself. The scenario metadata schema is exported as
`public/schema/scenario.schema.json` via `pnpm schema:export`, checked in tests so it cannot
drift from the Zod schema it is generated from. `demo_validate`'s MCP description grew a
self-contained DSL cheat-sheet — metadata shape, every `demo` method, the determinism and
`holdMs` rules — since the server runs against a customer's workspace and cannot point at
this repo's docs. `public/docs/scenarios.md` is the same reference at full depth for a human
or an agent working from the public release channel, and `public/README.md` is split into
`## For humans` and `## For agents` sections, with the four-screenshot grid replaced by one
generated GIF.

**Fixed: the closing credit card is no longer silently shortened by capture trailing.** A
Playwright screencast keeps rolling past the last recorded event until the context tears down, so
the raw WebM routinely carries trailing frames the plan never accounted for — measured, 6.7s of
them on a real session-handoff recording. The render chain anchored the credit card to the end of
the capture file instead of the end of the planned content, so everything after the content was
shifted by the trailing: the `-t` cut filled the card's window with frozen capture frames while
the counts and `verify` still read exactly right, the credit drew as faint text over a page, and
a tail longer than the card erased the card entirely. The chain now bounds the content to the
plan's own duration before the card is appended, from the plan alone — a capture that ends with
its content renders byte-for-byte as before.

## 1.1.0

**Videos can open on a title card, and it can talk.** A scenario may declare an `intro` — one or
two lines, an optional spoken hook, an optional length — and the video opens on that card instead
of on a page load still in flight. It is the counterpart to the closing credit and deliberately
not the same kind of thing: the credit is PlainTake's branding, so the Free Tier's is fixed in
code, while an opening card is the demo's own words and is **available on every tier**. Only its
colours follow a Pro `branding` config, so the two cards match. The declared length is a floor
rather than a duration — a card whose narration needs longer is lengthened rather than cutting
its own line off — and the card's frames are prepended before any overlay is drawn, so every
caption, cursor point, camera shot and chapter mark in the finished file lands past it
automatically. Both cards now fade their text, which is what the flat cut into a solid colour was
missing; the fade is on the text rather than the picture, because a video crossfade would mean
decoding the content twice for a transition nobody is watching for.

**Framing is per scenario.** `camera: { maxZoom, margin, easeMs, minDwellMs }` overrides the
defaults for pages they do not suit. `maxZoom` is the one that matters: at the 1.6x default the
tightest window is 1216x810 and 37% of the frame is discarded, which is enough to crop a results
page off at its edge — one recorded demo lost the whole left third of one. Every field is
optional and every default is the constant the camera already used, so a scenario that says
nothing is framed exactly as it was. `minDwellMs` is the exception to that pattern in spirit
rather than in effect: it guarantees settled screen time for a targeted step, is **off by
default**, and lengthens the recording when it is on, because pacing is the author's call.

**The credit card no longer disappears when a video also has an opening card.** Found by
watching two finished videos: both opened on their title card and then simply stopped on the
last frame of the recording, with no credit at all. Both cards were in the plan and both pads
were in the FFmpeg arguments. Measured cause, on FFmpeg 9.0.1: a `tpad` padding the head of a
chain leaves a later `tpad` padding the tail restarting its timestamps from the *un-shifted*
end of the content, so the credit's frames arrive with a timestamp the encoder has already
written past and all but one are dropped — 1562 frames where 1637 were asked for. The
timestamps are now renumbered between the two, which costs nothing on a stream that is already
constant-rate and is emitted only alongside the opening card, so no earlier bundle's arguments
change. Two checks that should have caught it are fixed with it: the recording path measured
the *container's* duration, which a narration track padded to full length reports correctly
while the picture is 2.5s short, and no test rendered a bundle carrying both cards.

**Two things that made videos look cut off are fixed.**

- **The cursor is no longer drawn off the bottom or right edge.** Its anchor was clamped to the
  frame, but the arrow's origin is its tip and its body extends down and right — so a click on a
  target flush with an edge put the entire pointer outside the picture. Measured on a recorded
  bundle whose "Merge & Download" click anchored at y=1080 and showed no pointer at all.
- **A chapter now holds an establishing beat before the next step starts.** Without one, a
  `demo.chapter()` landing milliseconds ahead of a targeted step left the camera less than its
  133ms ease floor, and the move became an honest snap-cut — correct behaviour for an impossible
  ease, and a visible one-frame jump in the video. The beat is the cursor's pre-roll plus the
  ease, 1.3s at the defaults, and recorded timelines are that much longer per chapter as a
  result. It has to cover the pre-roll because a step's shot is settled by the moment the
  *pointer parks* on its target, not by the moment the step starts, and for a click the pointer
  parks 500ms early so it can rest under the ripple: a beat shorter than that does not rush the
  move, it puts the next section's framing on screen *before* the mark that opens the section,
  and the chapter's wide shot becomes the thing that snap-cuts. Measured on two recorded bundles
  with four chapters between them, every one inverted.

**A recording can start on a page that is already loaded.** A scenario may declare a
`warmup` phase: it runs after pre-flight's `about:blank` hand-back and before tracing and
capture start, so what it navigates to and waits for reaches neither the trace nor the
video — and frame 0 of the recording is whatever it ended on. Without it there are only two
ways to open on the app itself, and both film the load: navigate in pre-flight, which the
hand-back then throws away by design, or make the first step's action a `page.goto`, which
puts the whole blank first paint on camera — measured on a real recording, seconds of white
between the opening card and the first screen. Warm-up is where that load belongs: the
scenario declares which page the video opens on and what "ready" means on it, the recorder
guarantees the same off-camera treatment pre-flight already gets, and a console error on the
warming page fails nothing for the same reason it fails nothing during pre-flight — the demo
has not begun. Measured on the trace this forced one honest distinction: the warmed page *is*
the recorded page, so its URL legitimately echoes through the trace as snapshot frame URLs
and as the Referer of the recorded half's own requests; what must never appear is its
navigation as a *request*, and the regression test searches for exactly that.

## 1.0.0

This is the release where a PlainTake video talks.

**Spoken narration.** Pro recordings can use `--speech on` to read every caption aloud with a
voice model that runs on your own machine — Kokoro-82M through onnxruntime, 24 kHz mono, no
network, no account and no API key. `plaintake install-voice` fetches the weights once and checks
every byte against a digest committed in the build; nothing on the recording or rendering path
opens a socket afterwards. The captions are the script, so there is no second copy of the words to
drift out of step with the screen, and each caption stays up for as long as the audio it was given
rather than for a reading-rate estimate. Word timestamps from the model also let long captions be
split at real word boundaries instead of by character weight, so captions come out better synced
with narration on than without it.

**Your own voice instead.** `narration/<stepId>.wav` beside the scenario file speaks that step in
whatever voice you recorded — a human voiceover, or a cloud voice you already pay for — without
PlainTake ever holding a credential. `--speech on` synthesises only the lines you have not voiced;
`--speech file` synthesises nothing at all and refuses a step with no file, rather than quietly
reading it in the model's voice. The clips and the mixed track are frozen into the bundle and
hashed like every other artifact, so re-rendering a narrated recording needs no voice model and
reproduces the same MP4. `--voice` chooses among 28 English voices; `doctor` reports which are
installed, and does not fail if none are.

**The voice works from the installed build.** The speech engine — the pronunciation dictionary,
the inference worker and the ONNX Runtime native library — now ships inside the tarball, beside
the binary in the same way Playwright already did, because a Node single executable cannot carry
a native library inside itself. So `plaintake install-voice` and `--speech on` work from an
installed `plaintake` rather than only from a source checkout. The build proves it rather than
assuming it: it loads the native binding from the staged install tree with the interpreter that
ships beside it, and fails if more than one platform's library is present, if a licence text is
missing, or if the tarball is about to carry a model cache.

**Click ripples land before the UI change, including on clicks that navigate** — which the
first version of this got wrong. A ripple is now timed from the step's own start rather than from
the moment the step's `run()` returned, because a `run()` that clicks a link does not return until
the page it opened has loaded: on scenarios of that shape the ring used to be drawn a second or
more after the screen had already changed, over a button that was no longer on it. Measured on the
release demo, the three ripples now lead their screen changes by 211–323 ms and fade out across
them.

**Smaller things.** `plaintake inspect` reports a bundle's narration — clip count, spoken length,
how much of it is your own audio, and which voice read the rest — and `doctor` reports whether
the voice model is installed and which voices you have, without failing when you have none. A run
that asks for `--speech on` with nothing installed and no `narration/` directory now stops before
the browser starts, instead of recording first and failing at the first line it had to speak.
Two more fixes found while building the above: the constant-frame-rate check read the container's
duration rather than the video stream's, so a narrated bundle could be refused for a difference
that was only its audio track being longer; and re-rendering a frozen bundle now creates the
output directory it writes into, which git cannot track when empty and which made the canonical
x86-64 reproducibility check fail on a fresh clone.

### Known limitations

- Narration is Pro-only in both modes, including `--speech file`: what a licence unlocks is the
  audio track in the video, not the voice model. Like the camera it is frozen while recording, so
  a silent bundle cannot be re-rendered into a narrated one. The pronunciation dictionary is US
  English only, so a non-English scenario gets captions and no voice. A narrated video is longer
  than the same scenario recorded silent, because each step waits for its line to finish.
- The bundled speech engine makes the download bigger for everyone, including people who never
  record a narrated demo, because there is one tarball per platform: measured on macOS arm64, the
  download goes from 81.3 MB to 93.9 MB and the installation from 247 MB to 292 MB. The voice
  model itself is still a separate ~93 MB download that only happens if you ask for it.
- Reproducible *rendering* of a narrated bundle is verified offline in the digest-pinned
  container, with the audio decoded back out of the MP4 and checked. Offline *synthesis* is not
  verified there — it would need a voice model and a licence inside the image — so that claim
  rests on the host runs instead.

## 0.2.0

This release adds a camera that follows declared step targets and makes human approval a
first-class part of a recorded browser flow.

**Target-driven camera.** Pro recordings can use `--camera zoom` to ease toward the same
rectangles already declared for steps and the synthetic cursor. The shot list is computed in
TypeScript and frozen into the render plan, so FFmpeg executes literal crop geometry and a
re-render stays byte-identical on the same architecture and FFmpeg build. The camera never
chooses what to show: steps without targets do not move it. Captions and closing cards remain
outside the crop, and `--camera off` preserves the full viewport.

**Smoother motion.** Camera transitions now use an 800 ms cosine ease with even-pixel
intermediate crop geometry, avoiding visible zoom rungs while keeping yuv420p-compatible
frames and exact held endpoints. Cursor safety shifts the crop without changing its zoom,
which prevents a moving pointer from causing the frame to pulse.

**Human-in-the-loop recording.** A scenario can declare `handoff: 'preflight'` to let a person
sign in or solve a challenge before recording and tracing begin, or `handoff: 'session'` when
the decision belongs in the demo itself. The visible browser is handed to the person; the
prompt returns only a completion choice, never credentials or codes. Interactive recordings
omit the Playwright trace so account fields, cookies, and request bodies are not bundled.
Clients that support MCP elicitation can relay the completion prompt in chat; other clients
are refused before Chromium starts.

**Cursor and click feedback.** The optional synthetic pointer continues to be rendered from
the frozen step targets, now framed by the same camera path. Click ripples land before the UI
change so the action reads as the cause of the transition.

**New release demo.** The public demo now walks through preparing version 0.2.0, requesting a
human review, approving it in the visible browser, and returning to the verified final state.
It is an 18-second, 1920×1080, 30 fps H.264 video with hard captions and no audio.

### Known limitations

- The camera is Pro-only, capped at 1.6×, and its shot list is frozen while recording; it
  cannot be added later to a camera-less bundle by re-rendering.
- A `session` handoff is filmed exactly as it happens. Use `preflight` for authentication that
  should appear in neither the video nor the trace.
- Interactive timing is a human input, so the capture is not reproducible; re-rendering the
  resulting frozen bundle remains reproducible under the usual toolchain constraints.

## 0.1.0

First release.

**Recording.** A committed TypeScript scenario drives a real Chromium through Playwright and
produces a narrated video. Steps, waits, masks and chapters are declared in the scenario; no
recording is done by hand and no take is edited.

**Output.** Every run produces one video, `demo.mp4`, plus `captions.srt`, `captions.vtt` and
`captions.ass` beside it. Captions are burned in with libass by default, because PlainTake
records silent video and no browser, Slack, X or LinkedIn renders an in-container caption
track — a selectable track would leave the narration invisible where demos actually get
watched. A licence can swap the burn-in for a `mov_text` track for the desktop players that do
render one.

Captions are white text on a slightly transparent dark plate, wrapped so the lines come out
roughly even rather than one full line and one stray word. The plate is there because
PlainTake mostly records light interfaces, where outlined text is hardest to read; measured on
the bundled example, the weakest part of an outlined caption had a local contrast of 25
against 170 for the plate.

**An evidence bundle, not just a file.** Each recording keeps the scenario source, the raw
capture, the Playwright trace, a semantic event timeline, the exact render plan, the toolchain
versions it was made with, and a SHA-256 manifest. `plaintake verify` re-checks every hash;
`plaintake inspect` reports what was produced.

**Reproducible rendering.** Re-rendering a frozen bundle produces byte-identical MP4s on the
same architecture and FFmpeg build, verified offline in a digest-pinned container with no
network at all.

**An MCP server.** Four tools — validate, run, render, verify — over stdio, sandboxed to a
workspace root, returning the same normalized results the CLI prints.

**A terminal UI.** `plaintake` with no arguments: record, browse recordings, settings,
licence, toolchain check. It starts only on a TTY, so an agent gets usage and a non-zero exit
rather than a prompt that blocks forever.

**Free and Pro.** Every recording, rendering and MCP feature works on the free tier, which
ends each video with a 3-second *Made with PlainTake* card. A one-time licence removes the
card, allows your own outro text and colours, and turns `demo.chapter()` calls into MP4 chapter
markers. Chapter events are recorded on **every** tier — only the markers are withheld — so
nothing is lost by recording on Free and activating later.

**Your output is yours** on both tiers, with no ownership claim and no restriction on selling
what you make.

### Known limitations

- Silent video with text subtitles. There is no audio and no text-to-speech.
- macOS arm64 and Linux x64 only. No Windows build, and no macOS Intel build.
- FFmpeg must be installed separately and **must have libass** — Homebrew's default `ffmpeg`
  does not.
- Chromium is downloaded once, separately, with `plaintake install-browser`.
- Chapter markers come only from `demo.chapter()`; they are never synthesised from step titles.
- Nothing prunes old recordings automatically. The Recordings panel deletes one when you ask.
