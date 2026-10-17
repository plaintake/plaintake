# Sample files and asset scripts

A short shows fictional sample files that sit beside the scenario. They are opened with
`desktop.document` or uploaded on the web, never taken from the person's own files. Each product
keeps generators in `scenarios/assets/create-*.ts`.

## Shape of a generator
- **A header comment** gives:
  - what it makes and for which scenario;
  - the market (AU/EU: paper size, date format, currency);
  - the run command (`node --experimental-strip-types scenarios/assets/<name>.ts`);
  - each output path with its layout;
  - design notes for the 9:16 cut (e.g. a blank wide column A so the table sits mid-frame; 5 cm side margins so a letter's text fits).
- **The data** is a fixed list of fictional rows. It is written to `scenarios/assets/au/` or `eu/`.
- **Library**, chosen by output: SheetJS `xlsx` for spreadsheets, `pdf-lib` for PDFs (A4 = 595×842 pt), `textutil` for .docx.
- **Apple apps** (`.numbers`, `.pages`) through AppleScript, with System Events only for what AppleScript doesn't expose.

## Apple apps through AppleScript
- **Launch so that AppleScript isn't blocked by the Open panel**:
  - `open -g -a App --args -NSShowAppCentricOpenPanelInsteadOfUntitledFile NO -ApplePersistenceIgnoreState YES -AppleLocale en_AU`
  - Then wait about 5 s.
- **Prefer `tell application "Pages"/"Numbers"`** (set cell values, body text, fonts, save in a POSIX file) over typing.
- **System Events steps** (menus, the Open panel's Cmd+Shift+G path, key-code loops) type into whatever is in front:
  - The person must say go and keep their hands off the Mac for the run (about 30 s).
  - Their go covers one run.
  - Never run one without asking.
- **Check the output afterwards**: open the file and dump or screenshot it (a field can go missing silently).
  - The parent letter lost its second «Student» field once; a re-run fixed it.
- **Pages Mail Merge**: the spreadsheet link is per Mac and per path. Save the letter at its final path *before* linking, never move or copy it, and re-run the script on a new Mac.

## Scratch copies
- **Apps that autosave** (Preview, a linked Excel file) open a scratch copy.
- **The scenario restores the copy** from the original in a `finally`, and at the start if a crashed run left it changed:
  - `if (!readFileSync(ORIGINAL).equals(readFileSync(COPY))) copyFileSync(ORIGINAL, COPY)`
