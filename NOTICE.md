# Third-party notices

PlainTake is proprietary software — see [`LICENSE`](LICENSE). Going closed source
does **not** discharge the obligations owed to the components it ships, vendors, or
invokes. Those are recorded here.

None of this is legal advice. Have the licence and these notices reviewed before a
commercial launch.

## Playwright — Apache License 2.0

**Redistributed.** The shipped binary cannot bundle Playwright, because
`playwright-core` reads real files from disk at runtime (`browsers.json`,
`webp_codec.wasm`, `xdg-open`, `trace-viewer/`) and a Node SEA cannot `require` from the
filesystem. So `playwright` and `playwright-core` are **vendored beside the executable**
and loaded from there.

That makes attribution mandatory rather than incidental: Apache-2.0 §4 requires the
licence, the copyright notice, and any `NOTICE` file to travel with the distribution.
The install tarball therefore ships `vendor/playwright-core/LICENSE` and
`vendor/playwright-core/NOTICE` unmodified.

Chromium is **not** redistributed. `plaintake install-browser` fetches it onto the
user's machine via Playwright's own installer. Chromium carries its own licences
(primarily BSD-3-Clause plus the licences of its bundled components).

## Noto Sans — SIL Open Font License 1.1

**Redistributed.** `assets/fonts/NotoSans-Regular.ttf` ships with the product; the
renderer pins fontconfig to it so a host font can never win, which is what makes caption
rendering deterministic.

OFL 1.1 permits bundling in a commercial, closed-source product. Two conditions apply
and both are met:

- the full licence text travels with the font — `assets/fonts/OFL.txt`;
- the font is **not modified**, so the Reserved Font Name restriction is not engaged. If
  it is ever modified, it must be renamed.

OFL also forbids selling the font *by itself*. Bundling it inside this product is not
that. Source: <https://github.com/notofonts/notofonts.github.io> (hinted static TTF).
The file's SHA-256 is pinned in `assets/fonts/checksums.txt`.

## FFmpeg — GPL, and deliberately not redistributed

FFmpeg is **not shipped with the product**. It is invoked as a separate executable that
the user installs themselves, and the two communicate only through a process boundary
and files.

This matters commercially. The builds this project targets are configured with
`--enable-gpl` and `--enable-libx264`, which makes those binaries **GPL-licensed**.
Because PlainTake never links FFmpeg — it spawns it with an argument array and reads
its output — the GPL applies to the FFmpeg binary the user installed, not to
PlainTake. Keeping it that way is a licensing requirement, not a design preference:
**do not vendor, bundle, or statically link FFmpeg or libx264 into the shipped binary.**

One exception to be aware of: the canonical container image (`docker/Dockerfile`)
installs FFmpeg via apt. **Distributing that image redistributes GPL binaries** and
carries the corresponding GPL obligations for FFmpeg itself. The image is a
reproducibility harness, not a product artefact; if it is ever published, comply
accordingly.

The Docker recipe that ships with each release (`plaintake.Dockerfile`) is not that image. It is
a text file that the user builds; their build downloads FFmpeg from Ubuntu's archive. PlainTake
still distributes no FFmpeg binary, in a tarball or in an image.

## H.264 / AVC patents

Output MP4 files use the H.264/AVC video codec via libx264.

**"Free software" does not mean "patent-free."** H.264 is covered by patents administered
through a patent pool. Distributing an H.264 encoder or decoder, or distributing H.264
content commercially, may carry licensing obligations depending on jurisdiction and
scale of use. PlainTake deliberately:

- does not bundle, vendor, or redistribute an FFmpeg or libx264 binary;
- keeps FFmpeg a separately installed external executable;
- makes no representation that any particular use is patent-unencumbered.

Selling software that produces H.264 output raises this question more sharply than
giving it away did. Review the obligations before launch.

## Gumroad

Licence keys are issued and validated by Gumroad. Activating a paid licence makes one
request to Gumroad's public licence-verify endpoint; no API key or access token is used,
and no credential is stored. Recording and rendering never contact Gumroad or anything
else — see [`docs/licensing.md`](docs/licensing.md).

## Spoken narration: Kokoro, HeadTTS, CMU dictionary, ONNX Runtime

Narrated audio is synthesised locally. The component chain was chosen for its licences as
much as its quality, because the obvious alternatives are copyleft and this product is
closed source.

**What is avoided, and why it mattered.** The usual routes to Kokoro — the Python `kokoro`
package, or `kokoro-js` via the npm `phonemizer` package — convert text to phonemes using
**espeak-ng, which is GPL-3.0**. So does Piper, whose maintained fork is GPL-3.0 outright.
Linking either in-process would put copyleft terms on PlainTake, which is the same hazard
FFmpeg presents and is handled the same way: keep it out. Nothing in the speech path links
espeak-ng, and no espeak-derived code is redistributed.

**Kokoro-82M — Apache License 2.0.** The model weights. **Not redistributed.**
`plaintake install-voice` fetches them from Hugging Face onto the user's machine, verified
against a pinned SHA-256, exactly as `plaintake install-browser` fetches Chromium. Nothing
is bundled and no account is needed.

The download is pinned by *commit*, never a branch: the revision and the SHA-256 of all 32
fetchable files live in `packages/speech/src/pinned.ts`, generated by
`scripts/fetch-speech-pins.ts` and committed. Bytes that do not match are deleted rather
than used, so neither a corrupted transfer nor a silently re-uploaded model can become the
voice in a published video. Only the 28 English voices are offered — the model's Spanish,
French, Hindi, Italian, Japanese, Portuguese and Chinese styles are deliberately not
installable, because the bundled pronunciation dictionary below is en-us only.

**HeadTTS — MIT.** *Redistributed.* `packages/speech/vendor/headtts/` holds four modules
copied from [HeadTTS](https://github.com/met4citizen/HeadTTS) v1.3.0, Copyright (c) 2025
Mika Suominen: the grapheme-to-phoneme engine, its English language module, a utility module,
and the inference worker. MIT requires the copyright notice and licence text to travel with
the distribution, so the upstream `LICENSE` ships unmodified beside them, and
`checksums.txt` records the SHA-256 of each file.

Three of the four are byte-for-byte upstream. `worker-tts.mjs` carries one PlainTake
modification, marked inline as `PLAINTAKE PATCH`: it honours an offline setting so model
loading cannot fall back to fetching from the Hugging Face Hub mid-recording. MIT permits
modification; the change is annotated at the point of change and described in
`packages/speech/vendor/headtts/README.md`.

**CMU Pronouncing Dictionary — 2-clause BSD.** *Redistributed* as
`assets/speech/en-us.txt` (~2.7 MB), by way of HeadTTS, which converted its ARPAbet
entries to the phoneme set this model was trained on. The upstream copyright notice is
retained in the file's own header comment, which is where CMU's licence requires it.
Out-of-dictionary words fall back to the letter-to-sound rules of NRL Report 7948
(Elovitz et al., 1976), a US Naval Research Laboratory publication in the public domain.

**ONNX Runtime (`onnxruntime-node` and `onnxruntime-common`) — MIT, and Transformers.js
(`@huggingface/transformers`) — Apache License 2.0.** *Redistributed*, and **vendored beside
the executable rather than bundled**, for the same reason as Playwright: ONNX Runtime is a
native module, and a Node SEA cannot `require` a `.node` binary from inside itself. Their
licence texts travel with the vendored copies. Only the host platform's native binary is
shipped.

Both are fetched at build time by `scripts/fetch-speech-runtime.ts` against SHA-256 digests
committed in that file, rather than being workspace dependencies — one `onnxruntime-node`
tarball carries every platform's native library, 220 MB unpacked, which does not belong in the
lockfile every contributor installs from. Neither ONNX Runtime package ships a licence file in
its npm tarball, so the MIT text is fetched from the upstream repository at the same pinned
version and written beside each copy; `scripts/build-binary.sh` fails the build if either is
absent, and if more than one platform's native library is staged.

**A stub named `sharp` — PlainTake's own code, and the reason is licensing.** Transformers.js's
Node build opens with a *static* `import sharp from "sharp"`, so it cannot load unless something
resolves under that name. Real [sharp](https://github.com/lovell/sharp) bundles **libvips, which
is LGPL-3.0-or-later**, and PlainTake calls no image code at all: the speech path loads a model,
tokenises phonemes and gets audio back. Shipping an LGPL image library to satisfy an import that
is never used would give away the argument this whole section makes, so `vendor/node_modules/sharp`
is two files of ours that throw if anything ever calls them. See
`packages/speech/vendor/sharp-stub/README.md`, which records how it was verified. **No part of
libvips or sharp is redistributed.** `onnxruntime-web`, also a dependency of Transformers.js, is
likewise not fetched or shipped: the Node build does not import it.

None of these requires a credential, and none is contacted while recording or rendering.

## MCP SDK, Zod, and the toolchain

`@modelcontextprotocol/sdk` (MIT) and `zod` (MIT) are shipped inside the bundled binary.
Their licence texts travel with the distribution.

Node.js, pnpm, TypeScript, Vitest, ESLint, esbuild and dependency-cruiser are build- and
test-time only and are not redistributed, save for the Node runtime embedded in the
single-executable build (Node is MIT-licensed, and its own notices ship with it). Exact
versions are pinned in `package.json` and `pnpm-lock.yaml`.
