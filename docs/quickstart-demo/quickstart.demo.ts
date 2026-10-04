import { defineDemo } from '@plaintake/scenario';

/*
 * The quickstart tutorial video — PlainTake recording a guide to PlainTake, in a real terminal
 * and a real browser.
 *
 * The terminal is a live shell (`terminal.browser: true`): every command on screen really runs,
 * in a fresh working directory `make quickstart-demo` prepares with what a user has after the
 * install guide's download step — the release tarball, SHA256SUMS and install.sh, built from this
 * checkout — plus the example scenario. The download itself is the one step not filmed, because
 * a recording never opens a socket. The video checks the checksum, installs into the terminal's
 * own throwaway HOME, and from then on uses that installed binary. While its `plaintake run`
 * records the example in its own headless Chromium, the video cuts to the browser actor, which walks through that same scenario file —
 * served from the terminal's working directory by ./serve.mjs, so the listing is the file being
 * recorded. When the run has finished, the browser plays the MP4 it just wrote.
 *
 * Nothing in the browser is pre-rendered output: the only static pages are the code viewer and
 * the player in ./pages. Pages are preloaded off-screen with the raw `web.page`, while the
 * terminal still holds the turn, so every cut lands on a rendered page — the same reason the
 * old pages-only version navigated between steps, never inside a step's `run()`.
 *
 * The run records without camera zoom on purpose: at the zoom cap the framing window is
 * narrower than the code lines, and a tutorial that crops its own content is worse than one
 * that never zooms. Every pointed-at step still declares its target, so the drawn pointer marks
 * what is being talked about.
 */

const SCENARIO = 'release-approval.demo.ts';

export default defineDemo({
  schema: 'agent-demo.scenario/v1',
  id: 'quickstart-demo',
  title: 'PlainTake quickstart',
  language: 'en',
  viewport: { width: 1920, height: 1080, deviceScaleFactor: 1 },
  locale: 'en-US',
  timezoneId: 'UTC',
  colorScheme: 'light',
  reducedMotion: 'reduce',
  // The captions keep the written forms; the voice reads these as separate words and letters.
  pronunciations: { defineDemo: 'define demo', MP4: 'M P 4' },

  terminal: {
    cols: 100,
    rows: 28,
    // Created fresh by `make quickstart-demo`; see README.md.
    cwd: '../../../artifacts/quickstart-demo-workspace',
    // The installed binary's Chromium lives where the parent's does, which the terminal's clean
    // HOME would otherwise hide — the film's stand-in for a one-time `plaintake install-browser`.
    env: ['PLAYWRIGHT_BROWSERS_PATH'],
    browser: true,
  },

  intro: {
    lines: ['PlainTake quickstart', 'install → script → video'],
    narration: 'Install PlainTake and record your first demo, in a real terminal and a real browser.',
    durationMs: 2_500,
  },

  async run({ demo, term, baseURL }) {
    if (term === undefined) throw new Error('a terminal scenario is handed `term`');
    const web = await demo.actor('web', { label: 'Browser' });

    // The code viewer needs nothing the terminal makes, so it loads before the first frame.
    await web.page.goto(`${baseURL}/code.html`, { waitUntil: 'load' });
    await web.page.waitForFunction(() => (window as { __codeReady?: boolean }).__codeReady === true);

    await demo.chapter('Install');
    await term.waitForText('$', { timeoutMs: 10_000 });

    await term.run('ls', {
      id: 'download',
      title: 'The release download',
      subtitle: 'Start from the release download: the tarball, its checksums and the installer.',
      holdMs: 2_000,
    });
    await term.waitForText('install.sh', { timeoutMs: 5_000 });

    await term.run('shasum -a 256 -c SHA256SUMS', {
      id: 'checksum',
      title: 'Check the download',
      subtitle: 'Check that the download is exactly what was published.',
      holdMs: 1_800,
    });
    await term.waitForText(': OK', { timeoutMs: 30_000 });

    await term.run('sh install.sh plaintake-*.tar.gz', {
      id: 'install',
      title: 'Install',
      subtitle: 'The installer unpacks one self-contained tree and links plaintake.',
      holdMs: 2_400,
    });
    await term.waitForText('Next:', { timeoutMs: 60_000 });

    await term.run('export PATH="$HOME/.local/bin:$PATH"; plaintake --version', {
      id: 'version',
      title: 'Ready',
      subtitle: 'Put it on your PATH, and plaintake is ready.',
      holdMs: 1_800,
    });
    await term.waitForText(/^plaintake \d/m, { timeoutMs: 10_000 });

    await demo.chapter('Validate');
    await term.run('clear', { id: 'clear', title: 'Clear the screen' });

    await term.run(`plaintake validate ${SCENARIO}`, {
      id: 'validate',
      title: 'Validate before recording',
      subtitle: 'A demo is one TypeScript file. validate checks it before any browser starts.',
      holdMs: 1_800,
    });
    await term.waitForText('validate ok', { timeoutMs: 30_000 });

    await demo.chapter('Record');
    await term.run(`plaintake run ${SCENARIO} --output out --fixture --subtitles hard`, {
      id: 'run-command',
      title: 'One command records',
      subtitle: 'One command films it in Chromium and renders it with FFmpeg.',
      holdMs: 1_800,
    });

    // The run keeps recording in the background while the browser holds the turn.
    await demo.turn(web);
    await demo.chapter('The scenario');

    await web.step({
      id: 'scenario-file',
      title: 'Plain TypeScript',
      subtitle: 'While it records — this is the file it follows, defineDemo and all.',
      target: web.page.locator('#blk-define'),
      action: 'point',
      holdMs: 2_400,
      run: () => Promise.resolve(),
    });

    await web.page.locator('#blk-step').evaluate((el) => el.scrollIntoView({ block: 'center' }));
    await web.step({
      id: 'step-anatomy',
      title: 'Declare each step',
      subtitle: 'A step names its target, its action and the caption you are reading.',
      target: web.page.locator('#blk-step'),
      action: 'point',
      holdMs: 2_600,
      run: () => Promise.resolve(),
    });

    await web.page.locator('#blk-assert').evaluate((el) => el.scrollIntoView({ block: 'center' }));
    await web.step({
      id: 'assert-outcome',
      title: 'Assert the outcome',
      subtitle: 'An assert fails the run if the app ends up in the wrong state.',
      target: web.page.locator('#blk-assert'),
      action: 'point',
      holdMs: 2_400,
      run: () => Promise.resolve(),
    });

    await demo.turn(term.actor);
    await demo.chapter('The bundle');
    await term.waitForText('run ok', { timeoutMs: 120_000 });

    await demo.step({
      id: 'rendered',
      title: 'The run wrote the MP4',
      subtitle: 'Done: one MP4, captions burned in.',
      target: term.getByText('run ok'),
      action: 'point',
      holdMs: 1_800,
      run: () => Promise.resolve(),
    });

    await term.run('ls out', {
      id: 'bundle-tree',
      title: 'More than a video',
      subtitle: 'Captions, a manifest and a trace ship beside it.',
      holdMs: 2_200,
    });
    await term.waitForText('manifest.json', { timeoutMs: 5_000 });

    // The MP4 exists now; load it into the player before cutting to it.
    await web.page.goto(`${baseURL}/watch.html`, { waitUntil: 'load' });
    await web.page.waitForFunction(() => (window as { __demoReady?: boolean }).__demoReady === true, undefined, {
      timeout: 30_000,
    });

    await demo.turn(web);
    await web.click(web.page.getByRole('button', { name: 'Play the recorded demo' }), {
      id: 'watch-output',
      title: 'Watch the actual output',
      subtitle: 'And this is the exact file that run just wrote.',
      holdMs: 1_000,
    });
    await demo.waitFor({
      id: 'output-played',
      title: 'The recorded video played to the end',
      timeoutMs: 60_000,
      until: () =>
        web.page.waitForFunction(() => (window as { __demoEnded?: boolean }).__demoEnded === true, undefined, {
          timeout: 0,
        }),
    });

    await demo.turn(term.actor);
    await term.run('plaintake verify out', {
      id: 'verify',
      title: 'Prove it later',
      subtitle: 'verify re-checks every artifact against the manifest.',
      holdMs: 1_800,
    });
    await term.waitForText('verify ok', { timeoutMs: 30_000 });

    await demo.step({
      id: 'whole-loop',
      title: 'That is the whole loop',
      subtitle: 'Write, validate, run, verify — then ship the video.',
      target: term.getByText('verify ok'),
      action: 'point',
      holdMs: 2_600,
      run: () => Promise.resolve(),
    });
  },
});
