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
| `viewport` | `{width:1920,height:1080,deviceScaleFactor:1}` | no, defaults to that | The captured frame; every field is a literal. |
| `uiScale` | `1`, `1.5` or `2` | no, defaults to `1` | How large the page is drawn inside that frame, like browser zoom. At `2` the page lays out at 960×540 CSS pixels and is painted at 2×, so the video is still 1920×1080 and the UI in it is twice the size and sharp — what a vertical `--aspect 9:16` cut needs to stay readable. The app sees the narrower viewport, so its responsive layout may change. Coordinates you pass to `page.mouse` or a scroll delta are CSS pixels. |
| `locale` | `'en-US'` | no, defaults to `'en-US'` | The only supported locale. |
| `timezoneId` | `'UTC'` | no, defaults to `'UTC'` | The only supported timezone. |
| `colorScheme` | `'light'` | no, defaults to `'light'` | The only supported scheme. |
| `reducedMotion` | `'reduce'` | no, defaults to `'reduce'` | The only supported value — recordings must not depend on CSS motion. |
| `allowedConsoleErrors` | string array | no, defaults to `[]` | Exact console error strings this scenario tolerates. Anything else fails the run. |
| `terminal` | object | no | Record a live terminal instead of (or beside) a web app. See [Recording a terminal](#recording-a-terminal). Fields: `shell` (`'bash' \| 'zsh' \| 'sh'`, default `'bash'`), `command` (argv array, omit for an interactive shell), `cols` (40–200, default 120), `rows` (12–60, default 34), `cwd`, `env` (names copied from your environment), `secrets` (names, a subset of `env`, masked by value), `browser` (`true` adds a web actor; see below), `label` and `transition` (`'cut' \| 'card'`; both need `browser: true`). `uiScale` must be 1 (exit 2 otherwise), and `preflight`/`warmup` are refused. |
| `desktop` | object | no | Record macOS app windows. See [Recording a macOS app](#recording-a-macos-app): one app is `app`, several are `apps` ([Several Mac apps in one video](#several-mac-apps-in-one-video)). |
| `sites` | kebab-case string array | no | The websites, by id, that a tool that runs the scenario should point `--base-url` at (the first) and sign in to (all of them). PlainTake only checks and reports it (`validate`). |
| `handoff` | `'none' \| 'preflight' \| 'session'` | no, defaults to `'none'` | See [Handing the browser to a person](#handing-the-browser-to-a-person). |
| `handoffTimeoutMs` | integer, 5000–300000 | no, defaults to `120000` | How long a handoff waits for a person before giving up. 300000 (5 minutes) is a hard ceiling — past that a wait is indistinguishable from a hang. |
| `intro` | object | no | See [The opening card](#the-opening-card). |
| `camera` | object | no | See [Framing](#framing). |
| `speech` | object | no | Scenario-level narration speed. See [Narration speed](#narration-speed). |
| `pronunciations` | `Record<string, string>` | no | Text substituted into narration before synthesis, so a caption can read one thing while the voice says another. Merged on top of a small built-in default. See [Pronunciation hints](#pronunciation-hints). |

The machine-readable version of this table is
[`schema/scenario.schema.json`](../schema/scenario.schema.json).

`allowedConsoleErrors` takes the exact strings the app itself prints — never a prefix or a
pattern. Anything else in the console fails the run, and the failure is truthful about what
happened: the result carries the recording's real numbers (captions, chapters, narrated
lines) rather than zeros, the reasons list every failed assertion id and then every
unexpected console error text, and the half-finished bundle is kept beside the output as
`<output>.failed` — the diagnostic evidence survives instead of being cleaned away. The same
applies when rendering fails after a green recording: the assertions stay visible in the
result, and the bundle is left at `.failed` for inspection rather than as debris.

## The `demo` DSL

Everything below is a method on the `demo` object `run()` receives, alongside `page` (a
Playwright `Page`) and `baseURL` (the string passed to `--base-url`/`fixture`). A scenario
that declares `terminal` is also handed `term`, and its `page` is the terminal's own; with
`terminal.browser: true`, `baseURL` is the web target and the browser is an actor you name
with `demo.actor`.

| Method | Signature | Purpose |
|---|---|---|
| `chapter` | `(title: string) => Promise<void>` | Marks a chapter boundary on the timeline. Holds an establishing beat before the next step starts (not on a desktop scenario: a Mac window doesn't repaint while it waits, so the beat would only film a silent, still pause). The MP4 chapter markers derived from the events are free on every tier. |
| `say` | `({id, subtitle, title?, target?, highlight?, holdMs?, voice?}) => Promise<void>` | A narrated step that does nothing: `step` with an empty `run`. `target` frames something while the line is spoken. Actors have `say` too. |
| `step` | `({id, title, subtitle?, target?, action?, highlight?, holdMs?, run}) => Promise<void>` | The unit of narrated action. `run` performs it; `subtitle` is both the on-screen caption and the spoken line — you may write a `[pause]` in it to break a long line (see [Narration breaks](#narration-breaks)); `target` (a `Locator`) is recorded for the cursor/camera/highlight to read, never used to act; `action` (`'click' \| 'type' \| 'point'`) tells the cursor what to draw; `highlight` (`boolean \| { label? }`) dims everything but `target` — see [Highlighting](#highlighting). |
| `assert` | `({id, title, run}) => Promise<void>` | A checked expectation. A rejection fails the run; it does not stop the recording. |
| `mask` | `({id, selector, reason?}) => Promise<void>` | Hides a CSS selector's contents in every frame it could appear in, from the moment it is registered — register it *before* the element exists so nothing is ever visible. A selector, not a `Locator`, is what makes that possible. |
| `waitFor` | `({id, title, until, timeoutMs?}) => Promise<void>` | Waits on a condition that prompts nobody — a push notification, an emailed link, a background job. Needs no window and no terminal; works headless and in CI. |
| `handoff` | `({id, title, detail?, until?, timeoutMs?, mask?}) => Promise<void>` | Hands the real browser window to a person. Requires `handoff` in the scenario's metadata; only available in `run()` when `handoff: 'session'`, and in `preflight()` always. See below. |
| `pause` | `(ms: number) => Promise<void>` | An explicit, recorded pause. Prefer this over `page.waitForTimeout`: it races the run's abort signal and appears on the timeline. |
| `note` | `(message: string) => void` | Says something the author should read about a run that still passes — a best-effort cleanup that failed, a fallback taken. Nothing reaches the video; the message becomes a `scenario.note` diagnostic in the run's or check's result. Never fails the run. |
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
  recording begins. Same restricted `demo` as `preflight`, for the same reason, plus `note`
  (reported with the run's own notes). Use it to navigate to the page the video should open on,
  when starting cold would film a blank load. On a Mac app scenario it also gets the app handles
  (see [Recording a macOS app](#recording-a-macos-app)).

## Recording a terminal

A scenario with a `terminal` block records a live PTY drawn by xterm.js, filmed like any other
page, so captions, narration, cursor, camera, highlights and chapters work unchanged. Without
`browser` it takes neither `--base-url` nor `--fixture` (exit 2). `run()` is handed `term`:

| Verb | Purpose |
|---|---|
| `term.run(line, meta?)` | Types the line and presses Enter. |
| `term.type(text, meta?)` | Types at a fixed per-character pace. |
| `term.press(keys, meta?)` | Playwright key names, space-separated for a chord: `'Enter'`, `'Ctrl+B c'`. |
| `term.waitForText(pattern, {timeoutMs?, id?, title?})` | Waits for text on the screen; `demo.waitFor`'s bounds. Times out as exit 4. A string matches literally, a `RegExp` is a regex. |
| `term.getByText(pattern)` / `term.cells({row, col, width, height})` | Locators over the screen, to use as a step's `target`. |
| `term.screenText()` | The visible screen, one line per row. |
| `term.assert({id, title, run})` | `demo.assert` against the terminal. |
| `term.actor` | Only with `browser: true`: the handle for `demo.turn(term.actor)`. |

The verbs that type (`run`, `type`, `press`) take the usual step meta plus `expectExit: true`
when the process ending is the point. A process that exits otherwise fails the run (exit 4).
Secrets named in `secrets` are masked by value and are never typed (exit 2 if you try).
[Patterns](patterns.md#a-live-terminal-declare-terminal) lists what bites.

### Terminal and browser together

`terminal: { ..., browser: true }` makes the terminal the default actor `term` (labelled
`terminal.label`, default `Terminal`) and lets you name a web actor with `demo.actor('web')`.
Record with exactly one of `--base-url` or `--fixture`: `baseURL` in `run()` is the web
target. `validate` needs no target and says so.

| Call | Meaning |
|---|---|
| `demo.turn(actor)` | The scenario's default switch: a **hard cut**, or with `transition: 'card'` the synthesised "Now: <label>" card. |
| `demo.turn(actor, { card: { lines, narration?, durationMs? } })` | A full-frame card for this turn. |
| `demo.turn(actor, { card: false })` | A hard cut for this turn, whatever the default. |

`card: true` or a non-object is refused (exit 2). `term.run`, `type`, `press` and
`waitForText` are refused (exit 2) while the web actor holds the turn. A cut makes the cursor
jump rather than glide. The Playwright trace covers only the terminal, and `terminal.secrets`
never masks web pixels. `preflight` and `warmup` are refused (exit 2) for a terminal scenario,
`browser` or not: with `browser` they would run in the terminal's page and context, so their
sign-in would never reach the web actor. `uiScale` other than 1 is refused as well.

## Recording a macOS app

A scenario with a `desktop` block records one macOS app's window: a helper resizes it to fill
the frame, streams it into a page PlainTake serves itself, and Chromium films that page, so
captions, narration, cursor, camera, highlights and chapters work unchanged. It takes neither
`--base-url` nor `--fixture` (exit 2), runs on macOS 13 or later only, and `run()` is handed
`app`:

```ts
desktop: { app: 'com.microsoft.Excel' }            // a bundle id, or a .app path relative to this file
// optional: args: ['--safe'], document: 'book.xlsx', scratchCopy: true, launch: 'fresh' | 'attach',
//           cleanup: { downloads: '^Untitled( \\d+)?\\.pdf$' }
```

`scratchCopy: true` opens a temporary copy of `document` instead of the file itself and deletes
the copy after the run, so an app that autosaves (Preview, Excel) never changes the original.
`cleanup.downloads` is a regular expression matched against the names of files in `~/Downloads`
once the run ends, whatever its outcome: a match created during the run (an export's
`Untitled.pdf`) is deleted and logged in `logs/recorder.log`; a file that was there before is
never touched.

With no `launch`, PlainTake uses the app if it is open and starts it if not (and quits it at the end
only if it started it). `launch: 'fresh'` refuses an app that is already open rather than quit it;
`launch: 'attach'` refuses one that is not.

| Verb | Purpose |
|---|---|
| `app.click({ role, name } \| { x, y } \| { x, y, width, height }, meta?)` | Presses the element (AXPress when it offers it, else a pointer click at its centre), or clicks the pointer at a window point, for what Accessibility does not expose (a spreadsheet's cells, the arrow beside a cell). A rect (an `app.grid` cell) is clicked at its centre and its step targets the rect. A point outside the window is refused before the step starts (exit 2). |
| `app.doubleClick({ role, name } \| { x, y }, meta?)` | A pointer double-click at the element or the point. |
| `app.choose({ role, name }, item, meta?)` | Picks `item` from a pop-up button or combo box, in one step: the menu opens once the step has started (the caption and voice cover the opening), the cursor goes to the item, and the item is pressed. A control or item not found is exit 4, and the error lists the pop-up's items. |
| `app.type(text, meta?)` | Types into whatever has keyboard focus, at a fixed pace. |
| `app.press(keys, meta?)` | Key chords, space-separated: `'Enter'`, `'Cmd+1'`, `'Cmd+a Delete'`. A single character is case-sensitive, as in Playwright: `'Cmd+a'` selects all, `'Cmd+A'` is Cmd+Shift+A. A character names the key that types it on the Mac's current keyboard layout, so `'Cmd+z'` is undo on QWERTY, AZERTY and Dvorak alike. Named keys (any case): `Enter`/`Return`, `Tab`, `Space`, `Backspace`, `Delete` (forward delete), `Escape`/`Esc`, `ArrowLeft`/`ArrowRight`/`ArrowUp`/`ArrowDown` (or `Left`/`Right`/`Up`/`Down`), `Home`, `End`, `PageUp`, `PageDown`, `F1`–`F12`; modifiers `Cmd`/`Command`/`Meta`, `Ctrl`/`Control`, `Alt`/`Opt`/`Option`, `Shift`. Any other key is refused before its step starts (exit 2). |
| `app.menu('Format > Cells…', meta?)` | Opens each menu from the menu bar, then presses the last item, all inside the step: the caption and voice cover the opening, and the video shows the menu open. The menu bar itself is above the frame; the drop-down's top edge rides the frame's top edge. An item not found lists that menu's items, and closes the menus it opened. |
| `app.drag(from, to, opts?)` | Presses on `from`, moves the pointer to `to` and releases there: moving a text box, dropping a file on a folder, reordering a row. `from` is an element `{ role, name }` or a window point `{ x, y }`; `to` is an element (its centre), an offset `{ dx, dy }` from the grab point, or a window point `{ x, y }`. Window points are the window's own points, 1920×1080 at `uiScale` 1 (960×540 at 2), from its top-left. `opts` is a step's meta plus `grab: { x, y }` (where to press on an element, from its top-left; default its centre) and `durationMs` (200–3000, default 600). A drop outside the window, a bad `durationMs` or `grab`, or `grab` with a point `from` is refused before the step starts (exit 2); an element not found is exit 4. The rendered cursor presses, travels with the drag and ripples again on the drop. |
| `app.waitForText(pattern, {timeoutMs?, id?, title?})` / `app.waitForWindow(title, …)` | Waits on the text of the app's windows, dialogs and alerts included (through Accessibility), or on a window title; `demo.waitFor`'s bounds, exit 4 on timeout. |
| `app.locate({ role, name })` | A locator over the element's rect right now, to use as a step's `target`. Not found is exit 4. |
| `app.text()` | The visible text of the app's windows, front to back, one element per line. |
| `app.assert({id, title, run})` | `demo.assert` against the app. |
| `app.mask({ id, target: { role, name }, reason? })` | Hides the element for the rest of the video (see below). |
| `app.rect({ x, y, width, height })` | A locator over a window rect, as a step's `target` (`demo.say({ target })`), for something Accessibility does not expose. |
| `app.point({ x, y, width, height }, meta?)` | A step whose cursor goes to the rect's centre and ripples as a click, sending the app nothing: pointing at a cell or a drawn shape while the line names it. |
| `app.grid({ x, y, colWidth, rowHeight })` | `(row, col) => rect` over equal cells, 0-based from the top-left cell: `const cell = app.grid({ x: 52, y: 180, colWidth: 96, rowHeight: 24 }); await app.click(cell(2, 1))`. Nothing is read from the app. |
| `app.closeAndDiscard({ id?, title? })` | The last step, unnarrated and best-effort: File > Close Window (or File > Close), then Don't Save, Delete or Discard if the app asks. A failure becomes a `demo.note`, never a failed run. After the last narrated line, so it is never filmed (see below). |

**See the app before writing against it.** `plaintake inspect-app <scenario.ts>` opens the
scenario's app as a recording would and lists each window front to back with its elements (short
role, the name `app.click` matches, value, rect in window points) and every menu path as `app.menu`
takes it (the Apple menu is left out: its Recent Items names your files), and writes `still.jpg`: the window at recording size with a grid every 100 points, one
pixel per window point. `--action 'menu:Data > Validation...'` opens a dialog first; `--app <id>`
picks one of `desktop.apps`; `--keep-open` leaves the app running. For a website scenario, pass
`--base-url` or `--fixture` and get Playwright's accessibility snapshot instead.

`role` is an Accessibility role (`'AXButton'`, `'AXCheckBox'`) or a short form: `button`,
`checkbox`, `textfield`, `text`, `menuitem`, `menubutton`, `popup`, `radio`, `combobox`, `link`,
`image`. Names match across curly and straight quotes (`Don't Save` finds `Don’t Save`), `…` and
`...`, no-break spaces and invisible marks; otherwise exactly. An element not found fails with the
closest names of that role in the app's windows, and says when the name is in another window or
under another role.
`name` matches the element's title, then its description (Office splits names across the two),
then a static text's words, then the label beside it that names it (Excel's dialog controls are
named only that way: the pop-up under "Allow:" is `{ role: 'popup', name: 'Allow:' }`). Step ids are `app.1`, `app.2`, … unless you give one.
Electron apps (Slack, VS Code) work too: the helper asks them to expose their
page to Accessibility, so a button is named by its text, as in `app.click({ role: 'button', name:
'Board' })`.

**Dialogs, alerts and pop-ups.** An element is looked for in the app's windows front to back, so
a dialog, an alert or a panel open over the main window answers first, and a sheet is part of its
window: `app.click({ role: 'button', name: 'OK' })` presses the dialog's OK. A window the app opens
outside the frame (Excel puts some alerts at the screen's right edge) is moved to the middle of the
main window as it appears, so the video shows it; `logs/recorder.log` says where it went. Window points
are measured from the main window's top-left, dialogs included. A pop-up button's choice is one
step:

```ts
await app.menu('Data > Validation...', { title: 'Data Validation', holdMs: 1500 });
await app.choose({ role: 'popup', name: 'Allow:' }, 'List', { subtitle: 'Under Allow, pick List.' });
await app.click({ role: 'button', name: 'OK' }, { subtitle: 'Then OK.' });
await app.waitForText("doesn't match", { timeoutMs: 5000 });
```

A window drawn by another process (a sandboxed app's Open panel) can be neither driven nor filmed.

**Dragging something drawn on a canvas.** Some apps draw an object with no Accessibility element of
its own: Preview's text and shape annotations are drawn on the document and invisible to `app.locate`.
Drag those from a window point. A new Preview text box appears at the centre of the document, so on a
document that fills the window:

```ts
await app.menu('Tools > Annotate > Text', { title: 'Add a text box', holdMs: 1000 });
await app.drag({ x: 960, y: 595 }, { dx: 300, dy: 200 }, { title: 'Move it', subtitle: 'Drag it onto the signature line.' });
```

Give a newly made object a moment before dragging it (the `holdMs` above): Preview ignored a drag that
began a few milliseconds after the box appeared, and took the same drag a second later. Rehearse to
find the point, since it depends on the document's size in the window.

Three things to know before you record:

- **The Mac is in use while it records.** The app is brought to the front, the window is resized
  to 1920×1080 points (960×540 at `uiScale: 2`, which a 13"–15" MacBook display needs: a
  display the window does not fit is refused with the scales that would), and clicks and keys are
  real input. Do not touch the keyboard or mouse until the run ends.
- **Some controls ignore synthetic input.** Office's ribbon drop-down buttons do; drive those
  through the menu bar (`app.menu`) or a shortcut (`app.press`) instead. Check boxes, buttons,
  menus and dialogs behave.
- **The first run asks for two permissions** — Screen Recording and Accessibility — for the app
  that launched `plaintake` (your terminal, or the app that runs it), in System Settings → Privacy &
  Security. `plaintake doctor` reports both as a state.

**A window that keeps its own size.** Some windows cannot be resized — Pages' first-launch welcome window is
910×609 points whatever is asked of it. Such a window is filmed in the middle of the frame at its
own size, unstretched, with black around it, and with `--camera zoom` the camera frames that window
whole while it is up (up to 2×, so it fills a vertical cut), instead of resting on the full frame.
It must fit the frame at your `uiScale` (the chooser fits at `1.5`, 1280×720 points, but not at
`2`); a larger one is refused before the run starts (exit 2), naming a smaller scale to try. When the
filmed window closes and the app opens another in its place (Create in the chooser opens the new
document), that window is filmed instead: sized to the frame like the first, with one line in
`logs/recorder.log`, and the camera goes back to the full frame. Window points (`app.click({ x, y })`,
`app.drag`) are always the frame's, from its top-left, so a point in a centred chooser is its
position in the frame, not in the chooser.

**Masks.** `app.mask` paints a solid block over the element inside the helper, before a frame
is encoded, so its pixels are in no frame, trace or bundle; `demo.mask` (a CSS selector) is refused
on a desktop scenario. The element must be on screen when you call it, in the app's main window (an
element in a separate panel, popover or dialog is not found, unlike every other verb's). The block follows the element as it moves,
with a small margin; something that moves very fast — a quick scroll, a sheet sliding in — can show
at its edge for a frame, so watch the video back before publishing. If the element closes nothing is painted, and when it comes back it is found again before
the frames that follow any `app` verb, or within a quarter of a second otherwise. When the helper
cannot tell where a masked element is, it sends no frame at all — the video holds the last masked
one, then catches up as soon as it knows — and if that lasts too long (2 seconds with nothing left to
try, 10 in all) the run fails rather than leave a frozen stretch unexplained.

**Handing the app to a person.** `handoff: 'session'` works as it does for a browser, except the
person works in the app's own window (PlainTake brings it to the front; no browser window opens),
and the prompt names the app. The video is rolling, so mask anything private with `app.mask`
before the handoff; a handoff's own `mask` option is a CSS selector and is refused here.

**Set the app up in `warmup`, which is never filmed.** `warmup({ app, apps, demo })` runs once the
apps are launched with their documents open and before capture starts, so nothing it does reaches
the video, the captions, the narration or the step list. Answer the app's start-up dialogs there
(a recovered-workbook prompt, a converter question, a welcome gallery), dismiss a message bar, set
the zoom with `app.menu`, open the tab the video starts on. `app` and `apps` are the same handles
`run` gets, and their verbs act on the app the same way, but record no step: an `id` is allowed and
ignored, a `subtitle` is refused, and `app.mask`, `app.point`, `app.assert` and `app.actor` are
refused (exit 2), since each is about the video. `demo` has `waitFor` and `note`. With several apps,
a verb first brings its own app to the front, and the first app is brought back to the front when
warmup returns, so `run` starts on the app it films with whatever window warmup left; `run`'s
`demo.turn` works as before.

```ts
async warmup({ app: excel, apps }) {
  const word = apps!['word']!;
  if ((await excel.text()).includes('recovered')) await excel.click({ role: 'button', name: 'No' });
  await word.menu('View > Zoom…');
  await word.click({ role: 'button', name: 'OK' });
  await word.click({ role: 'tab', name: 'Mailings' });
},
```

**What runs after the last line is not filmed.** On a Mac app scenario, the steps that start after
the last narrated step has finished (its line and its `holdMs`) still run, but the video ends there:
closing documents, `app.closeAndDiscard()`, a Delete on a keep-or-delete alert, a `demo.turn` to
another app to close it. Their events are taken out of the bundle too, and `logs/recorder.log` says
`tail: cut …ms after the last narrated line; ran unfilmed: <ids>`. With several apps, the segments
those turns opened are dropped, unless that would leave only the first one (then nothing is cut, and
the log says so). An `explain` scene after the last line keeps the whole tail; a run that fails is
never cut. Web and terminal scenarios are unchanged.

Targets are authored against one `uiScale`: a responsive app re-lays out its controls at 960
points wide. `preflight` and `handoff: 'preflight'` are refused on a desktop scenario (exit 2): set
up the app in `warmup` instead.
Desktop recordings are not part of `make reproduce`: the app's pixels depend on the machine, but
two renders of one bundle are still byte-identical.

**Defaults from the config.** A `plaintake.config.json` may hold `scenarioDefaults`, which every
scenario it runs gets under its own fields: `uiScale` when the scenario names none, and launch
arguments per app (`appArgs`, keyed by the bundle id or `.app` path the scenario names), put before
the app's own `args`, each flag only when the scenario does not pass that flag itself. `run`, `check`
and `validate` read it (`--config` names the file); `validate` reports which took effect.

```json
{ "scenarioDefaults": { "uiScale": 1.5, "appArgs": { "com.apple.Preview": ["-ApplePersistenceIgnoreState", "YES"] } } }
```

### A Mac app and a browser together

`desktop: { ..., browser: true }` works as [`terminal.browser`](#terminal-and-browser-together)
does: the app becomes the default actor `app` (labelled `desktop.label`, default the `.app` name, or
the bundle id, so give a bundle-id app a `label`), and you name a web actor with
`demo.actor('web')`. Record with exactly one of `--base-url` or `--fixture`; `baseURL` in `run()` is
the web target. `app.actor` is the handle to turn back to:

```ts
desktop: { app: 'com.apple.TextEdit', label: 'TextEdit', browser: true },

async run({ demo, app, baseURL }) {
  await app.type('Plans for Friday', { title: 'Type', subtitle: 'Write it down.' });
  const web = await demo.actor('web', { label: 'Web' });
  await web.page.goto(baseURL);                     // preloaded, so the cut lands on a drawn page
  await demo.turn(web);                             // a hard cut, unless transition: 'card'
  await web.click(web.page.getByRole('link', { name: 'Notes' }), { title: 'Open notes' });
  await demo.turn(app.actor, { card: { lines: ['Back to TextEdit'] } });
}
```

The turn calls are the terminal's (`card`, `card: false`, `transition: 'card'`); a turn is a hard
cut unless you ask for a card, so `{ card: false }` is never needed. `app` verbs are
refused (exit 2) while the web actor holds the turn. `--storage-state` reaches the web actor, so it
starts signed in. The web actor's page is not traced, and the actor badge (white on a dark plate) draws over the
window's top-left corner; on a 9:16 or 1:1 video it sits at the top-left of the picture, so the
social and follow crops never cut it off. `demo.mask` stays refused: hide a web secret with the web actor's own
`web.mask({ id, selector })`, and an app one with `app.mask`. A session handoff is refused with
`browser` (exit 2), since Chromium stays headless on a desktop run and a person could not act in
the web half.

### Several Mac apps in one video

`desktop.apps` records two or more apps, each in its own window, taking turns like actors. Every
app has an `id` (its actor and the prefix of its step ids, `excel.1`), a `label` for its badge and
cards, and its own `args`, `document` and `launch`; those four are refused at the top level beside
`apps`. The first app is the default actor and is also handed to `run()` as `app`; `apps` holds
every app by id:

```ts
desktop: {
  apps: [
    { id: 'excel', app: 'com.microsoft.Excel', label: 'Excel', document: 'sales.xlsx' },
    { id: 'word', app: 'com.microsoft.Word', label: 'Word' },
  ],
},

async run({ demo, app, apps }) {
  await app.press('Cmd+c', { title: 'Copy', subtitle: 'Copy the totals.' });
  await demo.turn(apps.word.actor);                 // a hard cut, unless transition: 'card'
  await apps.word.press('Cmd+v', { title: 'Paste', subtitle: 'Paste them into the letter.' });
  await demo.turn(app.actor, { card: { lines: ['Back to Excel'] } });
}
```

Each app is started in order before the video starts (and quit at the end only if PlainTake
started it), and a turn brings that app's window to the front before its first step, so its
clicks and keys reach it. An app's verbs are refused (exit 2) while another actor holds the turn.
Turns between apps are hard cuts unless `transition: 'card'` (a card films a still, silent stretch; prefer the cut). Add `browser: true` to take turns
with a web actor as well, as above; without it, `demo.actor` accepts only the apps' ids. Every
window is resized to the same frame and filmed on its own, so the Mac's display must fit one
window, not all of them.

## Rules that matter in practice

- **`id` values are authored and stable.** Never generate them.
- **Set `holdMs`.** Narration is timed at roughly 20 characters/second with a 1200ms minimum,
  so a step that finishes in 40ms still needs its caption on screen for over a second. Without
  holds the video becomes a frozen frame with captions scrolling over it.
- **A step's `target` must already be on the page when the step begins.** PlainTake measures it
  before the step starts and before its narration does, giving up after 2s. A target the step's
  own `run` creates (an overlay, a panel, the next page) costs those 2s as a silent, frozen
  stretch, then goes unmeasured: no cursor point and no camera shot. Both `run` and `check`
  report it as `target.unmeasured`. Draw overlays in `warmup` or an earlier step, and navigate
  between steps, not inside a targeted step's `run`.
- **Masks take a CSS selector, not a `Locator`**, so they can be registered before the element
  exists — that is what makes "masked before the secret is ever visible" true.
- **No `Date.now()`, no `Math.random()`, no external network.** A scenario should be
  deterministic: the same scenario run twice should produce the same ordered steps, captions
  and assertions. Unlike the two rules below, this one is a convention `validate` does not
  check — a scenario is loaded and executed as a plain Node module, and nothing inspects its
  source for these calls or fences its network access at record time. Follow it anyway: it is
  what makes a re-record match the last one, and what makes an assertion mean the same thing
  against the same app tomorrow that it means today.
- **Erasable TypeScript only** — no `enum`, `namespace`, parameter properties, or decorators.
  Node's type-stripping loader cannot erase them, and `validate` rejects them by name before a
  browser opens.
- **No machine-specific absolute paths** — `/Users/you/fixtures/data.json` works on the
  machine it was written on and nowhere else. `validate` refuses them by line number and names
  the fix: load fixtures relative to the scenario with `import.meta.dirname`.

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

What moves the camera, beyond each targeted step:

- **A step with no target holds the frame**, but the move to the *next* target starts early: up
  to `easeMs` plus about 500ms before that step begins, so it can land in the tail of a hold. To
  linger on the current view, keep the step after the hold near it.
- **`demo.chapter()` zooms out to the whole frame.** On a vertical cut (`--reframe follow`,
  `--for tiktok`), where the whole width does not fit, it zooms out in place over the content
  the camera was on rather than sliding to the middle of the screen.
- **An `app.drag` from a bare `{ x, y }` point** (a click off a text box, a grab on a canvas)
  only moves the camera when the point is not already well inside what is on screen. A point
  has no element to frame, so zooming in on one would just centre on empty space.

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

Dims everything on screen except `target`'s rect *and a 16px margin around it*, with an
optional callout label beside it. Free on every tier — unlike the camera, there is no
licence gate and nothing to turn on at the CLI or in `demo_run`; a step's own `highlight`
field is the only switch.

- `highlight: true` — spotlights `target` with no label.
- `highlight: { label: 'text' }` — spotlights `target` and draws `text` beside it.
- Absent (the default) — no highlight, exactly what every scenario written before this field
  existed already renders.

`highlight` needs a measurable `target`: if the step's bounding-box measurement fails —
best-effort, and rare — the run still completes, but the highlight is reported as a
diagnostic rather than silently skipped, so the gap is visible in `demo_run`'s diagnostics
rather than only in the missing pixels.

**The hole is cut around the target, not flush to it.** A spotlight that ends exactly at an
element's own edge reads as a crop mark, not a light shone on it — so the measured rect is
grown by 16px on every side before the frame is dimmed, the same "breathing room" a
product tour's own highlighted element gets in tools like Driver.js or Intro.js. The margin
is fixed, not configurable, and a target sitting flush against the frame's edge is clamped
back onto it rather than pushed off-screen — you never see a hole that reaches past the
picture.

**When the spotlight is on screen depends on what the step does.** A click's window
*brackets the press*: the dim starts fading in while the cursor is still parking on the
target (500 ms before the click fires), is at full strength through the press and the start
of the click ripple, and releases 200 ms after the press — so the viewer always sees the
spotlight settle on the button *before* it is clicked, never a dim overlay arriving on the
screen the click just navigated to. A continuous action (`type`, `point`, or no `action`)
keeps its window over the whole step, because nothing changes screen at its opening
instant. Like every derived track, the timing is frozen into the bundle at record time; a
bundle recorded before this bracketing exists re-renders exactly as it always did.

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
scene, rendered by PlainTake itself after capture finishes — nothing else to install. The
cut-away is a boundary on the timeline, the same mechanism a multi-actor `demo.turn()`
uses to hand the browser between two windows: the screencast pauses, the scene plays, and
recording resumes on the same page with nothing excised. Free on every tier, like every
authoring verb.

An explain scene is always narrated — its narration is its clock — so it needs the voice
model installed (`plaintake install-voice`; `plaintake doctor` reports whether it is) even
when the rest of the recording is silent. Without it, the run stops at the first cut-away,
before the capture is split. With `--speech off` the scene is still timed by its narration
and captioned, but the voice is not laid into the video.

- **`id`** — becomes the directory the frozen scene lives in (`explain/<id>/`) and the
  generated scene's own id, so it follows the scene id rule: lower-case alphanumeric and
  hyphens, starting alphanumeric.
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
  | `comparison` | `left`/`right` (`{heading,items}`), `title?` | Two columns, side by side. |
  | `diagram` | `src` (an svg path, relative to the scenario file), `title?`, `caption?`, `regions?` | An author-supplied svg, imported as-drawn. |
  | `recap` | `items` (strings), `title?` | A closing bullet list. |

  Geometry is deliberately absent from every one of these — where a pixel lands is the
  scene layout's decision. An author says what
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
recording is the dial anyone has asked for. Pitch and general SSML are out of scope — the one
in-line control is the `[pause]` break marker (see **Narration breaks** below), a single,
bounded place-marker with no length and no other markup.

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
- A small built-in default — currently just `{ id: 'I D' }` — is merged in underneath whatever a
  scenario declares, so every recording gets it without asking. It exists only for words the
  engine speaks as a plainly different, wrong word (`id` otherwise comes out as the English word
  "id"); it is not a place for stylistic choices like `SQL` → `sequel`, which stay scenario-opt-in
  above. A scenario's own key always wins: declaring `pronunciations: { id: 'id' }` overrides the
  default back to the literal reading, and declaring any other keys keeps the default alongside
  them.

## Narration breaks

```ts
subtitle: 'Applying a set stacks its grants [pause] alongside anything else granting the flag.',
```

Write `[pause]` inside a `subtitle` (or an `intro.narration`) to force the voice to break there.
It exists for one specific problem: on a long line, Kokoro occasionally drops a ~300–500 ms
near-silence at the *wrong* word — a quirk of the model's own timing, not of your punctuation.
PlainTake already tries to repair that automatically and warns with `speech.pause` when it
can't (see below); `[pause]` is the manual override for when it can't. Each side of the marker
is synthesised on its own, so the model can no longer stall across it, and the breath lands
exactly where you put it.

- **It is stripped from the caption.** `[pause]` is never shown on screen and never spoken — the
  caption reads `…its grants alongside…`, the same "affects speech, not caption" rule the
  pronunciation dictionary follows. A marker adjacent to a word (`grants[pause]alongside`)
  implies a word boundary, so it also reads as a space in the caption.
- **Place only, no length.** There is no `[pause 400]` — a break marks *where* the line breaks,
  not for how long; the pause is the same natural breath PlainTake keeps at an auto-split
  sentence. A marker carrying an argument, or an unmatched `[pause`, is refused at record time
  with the step named.
- **Each side still auto-repairs.** A segment that is itself long and stalls goes through the
  same whole-line → nudge → split ladder, so `[pause]` composes with the automatic handling
  rather than replacing it.
- **Not in explain scenes.** `demo.explain` narration is compiled as one line by the explain
  scene's own timing, which has no split machinery; a `[pause]` there is stripped (never
  shown, never spoken) but buys no break. Anchor an explain scene's timing with its `atPhrase` cues instead.

Reach for it sparingly — a line short enough not to stall never needs one, and rewording is
often clearer than marking. It is the escape hatch for the long line the model mistimes.

## Warming the speech cache

```sh
plaintake warm ./out/my-demo       # then re-record into the same place
plaintake run  my-demo.demo.ts --output ./out/my-demo --base-url http://localhost:3000 --speech on
```

Synthesis runs *while the browser is being recorded* — each line is spoken during the step that
narrates it, so a clip that has to be synthesised then is time the camera is filming. Every line is
cached (`~/.cache/plaintake/speech`), so this only bites when the cache is **cold**: a fresh
machine, CI, or the first run after PlainTake changes how a line sounds (a new voice model, or the
internal speech-engine version). A cold recording pads the video with those synthesis stalls — the
gaps *between* spoken lines stretch, and a long demo can come out minutes longer than the same
scenario recorded against a warm cache, with the narration itself unchanged.

`plaintake warm <bundleDir>` fixes that ahead of time. Every recording made with `--speech on`
writes a `speech/narration.index.json` into its bundle — the lines it synthesised, with their
`[pause]` splits and any non-default voice. `warm` reads that index and re-synthesises each line
into the shared cache **with no browser and no target app**, so the next recording finds every clip
already made and its length depends on the demo, not on the machine.

- **After a version bump or on a new machine:** `warm` the previous bundle, then re-record. The text
  has not changed, so warming fills the exact cache entries the re-record will look for.
- **A brand-new scenario** has no prior bundle: run `plaintake check` once (it records and asserts
  without rendering — a cold synthesis there pads nothing you keep), then `warm` that bundle, then
  `run`.
- **It needs the voice model installed**, because it synthesises — unlike `verify` or `render`. A
  bundle recorded without `--speech on` has no index and nothing to warm.
- **A cold recording says so.** When the first synthesised lines of a run all miss the cache,
  the result carries a `speech.cold` diagnostic naming `plaintake warm` as the fix — coldness
  is reported, not left for you to infer from a slow, loose-paced video.
- **The bundle is checked before it is published.** A run whose frozen speech track references
  a clip file the bundle does not contain, or a synthesised line missing from the narration
  index, refuses rather than publishing a video with a hole in its narration. That recording
  is re-made, not shipped.

Warming is optional: a normal `run` still works cold, just slower and with a looser-paced video the
first time. It is CLI-only — there is no MCP tool for it — because it is a local performance step,
not a recording operation.

## Re-running: archived, not clobbered

A `run` (or `check`) into an existing `--output` moves the previous bundle aside to
`<output>.<timestamp>` before recording starts, rather than deleting it — the old recording
survives every re-run by default, so a worse take can never erase a better one. The result
reports where it went (`archived <path>` in the CLI output; `archivedPath` in `--json`).

Archives are real bundles — they carry `manifest.json`, so `plaintake verify` and `inspect`
work on them, and `plaintake prune` finds and cleans them through the same discovery as any
other bundle rather than letting them pile up for ever.

`run`'s `--no-archive` asks for the old behaviour back — delete the previous bundle on
re-run — for scratch output directories where archives would only be noise.

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
page with no browser. The recipes for the *application* side of a recording — seeding a
database, polling a mail server, switching personas — are in [`patterns.md`](patterns.md):
nothing there is enforceable by `validate`, which is exactly why it is a separate page.
