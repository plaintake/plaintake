# syntax=docker/dockerfile:1.7
#
# PlainTake in Docker, built on your own machine.
#
#   curl -LO https://github.com/plaintake/plaintake/releases/download/v<version>/plaintake.Dockerfile
#   docker build -t plaintake -f plaintake.Dockerfile .
#   docker run --rm -v "$PWD:/work" plaintake run demo.demo.ts --base-url http://host.docker.internal:3000
#
# A recipe, not a published image, on purpose. PlainTake needs an FFmpeg with libass, and the
# builds that have it are GPL (libx264). PlainTake never redistributes FFmpeg — see NOTICE.md —
# so this file does not contain one: your `docker build` installs it from Ubuntu's archive.
#
# The copy on a release page is stamped with that release's version and the SHA-256 of both
# linux tarballs, and refuses to install anything that does not match. The copy in the
# plaintake/plaintake repository is unstamped and refuses to download at all; take the
# recipe from the release you want.

ARG VERSION=@VERSION@
ARG SHA256_X64=@SHA256_X64@
ARG SHA256_ARM64=@SHA256_ARM64@

# Empty unless the release process overrides it with `--build-context tarballs=<dir>`, which is
# how a release is built and checked from this recipe before its tarballs are public.
FROM scratch AS tarballs

# The same digest-pinned multi-arch index as docker/Dockerfile: one line serves amd64 and arm64,
# and its Chromium is the build PlainTake's vendored Playwright expects.
FROM mcr.microsoft.com/playwright:v1.62.1-resolute@sha256:aebd85bce8056dcdc2269853fd94ea432b6a201da4f0ef125b509489ecd52ddb

ARG VERSION
ARG SHA256_X64
ARG SHA256_ARM64
ARG TARGETARCH
# 1 downloads all voices at build time so a narrated run needs no network; 0 skips them.
ARG VOICE=1

ENV TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Exact apt versions and measured capabilities, identical to docker/Dockerfile (a test keeps the
# two in step). The build fails loudly rather than installing an FFmpeg that renders wrongly.
COPY <<'PACKAGES' /tmp/packages.txt
ffmpeg=7:8.0.1-3ubuntu2
libass9=1:0.17.4-2
locales=2.43-2ubuntu2.4
PACKAGES
COPY <<'ASSERT_CROP_RESIZE' /tmp/assert-crop-resize.sh
#!/usr/bin/env bash
#
# Asserts that this FFmpeg can resize `crop` MID-STREAM under `sendcmd`.
#
# `--camera zoom` needs this and nothing else about the camera is worth checking at image build time,
# because it is the one capability that fails SILENTLY. Measured on Ubuntu noble's FFmpeg
# 6.1.1: `sendcmd` applies `crop`'s `x`/`y` per frame but its `w`/`h` never take, so the
# crop keeps emitting full-size frames, the `scale` that follows becomes a no-op, and the
# video is *panned* instead of zoomed. No error, no warning, the right frame count, and two
# renders still compare byte-identical — it reproducibly renders the wrong picture. That is
# the vacuous pass AGENTS.md §2 records twice, and a grep for the filters cannot catch it:
# both `crop` and `sendcmd` are present and both parse.
#
# A `0.000` command does not discriminate either — it is applied while the graph is still
# being configured, so the output stream reports the cropped size on 6.1.1 too. The command
# has to land after frame 0, and the check has to look at PIXELS.
#
# The method: render the same target geometry twice from one source, once with a static
# `crop` and once driven by `sendcmd` from an identity crop, and compare framehashes of the
# frames after the command. If the mid-stream resize works the two are identical.
set -euo pipefail

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A box off to one side, so a crop that pans without zooming lands it somewhere a crop that
# zooms does not — the two failure modes are then distinguishable rather than merely different.
src="color=white:s=640x360:r=30:d=1,drawbox=x=420:y=60:w=60:h=60:color=black@1:t=fill"

printf '0.500 crop x 320;\n0.500 crop w 320;\n0.500 crop h 180;\n' > "$work/cam.cmd"

# Frames from 0.6s on: after the command, and clear of it.
hash_of() {
  ffmpeg -hide_banner -loglevel error -f lavfi -i "$src" \
    -vf "$1,scale=640:360:flags=lanczos,setsar=1,select='gte(t\,0.6)'" \
    -fps_mode passthrough -f framehash -hash md5 - | grep -v '^#'
}

static=$(hash_of "crop=w=320:h=180:x=320:y=0")
driven=$(hash_of "sendcmd=f=$work/cam.cmd,crop=w=640:h=360:x=0:y=0")

if [ -z "$static" ]; then
  echo "assert-crop-resize: the static reference produced no frames; the probe itself is broken" >&2
  exit 1
fi

if [ "$static" != "$driven" ]; then
  echo "assert-crop-resize: FAILED — sendcmd cannot resize crop mid-stream in this FFmpeg." >&2
  echo "  This build applies crop's x/y per frame but not its w/h, so '--camera zoom' would" >&2
  echo "  silently render a pan instead of a zoom. Measured broken on 6.1.1, working on 8.0.1." >&2
  ffmpeg -hide_banner -version | head -1 >&2
  exit 1
fi

echo "assert-crop-resize: ok — sendcmd resizes crop mid-stream ($(ffmpeg -hide_banner -version | head -1 | cut -d' ' -f3))"
ASSERT_CROP_RESIZE
COPY <<'ASSERT_AAC' /tmp/assert-aac.sh
#!/usr/bin/env bash
#
# Asserts that this FFmpeg can encode AAC — the capability, not a proxy for it.
#
# Narration needs it: a narrated bundle's frozen arguments say `-c:a aac`, the base encode writes
# the audio and the `soft` variant stream-copies it, so a build without the encoder cannot
# render one at all.
#
# Why this is not a `-buildconf` grep, which is how libass and libx264 are checked two lines
# above the call site. **AAC is native to FFmpeg**, so there is no `--enable-` flag for it to
# be missing from — a build with `--disable-encoder=aac` reports a buildconf indistinguishable
# from a working one. `parseHasLibass`'s technique cannot answer this question.
#
# Why it is not a `-encoders` grep either, which is what `parseHasAac` does in TypeScript for
# `doctor`. A listing says a name is present; it does not say the encoder initialises, links
# its dependencies, or produces a decodable stream. This is the same M16 lesson as the
# crop/resize assertion — a capability gate must assert the capability — applied one feature later and for a tenth of
# the cost, because unlike a mid-stream crop resize this one takes a quarter of a second.
#
# The method: encode a known tone to AAC in an MP4, then read the result back with ffprobe and
# require that it is an `aac` stream at the rate and channel count the render plan freezes.
# `-ac 1` on a mono source is one stream either way, so the properties are checked and not the
# count — the same reason `audioProblems` checks properties rather than counting streams.
set -euo pipefail

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 24 kHz mono: exactly what `writeSpeechTrack` produces and what `plan.speech` declares.
if ! ffmpeg -hide_banner -loglevel error \
      -f lavfi -i 'sine=frequency=440:duration=0.25:sample_rate=24000' \
      -ac 1 -c:a aac -b:a 96k "$work/probe.mp4" 2>"$work/err"; then
  echo "assert-aac: FAILED — this ffmpeg cannot encode AAC, so a narrated bundle cannot be rendered." >&2
  echo "  AAC is native to ffmpeg, so this build must have disabled it explicitly." >&2
  sed 's/^/  /' "$work/err" >&2
  ffmpeg -hide_banner -version | head -1 >&2
  exit 1
fi

read -r codec rate channels < <(
  ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_name,sample_rate,channels \
    -of csv=p=0 "$work/probe.mp4" | tr ',' ' '
)

if [ "$codec" != "aac" ] || [ "$rate" != "24000" ] || [ "$channels" != "1" ]; then
  echo "assert-aac: FAILED — the encode succeeded but produced ${codec} ${rate}Hz ${channels}ch," >&2
  echo "  not the aac 24000Hz 1ch a frozen render plan declares. A bundle rendered here would" >&2
  echo "  carry an audio stream that does not match its own manifest of what it contains." >&2
  exit 1
fi

echo "assert-aac: ok — aac 24000Hz mono ($(ffmpeg -hide_banner -version | head -1 | cut -d' ' -f3))"
ASSERT_AAC
# Ubuntu's archive rotates: the ".3" build of `locales` above already vanished, replaced by
# ".4", and nothing stops the same happening to `ffmpeg` or `libass9` between one user's
# `docker build` and the next. A recipe pinned to exact versions but drawn only from the LIVE
# archive has a shelf life measured in Ubuntu's own package churn, not in this repository's
# release cadence — the opposite of what "pinned" is supposed to buy, and the whole reason this
# file is a recipe a user builds themselves rather than an image PlainTake ships once.
#
# The fix is `APT::Snapshot`, written into an apt config FILE below rather than passed as a
# `--snapshot=<ts>` flag on one command. That distinction is the entire fix: a flag only affects
# the ONE apt invocation it is given to. Measured directly — give it only to `apt-get update` and
# a later, flagless `apt-get install` (the very next command in a recipe like this one) resolves
# exactly as if snapshotting were never configured, from whatever the live archive's index
# happens to hold at that moment. That defeats the feature on the one day it is meant to matter:
# once Ubuntu has actually rotated a pin away from the live archive, a flagless install has
# nothing frozen left to fall back on. An apt.conf.d file, by contrast, is read by every apt
# invocation that follows it in this image — the `apt-get update` and `apt-get install` below,
# and the verification after them — with no flag to forget on any one of them.
#
# What `APT::Snapshot` does once active is also stronger than "prefer the snapshot, fall back to
# live," which is what this comment used to claim. Measured directly, with only this option set
# and no other change: `apt-cache policy` and `apt-cache showpkg` stop seeing ANY version from a
# source whose host has no snapshot mapping, even though that source's index was fetched to disk
# moments earlier by the very same `apt-get update` and is not stale. Live is not "tried first"
# here; for a mapped host it is not consulted for resolution at all, snapshot or no snapshot
# available — which is exactly what keeps this build reproducible against the frozen timestamp
# instead of quietly sliding back to whatever the live archive carries the day someone runs
# `docker build`. It also means the mapping below is load-bearing, not an optional widening of
# coverage: this base image's arm64 sources use `azure.ports.ubuntu.com` (Microsoft's regional
# mirror of the ports archive, baked in at the digest pinned above), and apt's built-in snapshot
# host table has no entry for it — only for `archive.ubuntu.com` and its subdomains and for
# `security.ubuntu.com`, which is what amd64's sources use and needs no override. Measured
# directly: on arm64, `APT::Snapshot` active with no mapping for its host does not fall back to
# a normal live install — every package on that host, including ones already installed, drops out
# of `apt-cache policy` entirely, and the same `apt-get install` line that succeeds with the
# mapping in place fails outright without it (`Unable to locate package ffmpeg`, `Version ... for
# 'locales' was not found`). The `Acquire::Snapshots::URI::Host::...` line below adds that one
# mapping. It also encodes a fact measured directly rather than assumed: snapshot.ubuntu.com
# serves every architecture under `/ubuntu/`, not a separate `/ubuntu-ports/` (that path answers
# 401). The mapping is harmless on amd64 — `azure.ports.ubuntu.com` never appears in its sources,
# so it matches nothing there, and amd64's own host is already covered by the built-in wildcard.
#
# Confirmed directly against this pinned base image, arm64 native and amd64 emulated: with the
# config below in place, deleting the live archive's own list files after `apt-get update` and
# then running this file's exact, flagless `apt-get install` line still resolves and installs all
# three pins — proof the install step, not only the update step, reads the frozen mirror. Without
# the config, the identical sequence fails outright on both architectures (`E: Unable to locate
# package ffmpeg`, `Version '2.43-2ubuntu2.4' for 'locales' was not found`, exit 123) — proof the
# check discriminates rather than passing either way. The `apt-cache policy` loop after the
# install below is the same measurement, kept in the build itself: it fails loudly if a future
# edit to this file, or a future apt, ever stops resolving these three packages through the
# snapshot, rather than silently installing whatever the live archive happens to have that day.
ARG APT_SNAPSHOT=20260925T000000Z
RUN <<'APT_SNAPSHOT_CONF'
#!/usr/bin/env bash
set -euo pipefail
# Read by every apt-get/apt-cache call below, update through the verification loop, rather than
# by one flagged command — see the comment above for why that is the entire fix. Removed with
# the other build-only files at the end of the RUN chain below, so nothing in the shipped image
# keeps resolving against a timestamp that will itself be stale the day someone opens a shell in
# a container built from it and reaches for apt.
cat > /etc/apt/apt.conf.d/99plaintake-snapshot <<CONF
APT::Snapshot "$APT_SNAPSHOT";
Acquire::Snapshots::URI::Host::azure.ports.ubuntu.com "https://snapshot.ubuntu.com/ubuntu/@SNAPSHOTID@/";
CONF
APT_SNAPSHOT_CONF
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive xargs -a /tmp/packages.txt \
      apt-get install -y --no-install-recommends \
 && for pkg in ffmpeg libass9 locales; do \
      apt-cache policy "$pkg" | grep -q 'snapshot\.ubuntu\.com' || { \
        echo "apt-cache policy $pkg: no snapshot.ubuntu.com source for the installed version -- the snapshot config above has stopped taking effect, so this exact pin is no longer guaranteed once Ubuntu's live archive rotates it away" >&2; \
        apt-cache policy "$pkg" >&2; \
        exit 1; \
      }; \
      echo "apt-cache policy $pkg: resolves via snapshot.ubuntu.com"; \
    done \
 && ffmpeg -hide_banner -buildconf | grep -q -- --enable-libass \
 && ffmpeg -hide_banner -buildconf | grep -q -- --enable-libx264 \
 && ffmpeg -hide_banner -filters | grep -qE '^\s*[A-Z.]{2,3}\s+ass\s' \
 && ffmpeg -hide_banner -filters | grep -qE '^\s*[A-Z.]{2,3}\s+crop\s' \
 && ffmpeg -hide_banner -filters | grep -qE '^\s*[A-Z.]{2,3}\s+sendcmd\s' \
 && bash /tmp/assert-crop-resize.sh \
 && bash /tmp/assert-aac.sh \
 && locale-gen en_US.UTF-8 \
 && locale -a | grep -q en_US \
 && rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99plaintake-snapshot /tmp/packages.txt /tmp/assert-crop-resize.sh /tmp/assert-aac.sh

COPY --from=tarballs / /tmp/tarballs/

# The same two steps as install.sh — unpack the tree, link the binary — with the digest check
# in front. Node, not curl, for the download: curl is already on this base image
# (/usr/bin/curl — measured directly, not assumed), so nothing would need adding to reach for
# it, but its version is whatever Microsoft's image happens to ship, unpinned, in a file whose
# every apt package is pinned deliberately (see the snapshot comment above). Node is pinned the
# same indirect way every other runtime fact here is — recorded in docker/README.md rather than
# asserted — and it is already required for `plaintake` itself, so this reaches for what is
# already a dependency instead of a second HTTP client with no version story of its own.
# `NODE_USE_ENV_PROXY=1` because Node's fetch ignores `HTTP_PROXY`/`HTTPS_PROXY` by default;
# without it, a build behind a corporate proxy would fail the download with no explanation.
RUN <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail
case "$TARGETARCH" in
  amd64) arch=x64; sum="$SHA256_X64" ;;
  arm64) arch=arm64; sum="$SHA256_ARM64" ;;
  *) echo "PlainTake has no linux build for $TARGETARCH (only amd64 and arm64)." >&2; exit 1 ;;
esac
case "$VERSION" in
  @*) echo "This recipe is unstamped. Download plaintake.Dockerfile from a release page:" >&2
      echo "  https://github.com/plaintake/plaintake/releases" >&2
      exit 1 ;;
esac
name="plaintake-$VERSION-linux-$arch.tar.gz"

# Refuses before any download is attempted, not just before the digest check further down: a
# `--build-arg VERSION=1.23.0` on the unstamped repo copy passes the check above (VERSION no
# longer looks like a placeholder) while SHA256_X64/SHA256_ARM64 are untouched, so `$sum` is
# still `@SHA256_...@`. Without this, the build would reach the network, download a full
# tarball, and only then fail — on a missing /tmp/tarballs/SHA256SUMS, since the digest check
# below has nothing else to check an unstamped `$sum` against. The one case that is not a
# refusal is a local tarball already staged (`--build-context tarballs=<dir>`, how a release
# checks itself before it is stamped): that has its own SHA256SUMS to verify against instead.
case "$sum" in
  @*)
    [ -f "/tmp/tarballs/$name" ] || {
      echo "This recipe is unstamped. Download plaintake.Dockerfile from a release page:" >&2
      echo "  https://github.com/plaintake/plaintake/releases" >&2
      exit 1
    }
    ;;
esac

if [ -f "/tmp/tarballs/$name" ]; then
  tarball="/tmp/tarballs/$name"
else
  tarball="/tmp/$name"
  url="https://github.com/plaintake/plaintake/releases/download/v$VERSION/$name"
  echo "downloading $url"
  NODE_USE_ENV_PROXY=1 node --input-type=module -e '
    const [url, out] = process.argv.slice(1);
    const res = await fetch(url);
    if (!res.ok) { console.error(`download failed: ${res.status} ${url}`); process.exit(1); }
    const { writeFile } = await import("node:fs/promises");
    await writeFile(out, Buffer.from(await res.arrayBuffer()));
  ' "$url" "$tarball"
fi

case "$sum" in
  @*)
    # Unstamped recipe with local tarballs: a development build. Check against the SHA256SUMS
    # beside them instead, and never without one.
    ( cd /tmp/tarballs && grep -F "  ./$name" SHA256SUMS | sha256sum -c - )
    ;;
  *)
    # A stamped `$sum` is trusted enough to hand straight to `sha256sum -c`, which happily
    # "verifies" a malformed line by finding no match and exiting non-zero — but a `$sum` that
    # is empty, truncated, or corrupted some other way during templating deserves a clear
    # refusal here rather than a confusing one from sha256sum two lines down.
    [[ "$sum" =~ ^[0-9a-f]{64}$ ]] || {
      echo "This recipe's SHA256 for linux-$arch is not a sha256 digest: $sum" >&2
      exit 1
    }
    echo "$sum  $tarball" | sha256sum -c -
    ;;
esac

mkdir -p /opt/plaintake
# Not `tar -xzf ... --strip-components=1`, measured on this pinned base image: its tar (Ubuntu
# 26.04, glibc 2.43) imports openat2@GLIBC_2.43 and reaches for it on every member below the
# archive's top level, and Docker Desktop's amd64 emulation on Apple Silicon (Rosetta) answers
# openat2 with ENOSYS — so under `--platform linux/amd64` on a Mac, every nested entry failed
# with "Function not implemented" and the build died mid-extract. Native amd64 hardware
# implements the syscall and never sees this; the emulated build is a real path anyway — it is
# what `scripts/check-recipe.sh`'s amd64 leg runs, and what any Docker Desktop user gets if
# they build that platform explicitly. python3 already ships on this base image (measured,
# /usr/bin/python3) and its tarfile writes through the plain openat/mkdirat every emulator
# implements; its output was verified identical to tar's on a release tarball — same paths,
# modes, types and per-file digests.
python3 - "$tarball" /opt/plaintake <<'PY'
import sys, tarfile

archive, dest = sys.argv[1], sys.argv[2]

def parts_of(name):
    return [p for p in name.split('/') if p not in ('', '.')]

with tarfile.open(archive) as tf:
    members = tf.getmembers()
    # One root directory, asserted rather than assumed: the tarball's shape is this project's
    # own build output, and a change to it should fail the build here rather than extract
    # something subtly different from what the recipe below expects at /opt/plaintake.
    roots = {parts_of(m.name)[0] for m in members if parts_of(m.name)}
    if len(roots) != 1:
        sys.exit(f'archive has {len(roots)} root directories: {sorted(roots)}')
    keep = []
    for m in members:
        ps = parts_of(m.name)
        if len(ps) <= 1:
            continue  # the single root directory itself
        m.name = '/'.join(ps[1:])
        keep.append(m)
    # filter='data' keeps what tar refuses too: no absolute paths, no .. traversal, no device
    # nodes, no links escaping the destination.
    tf.extractall(dest, members=keep, filter='data')
PY
ln -s /opt/plaintake/bin/plaintake /usr/local/bin/plaintake
install -d -o pwuser -g pwuser /work
rm -rf /tmp/tarballs "/tmp/$name"
plaintake --version
INSTALL

# Chromium's sandbox cannot run as root; running as pwuser keeps it on.
USER pwuser

RUN if [ "$VOICE" = "1" ]; then plaintake install-voice --all-voices; fi

WORKDIR /work
ENTRYPOINT ["plaintake"]
CMD ["--help"]
