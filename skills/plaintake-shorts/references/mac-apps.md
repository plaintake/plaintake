# Mac apps: what each one does on camera

Learned on real shorts (macOS 15.8, Office 16.11x, iWork 14). Check that a quirk
still holds when the app updates.

## Every Mac app
- **Settings**: `uiScale: 1.5` (window 1280×720 points). `viewport`, `locale`, `timezoneId`, `colorScheme` and `reducedMotion` take one value each and can be left out; the product's `scenarioDefaults` (in `get_product_context`) may already set `uiScale` and the args below.
- **Args**:
  - `-ApplePersistenceIgnoreState YES`, so an old document never reopens.
  - `-AppleLocale en_AU` / `en_IE` per market. Decimals and list separators follow it: Excel's validation list splits on `;` in comma-decimal locales.
  - `-NSCloseAlwaysConfirmsChanges YES` when you rely on a close prompt.
- **`launch: 'fresh'`** fails if the app is already running. Quit it first, or ask the person to.
- **Coordinates** are window points from the window's top-left. One window point equals one CSS pixel on the desktop page.
- **`app.rect({ x, y, width, height })`** is an invisible element the cursor and camera can target; `app.point(rect)` is a step that points at it, `app.grid(...)` makes cells.
- **Out-of-process windows** (Open/Save panels, iCloud pickers) can't be filmed or typed into. AX clicks reach a save sheet; keys don't.
  - Start apps on a new document: `-NSShowAppCentricOpenPanelInsteadOfUntitledFile NO`.
  - Open a second file mid-take with `execFile('open', ['-a', App, file])` inside a narrated step.
- **Alerts at close** (save / keep this document) have filmed black in some takes, cause unknown. Do them last and don't narrate them.
- **A new window** (Merge, Export) is filmed only once the filmed window closes.
  - Bring the original forward with Cmd+\` and close it with Cmd+W.
- **`app.text()`** shows what is on screen. Use it to branch on state (sidebar open? which tab?).
- **`app.waitForText`**:
  - `timeoutMs` must be ≥ 5000.
  - Use a regex when the app inserts invisible marks (`/Classic Certificate/`).
- **Several apps** (`desktop.apps`): each app's `label` is its badge, drawn at the top-left of the phone picture on a dark plate in every frame of its turn. Use the app's own name ("Word", "Excel"); the badge covers about 120×60 px of that corner, so a toolbar under it is fine and the subject of a line is not.
- **Roles**: thumbnails are `AXImage` (short role `image`). `inspect_app` shows each element's role.

## Pages
- **Launch args**:
  - `-NSShowAppCentricOpenPanelInsteadOfUntitledFile NO`, or it opens on the iCloud Open panel.
  - `-TPReplaceSenderFieldsUsingMeCardInNewDocuments NO`, or the account name fills sender fields.
- **Template chooser**:
  - Choosing a category selects its first template.
  - AXPress on any template opens the *selected* one. Select with a real click on the thumbnail, then AX-press Create.
  - Wait for the list text, which fills in late.
- **After Create**:
  - Wait about 4 s before changing the view; input sent while the document settles is ignored.
  - Menu commands less than 2 s apart leave a menu open that swallows later clicks.
- **The inspector or sidebar** opens as Pages last left it (hidden, Format, Document).
  - Test `app.text()` (e.g. /Headers & Footers|Mail Merge|Paragraph Style/).
  - Hide it with `app.menu('View > Inspector > Hide Inspector')`.
  - The page moves about 136 points to the right when it hides.
- **The canvas isn't in Accessibility.** Text boxes need real clicks at window points; the person agreed to that for Pages only.
  - Double-click a multi-line box. Once editing, a single click selects a placeholder.
- **Date fields** show today.
- **The export save sheet** keeps the last folder and names files "Untitled". Strays show up as "Untitled N".
- **Page Down** scrolls less than a page. Use View > Go To > Next Page (it has no shortcut).
- **Mail Merge**:
  - The spreadsheet link lives in Pages' per-Mac view state (PersistentContainers), keyed to the letter's path, not in the file.
  - A copied or moved letter merges from Contacts, which would film the address book.
  - Open the letter in place and never save it.
  - Rebuild with the asset script on a new Mac.
- **Merge** opens the result in a new window. Return presses Merge.
- **Closing the merged document** asks whether to keep it. Choose Delete, unnarrated, after the last line (never filmed).

## Numbers
- **A .xlsx** opens with nothing selected and its cells aren't in Accessibility. Cmd+A then Option+Return reaches A1. Point at cells with `app.grid` cells.
- **Export → Excel** opens a sheet, then the save sheet:
  - Typing `~` opens Go to Folder there (Cmd+Shift+G doesn't).
  - Don't open Where: Recent Places would film folder names.
- **iCloud name clashes** give "name 2.xlsx". Exporting shows a "Some changes were made" alert.
- **Cmd+W** closes without asking.

## Excel
- **Cells** aren't in Accessibility.
  - Move with keys from A1.
  - Point the video's cursor at measured rects, using a grid helper for rows and columns.
  - Never use real mouse input.
- **Recovery prompt.** After an interrupted run Excel asks "Open recovered workbooks?". Answer No in `warmup`, which is never filmed:
  - `if ((await app.text()).includes('Open recovered workbooks?')) await app.click({ role: 'button', name: 'No' })`
- **Ribbon and menus**: ribbon drop-downs ignore synthetic input, and Excel's menus have filmed as a black block in some takes (perhaps not yet drawn).
  - The menu item is "Data > Validation...", with three dots.
  - Page Layout > Print Titles is on the ribbon.
- **The Data Validation dialog is a separate window.** Element verbs look in the app's windows front to back, so its "Allow:" pop-up is `app.choose({ role: 'popup', name: 'Allow:' }, 'List')` (named by the label beside it). An earlier short drove it through System Events; check it with `inspect_app({ action: 'menu:Data > Validation...' })` and never shell out.
  - The "doesn't match" alert opens at the screen's right edge; move it into the frame.
  - A take passed with the pop-up never opened, so check the stills.
- **Flash Fill** is Ctrl+E. The status bar says "Flash Fill Changed Cells: N".
- **The print sheet** names only the "Page n of N" labels; each page's thumbnail sits above its label.
- **Close**: `app.closeAndDiscard()`.

## Word
- **First run** shows a "Start Using Word" welcome window once.
- **Body text** isn't in Accessibility.
- **Paste Special** (Ctrl+Cmd+V) defaults to HTML Format. Cmd+A then F9 updates links.
  - A pasted link reads the *saved* Excel file, so save a scratch copy first.
- **The close prompt** has "Don’t Save" with a curly apostrophe; names match either way.
- **Close explicitly, also in `finally`** (`word-find-replace-letter-template`): `app.closeAndDiscard()` opened File > Close and left Word's save prompt unanswered. Use `app.press('Cmd+w')` after the last line (never filmed), `waitForText(/Don.t Save/)`, then click 'Don’t Save' (`holdMs: 0`). Wrap the run in try/finally that does the same when a step failed: a window left open sits beside the next take's letter and breaks it, and once quit it comes back as "<name> - Recovered" on every launch until someone closes it by hand.
- **Wait about 1 s after the last line before Cmd+W** (`word-merge-if-fees-unpaid`): the video keeps a ~0.34 s tail after the last line, and a close sent at once faded the Don't Save alert in over the final frames. A plain `await new Promise((r) => setTimeout(r, 1000))` (no step) before the close keeps it unfilmed.
- **Start gallery on a cold launch**: Word sometimes opens its Start gallery (account name, recent files) in front of the sample document; it swallows menu commands and is private. In `warmup`: `if (/Blank Document|Recommended/.test(await app.text())) await app.click({ role: 'button', name: 'Cancel' }, …)`.
- **Find and Replace**: Cmd+Shift+H toggles the Find and Replace *sidebar* and was unreliable (opened once, nothing the next run; Word then reopens the sidebar as Thumbnails). Use `app.menu('Edit > Find > Advanced Find and Replace...')`: a centred dialog on its Find tab; click radio 'Replace', comboboxes 'Find what:' and 'Replace with:' (click to focus, then type), button 'Replace All'. Word answers "All done. We made N replacements." (OK = Return; Escape then closes the dialog). Replace All keeps a run's highlight on the new text.
- **Sample .docx via textutil** drops highlights, fonts and page size and merges plain runs: wrap each word to patch in a styled span, then patch `word/document.xml` (`create-eu-staff-calendar-letter-assets.ts`). HTML tables flatten to one cell a line.
- **No Merge to PDF** in Word 16.114 for Mac (`word-merge-to-pdf-hr-letters`): Mailings > Finish & Merge is a menubutton that *does* open on an AX click, but lists only Edit Individual Documents..., Print Documents... and Merge to E-Mail. One PDF per record needs Mergram.
- **Keep `-AppleLocale en_IE`** for Word, as every Word short has: one launch with `en_US` showed "Default Editing Language Changed" and Word replaced Normal.dotm (keeping a backup). Market formats come from the data anyway.
- **Link a Word table, not an .xlsx, when the merge only needs the values** (`word-merge-date-format-fix`): an .xlsx source goes through Word's Excel converter (Open Document in Workbook / Open Workbook), which hung Word at launch in five takes while rehearsals passed. A .docx holding one table, linked with `<w:dataType w:val="textFile"/>` and `<w:query w:val="SELECT * FROM /abs/path.docx"/>` (no odso), opens with no popups. Write each cell as Excel shows it.
- **A force-quit Word leaves `AutoRecovery save of <doc>`** (Containers/com.microsoft.Word/.../AutoRecovery) and a `~$` lock beside the linked list; trash both before the next take, or Word can launch with no main window.
- **A new linked workbook** needs Word's one-time Grant File Access (Select... opens an Open panel only the person can click), as `mailing-list.xlsx` did.
- **No account** shows at the top right of a document window (Comments, Editing, Share only); nothing to mask there.

## Preview
- **It autosaves into the open file.** Open the sample with `scratchCopy: true`.
- **Use menus, not key chords.** Chords moved windows through the person's window manager.
- **Opening**: it opens A4 fitted to width and scrolled to the bottom. `Home` doesn't scroll back; use PageUp or a menu.
- **Annotations** aren't in Accessibility.
  - Each new text box lands lower than the last, so give each its own spawn point.
  - The first key typed into a new box turns it into an editor: type it on its own.
- **Moving pages**:
  - Dragging thumbnails between windows doesn't insert pages. Use Edit > Copy / Edit > Paste.
  - Paste inserts **before** the selected page.
  - Check the page order in the stills; a rehearsal won't show it.
- **Thumbnails** are AXImage, named after the file for one page, else "1", "2", ….
- **Close**: `app.closeAndDiscard()` (File > Close Window; it autosaves, which is why the scratch copy matters).
- **Redact** (Tools > Redact, macOS 15):
  - It only enters redact mode, after an alert ("Redacted content is permanently removed", Return = OK; leave "Do not show again" alone). A Find selection is not redacted.
  - Mark text with `app.drag` corner to corner of its box. A flat (zero-height) drag removes the text but draws no bar.
  - The text leaves the file only on close: to prove it, File > Close Window, reopen with `execFile('open', ['-a','Preview', copy])`, then Edit > Find shows "No Results Found" (an AX text, usable as a camera target). Needs your own copy (not `scratchCopy`) so you know the path; reset it at load and in `finally`.
- **Sidebar state carries over** from the last window closed (a search leaves its sidebar open, and the next launch opens with thumbnails). Hide it before closing (View > Hide Sidebar) and check `app.locate({ role: 'AXGroup', name: 'document' })` x > 100 at the start.
- **Export sheet** (File > Export…, macOS 15; `preview-shrink-pdf-for-email`):
  - It is drawn inside the window and filmed, but keys don't reach it: the name stays the document's.
  - The Quartz Filter and Format pop-ups have no Accessibility name. Click the Quartz Filter pop-up at its window point (682, 328) with a real click (the person agreed for Preview), then `app.click({ role: 'menuitem', name: 'Reduce File Size' })`.
  - `Where:` is named: `app.choose({ role: 'popup', name: 'Where:' }, 'Downloads')`. Preview remembers it (it was Documents).
  - Never export to ~/Documents: Studio can't delete there (EPERM), and `open -a Preview` on a file there or in Downloads fails with "don't have permission". Export to Downloads, copy the file next to the scenario, and open the copy.
  - Reduce File Size took the 7.7 MB receipts scan to 1,077,391 bytes, still readable when zoomed.
- **Form filling** (`preview-fill-pdf-form`):
  - AcroForm fields are unnamed AXTextField/AXCheckBox, and Tab from the page goes to the toolbar's search field: click the first field at its window point (real click, agreed for Preview), then Tab field to field.
  - Tab past a pop-up field landed in a box Preview drew beside a heading (no widget in the PDF), so Space typed a space. Click check boxes at their window point.
  - **AutoFill shows the person's contact card** on fields named like `full_name`/`email_addr`/`phone_no`. Record a copy with the fields renamed `field_N` (pdf-lib, `create-preview-fill-form-assets.ts`) and launch with `'-NSAutoFillHeuristicControllerEnabled', 'NO'`.
  - `app.type`/`app.press` ignore `target`: the camera stays put. Put a `demo.say({ target })` on the next field before typing into it, which also keeps a short typing line from filming a silent pause.
  - The whole page for the result: View > Single Page, View > Zoom to Fit (page at window x 400–880), then View > Continuous Scroll under the CTA to put the view back.
- **Inspector** (Tools > Show Inspector) docks right of the window, outside the frame, and `app.drag` refuses a grab point outside the window. File sizes can't be filmed there: put them in the captions.
