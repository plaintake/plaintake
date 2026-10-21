# Websites: what each one does on camera

Websites are recorded with Playwright Chromium, using the product's saved sign-in. Use Playwright
locators (`getByRole`, …). Mask anything private with `web.mask` before it appears.

## Every website
- **Never write login steps.** The actor starts signed in.
- **A `preflight` must not `addCookies` over the saved sign-in.** `write_scenario` refuses it.
- **Cleanup on a live site**:
  - Run it from an unfilmed tab or page, started early and not awaited when it is slow.
  - Make it best-effort: try/catch, then `demo.note`.
- **End-of-take popups** ("File is in the bin", toasts) can be hidden with a `MutationObserver` added in the page.
- **Content drawn on a canvas** (Google Docs pages) has no elements.
  - Draw invisible overlay boxes (`#demo-header-n`) before the step that targets them, never inside its own run.
- **Camera**: Mergram's scenarios draw a fixed `#demo-camera-frame` box that the camera follows. Frame a dialog with a box wider than the dialog.

## Canva
- **Canva silently drops uploads made by a script.** The person uploads the file by hand (named "… (PS).pdf") before every rehearsal and take, including the retake Studio makes after a voice stall.
  - Ask, and wait for their "go".
  - Keep the exact steps in the product's own docs, so the next take repeats them.
- **Bot check**: `handoff: 'preflight'` with `demo.handoff` gets a headed browser past it. Cloudflare and rate limits happen; wait instead of retrying fast.
- **Imported PDFs**:
  - Lines under about 60 pt apart become one text box.
  - Boxes keep their width.
  - Box ids change on every upload, so find boxes by text.
- **Trash the design** from an unfilmed home tab. The menu item wording varies.
- **Console errors** the site always throws are listed in the notes doc. Allow exactly those.

## Google Docs
- **Pages are a canvas.** Use overlay boxes as targets, drawn before their step.
- **Docs scrolls back to the cursor after typing.** Press Cmd+Home first.
- **A second session on the same doc** draws a named cursor flag on the filmed page. Close other sessions.
- **The cleanup editor** takes about 15 s to load: start it early.
- **The trash item** says "Move to trash" or "Move to bin" depending on locale. Match both.

## Mergram
- **Scale**: at uiScale 1.5, 1 point is 1.075 px.
- **Drag and drop** uses dispatched `DragEvent`s.
  - A drop onto an existing field throws, so place fields bottom-up.
- **Chromium's PDF viewer** reports `ERR_ABORTED`. Poll the URL instead.
- **Takes run slower than rehearsals** (`word-merge-to-pdf-hr-letters`, Oct 2026): the same steps took 2-3 s in rehearsals and 10-18 s in takes (canvas settling after the spreadsheet upload, Save as Template, the merge screen loading, template deletion). Give every network wait its own step with a long line, hover the field chips while the canvas settles, and start the template deletion unawaited in the step before the CTA. Check `curl -w %{time_total} https://mergram.com/api/config` first: at 1-7 s for that endpoint, a take can't pass (Save as Template hung 30 s).
- **Text baselines**: check the stills zoomed in when fields sit next to static text ("the name now looks lower compared to 'Dear'").

## Google Sheets (learned on sheets-permission-slip-tracker)
- **The demo account is UK English**: "Tick box" not "Checkbox", "Fill colour", "Move to bin". Match both spellings with a regex.
- **Only docs.google.com is signed in; drive.google.com redirects to sign-in.** Drive search and emptying the bin never work. Find leftovers in `https://docs.google.com/spreadsheets/u/0/?q=<title>`, open each one, then File > Move to bin.
- **Open the cleanup tab in warmup**, on `#gid=0&range=Z500`, so the second session's cursor stays off the filmed grid. Never click in it during the take.
- **A new sheet may show a "Save time with tables" card and a Tables side panel.** Dismiss them in warmup ("Got it"). There are several hidden sidebar Close buttons: use `.waffle-sidebar-title-close:visible`.
- **Targets on the grid canvas**: select the range with the Name box (`#t-name-box`), then lay an invisible box over the union of `.range-border, .active-cell-border` rects, in warmup.
- **Conditional formatting sidebar**: the condition dropdown shows "Is not empty", the formula field has the placeholder "Value or formula", swatches are `[aria-label="light red 2"]`, and there is a "Done" button.
- **Warmup's `demo` has `note()`** (since this PlainTake release; older ones lacked it): a note there is reported with the run's own.

## Every website
- **A `demo.chapter()` between narrated steps films a ~1.1–1.3 s silent zoom-out.** Over a static page that fails the take. Keep chapters out of short scenarios, or only before the first line.

## Google Sheets print / PDF export (learned on sheets-one-page-pdf)
- **File > Download > PDF and File > Print open the same "Print settings" view**, in the page: preview on the left (first page ~CSS 267,79), settings on the right (CSS x ≥ 979, outside a 9:16 crop centred on the preview).
  - Controls: `getByRole('listbox', { name: /Paper size/ })`, `/Scale/`, `getByRole('radio', { name: 'Landscape' })`; options are `[role="option"]` ("Fit to width", "Normal (100%)", "Letter (21.6 cm x 27.9 cm)", "A4 …"). Cancel/Export are `[role="button"]` with that text.
  - "Formatting" is a collapsed section; its box is labelled **"Show grid lines"** (two words). The checkbox span's clicks are intercepted: click the label text.
- **Sheets remembers the last print settings for the account**, saved as you change them (no Export needed). Set the "before" state in warmup (File > Print, set, Cancel) and put the account's own defaults back at the end from the unfilmed tab.
- **The account's UK locale stores typed "$1,234.50" as text** (left-aligned), so SUM shows 0. Type computed totals and right-align with Cmd+Shift+R.
- **Empty columns widen Fit to width**: delete O:Z (`Meta+Alt+Minus` on the selected columns) so the table fills the page.
- **"Convert to table" outlines the whole data range**, so `.range-border` measurements come out too wide; measure from `.active-cell-border` of A1 times columns/rows.
- **Point preview steps at a box over the page**, not the preview container: its centre is right of the page and cuts it off.
- **A slow unnarrated last step fails the take** (4.8 s cleanup filmed a silent frozen pause). Start the cleanup unawaited in the second-to-last step's run and await it in the CTA step.

## Google Sheets (learned on sheets-fix-name-capitals)
- **Cmd+Shift+V (`Meta+Shift+v`) doesn't paste values in Sheets under Playwright**: nothing is pasted. Use Edit > Paste special > Values only (`#docs-edit-menu`, hover the "Paste special" `.goog-menuitem`, click "Values only"). Plain `Meta+c` copies fine. Grant `clipboard-read`/`clipboard-write` for https://docs.google.com in warmup.
- **The Tables side panel can open a few seconds after the grid**, so a check right after load misses it. Close it after typing the data (`.waffle-sidebar-title-close:visible, [aria-label="Close"]:visible`, last), and check it's gone.
- **The first formula in a column brings up a "Suggested auto-fill" card** (✓/✕) about half a second after Enter. Escape dismisses it. Then reselect the cell, because Enter moved down.
- **Fill handle**: `.autofill-handle:visible` around the selected cell; `page.mouse.dblclick` on its centre fills down.

## Google Sheets Remove duplicates (learned on sheets-remove-duplicate-signups)
- **The Data menu has no `#docs-data-menu` id** (File/Edit/Insert/Format do). Match the menu bar button by text: `#docs-menubar .menu-button:visible` filtered by `/^\s*Data\s*$/`.
- **Data > Data cleanup > Remove duplicates**: hover the "Data cleanup" `.goog-menuitem` (match `/Data clean-?up/i`), then click "Remove duplicates". The dialog is a `[role="dialog"]` ("14 rows and 3 columns selected", "Columns to analyse"); "Data has header row" is **not** ticked by default even with a bold header row, so click its text. Its button is `[role="button"]` "Remove duplicates".
- **The result is an `[role="alertdialog"]`**: "3 duplicate rows found and removed. / 10 unique rows remain." with an OK button. Wait for `/unique rows? remain/` in the step that clicks Remove, so the result step's target exists when it begins.
- Put a long column (emails) last so it spills into the empty columns instead of being cut off.
