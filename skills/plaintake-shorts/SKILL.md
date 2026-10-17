---
name: plaintake-shorts
description: Use when writing, rehearsing, recording, revising or checking a short through the PlainTake Studio MCP tools (list_shorts, inspect_app, write_scenario, rehearse, request_recording, get_job, step_frames, revise_short, edit_sheet), for a website or a Mac app (Pages, Numbers, Excel, Word, Preview, Canva, Google Docs). Holds the working loop and the lessons from 12+ recorded shorts. Use alongside the scenario API reference that get_product_context returns.
---

# Making PlainTake shorts

## Overview
A short is a `*.demo.ts` scenario plus an upload sheet. Studio rehearses it, records it, checks it
and hands it to a person for review. Every take that fails or comes out wrong costs an attempt, and
the person's patience ("you took too many steps to record a simple video"). The goal is **one
rehearsal and one take**. You get there by learning what the app does *before* writing, not by
trying things in rehearsals.

`get_product_context` gives you the API (`plaintakeSkill`), `rules.kind`, `rules.format`,
`desktopGuide` and the product's RULES. Follow those. This skill is the experience on top of them.

Per-app quirks:
- Mac apps: `references/mac-apps.md`. Read the section for your app before writing.
- Web apps: `references/web-apps.md`.
- Sample files and asset scripts: `references/asset-scripts.md`.

## The loop

1. **Find where it stands.**
   - `list_shorts` (with status) and the short's note.
   - For a revision, read the reviewer's note and the current scenario.
   - Note every step id that exists. Reviewers refer to them, and you must keep them.
2. **Context.**
   - `get_product_context`.
   - The closest existing scenario in `scenarios/`: copy its settings block and helpers.
   - The app's section in `references/`.
3. **Look before writing.**
   - Call `inspect_app`: the app's windows front to back, each element's role, the name `app.click` matches and its rect, every menu path, and a still with a grid every 100 window points. Pass `action` ("menu:Data > Validation...") to see a dialog, `slug` to open the app the way that short's scenario does.
   - Copy menu paths and button names from it. Names match across `…`/`...` and `’`/`'`, but "Close Window" is not "Close".
   - Read rects and points off the still, in window points (1280×720 at uiScale 1.5): `app.rect(r)`, `app.point(r)`, `app.grid({ x, y, colWidth, rowHeight })`.
   - Never probe the app with osascript, System Events or screenshots of your own.
4. **Write** the scenario and the sheet in place. Call `write_scenario({product, slug})` until it is ok.
5. **Rehearse** whenever there are new targets or steps. Fix every `notes` entry: a target missing when its step begins films a frozen pause. Then `step_frames({ source: 'rehearsal' })`: one still per step, beside each step's `crop` (what the video shows of the capture) and `offCrop` (a target partly outside it). A failed rehearsal's job carries a still of the step it stopped in.
6. **Record**.
   - If the short is `produced`, pass the reviewer's change as `reviseNote` to `request_recording`: it sends it back and records in one call.
   - Then `get_job({ waitSeconds: 300 })` until it ends. A failed take carries stills of its problem steps.
   - Never use `sleep` in Bash.
   - `phase: 'waiting'` means the person has to click Start. Keep waiting, and never request again.
7. **Check the take yourself** with `step_frames`, every step, before you call it done. A take that passes Studio's checks can still be wrong: a dropdown that never opened, the wrong page order, a sidebar covering the page, a menu over the content, a dialog cut off. Look for:
   - the content centred in the 9:16 crop, with no blank area;
   - each caption over the thing it names;
   - text that is right (names, numbers, the merge result);
   - the cover frame (time in the sheet) clean;
   - no private data.
8. **Report** in a few lines: what changed, what you checked, and anything small left for review. State any leftover files and what you cleaned up.

## Narration and timing (the most common failure)
A pause of **1.1 s that is both silent and frozen fails the take.**
- **One short line per step**, about 3–8 words.
  - A long line takes the voice longer to synthesise than to speak (17 s once), which films a frozen pause.
  - Split a sentence across steps: "Click Document," / "then Mail Merge," / "and Merge."
- **Every step that waits or moves gets a subtitle**, including `waitForText`, `waitForWindow`, menu steps and launch.
  - A step with no line must be instant (`holdMs: 0`), even the last one: a slow unnarrated last step (cleanup) fails the take. Run slow cleanup unawaited under the last lines.
- **`app.menu` opens its menu inside its own step**, so its line covers the opening. Name the path in its caption.
- **A line with no action** is `demo.say({ id, subtitle })`.
- **`write_scenario` warns** on lines likely to synthesise slowly, waits with nothing said over them, and a short running long. Fix its `warnings` before recording.
- **Captions for menu paths use arrows**: "File → Export To → PDF". Add a `pronunciations` entry so the voice says "File, Export To, P D F".
- **Pronunciation**:
  - Numbers are said as numbers ("120", not "1 2 0").
  - "double-click" is said as "double click".
  - "Cmd+A" is said as "command A".
  - Add entries rather than rewording what the person wrote.
- **Hold where the viewer reads**: 900–1200 ms on a result (a merged letter, the finished table), 300 ms between actions.

## Camera and framing
The phone video is the middle of the window, and the camera follows each step's target.
- **Point narrated steps at the content**, not at the control. Use a measured `pt-ax` rect: the letter's text, the table, the dialog's middle line.
  - A click on a button at a dialog's edge drags the camera there.
  - Pressing the default button with Return keeps the camera on the whole dialog.
- **Hide sidebars and inspectors** that cover the page in the cut.
  - Apps open them as last left, so test with `app.text()` before acting.
  - Move rects that depend on the sidebar (the page shifts when it hides) and fix them once the layout is stable.
- **Open dialogs fully before the step that shows them.** Use `waitForText` on words inside the dialog.
- **Menus open over the page.** Put them on their own steps and never during a step whose caption is about the content underneath.
- **Show where the data comes from first** if the short uses it (the class list before the merge). Two apps use `desktop.apps` and `demo.turn(other.actor)`, a hard cut by default; never ask for a card, which films black and silent.
- **What isn't filmed, or has filmed black**: windows of other processes (Open and Save panels) are never filmed; turn cards film black; keep/close alerts and Office's menus have filmed black in some takes, cause unknown (a slow app may not have drawn a menu yet). Keep them out of narrated steps, and do the close alert last.

## Input safety (the person's Mac)
- **Show the cursor with the fake cursor**: `app.point(rect)` moves the video's cursor there and ripples, sending the app nothing. Never use real pointer input unless the person agreed for that app (Pages' canvas is the one exception so far).
- **Prefer menus over modifier chords.** Ctrl/Cmd+arrows and similar reached the person's window manager and moved windows. Plain keys, Return, Escape and Cmd+letter are fine.
- **Never send System Events keystrokes or clicks yourself without asking.** They land in whatever app is in front, and once damaged the person's text.
  - An asset script that types into an app needs the person to say go and keep their hands off the Mac.
  - Their go covers that one run only.
- **Never call request_recording or rehearse a second time** while a job waits for Start.

## Revisions
- **Keep every existing step id.** Pin ids explicitly (`id: 'app.3'`) when you add an app or steps, since actor numbering would rename them. A new step gets a new descriptive id.
- **Change only what the note asks for**, plus anything broken you find (and say so).
- **Edit the upload sheet** only where the change affects it: the caption and the notes. Keep its layout exactly as `rules.format` gives it.
- **"Too many failed attempts"**: tell the person. A changed scenario that passes `write_scenario` or rehearses clean starts the attempts over; otherwise it needs `studio review --retry`. Don't loop.
- **`write_scenario` lists `stepIds`**: ids of the last take your change dropped, and positional ones (`app.N`) that may have moved. Pin the ones a note names.
- **Change one sheet field** (the caption, a title, the cover second) with `edit_sheet`, not by rewriting the sheet.

## Leaving things as they were
- **Close what the run opened without saving**: `app.closeAndDiscard()` as the last step. It is unnarrated and best-effort: a failure becomes a `demo.note`, never a failed take.
- **Sample files**:
  - Open them with `desktop.document`, and `scratchCopy: true` for an app that autosaves (Preview, Excel): the app opens a temporary copy.
  - Never open the person's own files.
- **Delete exported files** with `desktop.cleanup: { downloads: '^Untitled( \\d+)?\\.pdf$' }`: only files created during the run are removed.
- **Check for strays afterwards** in iCloud Drive (Pages/Numbers "Untitled N") and Downloads. Say if you couldn't remove one.
- **Live sites**: trash what the short made, from an unfilmed tab.

## Common mistakes
| Mistake | Instead |
|---|---|
| Probing with rehearsals that throw on purpose, or osascript | `inspect_app` first |
| Guessing a name: "Data Validation…", "Close" | Copy it from `inspect_app`; a not-found also lists the closest names |
| Long narration lines | Short lines, one per step |
| A step with no narration that waits | A subtitle, or `holdMs: 0` and last |
| Trusting a passed take | `step_frames` every step |
| `request_recording` on a produced short | `request_recording({ reviseNote })` |
| `sleep 45` between polls | `get_job({ waitSeconds: 300 })` |
| A turn card between apps | A plain `demo.turn`: a cut |
| Hand-written `Rect`/`point` helpers, empty `run` steps | `app.rect`, `app.point`, `app.grid`, `demo.say` |
| A hand-written close and Don't Save | `app.closeAndDiscard()`, last |
| Clicking a dialog's edge button | Return, or point at the dialog's middle |
| Real mouse or keystrokes into the Mac | Fake cursor; ask first |
| Renumbered step ids after a revision | Pin the old ids |
