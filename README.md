# Solace

A Minecraft shader pack built for hardware that most packs have given up on.

Solace is written for one specific machine: an Intel Core i3-5005U with Intel HD
5500 graphics, 8 GB of RAM and no dedicated GPU. That constraint decided almost
everything in it. Every effect has a setting that keeps it on at the cheapest
possible cost, the expensive ones ship switched off, and the whole thing is arranged
so you can trade frame rate for looks one step at a time instead of choosing between
"pretty" and "playable".

There is one pack here, `Solace-LowEnd`. The name is honest: it is tuned downwards,
not upwards.

## What it does

- Sun, moon, sky gradient and fog all come from one colour model, so nothing ever
  disagrees with anything else
- A stylised diffuse model with a de-biased lightmap, a candle curve for block
  light, and fake shadows built from sky exposure — detailed-looking lighting without
  a shadow map
- Water with ripples, a sky reflection, a sun glint, and optional depth-aware
  refraction and screen-space reflections
- Eight colour presets plus a custom one, each with its own ambient light and water
  colour: Natural, Vivid, Game, Soft, Cinematic, Neon, Warm and Bright
- Sun and cloud controls: the sun's arc across the sky, its size and halo shape,
  separate red/green/blue gains for sunlight, and four cloud styles from soft noise to
  vanilla flat, with their own drift speed
- Optional: cast shadows (with coloured shadows and a refresh lock), volumetric
  clouds, light shafts, ambient occlusion, bloom, depth of field, temporal
  anti-aliasing, FXAA, motion blur, auto exposure, chromatic aberration, sharpening
- Distant Horizons and Voxy support, so the far world is lit by the same model as
  the near world
- 103 options in fifteen sub-screens, and nine languages
- Five profiles, named for what you get: `Potato`, `Smooth`, `HD`, `HDR`, `Everything`

## Requirements

- **Iris 1.5.1 or newer**, or OptiFine
- **Minecraft 1.20 – 1.21** is the comfortable range. Older versions load too: the
  block lists carry both the modern names and the pre-1.13 ones
- No mods required. Distant Horizons and Voxy are optional, and are detected if
  present

## Install

Download `Solace-LowEnd-v<version>.zip` — the asset is named for the release it belongs
to, so `Solace-LowEnd-v2.0.4.zip` is that build and nothing else — from the newest release
on the [Releases](../../releases) page, and **copy the zip itself** into your
`shaderpacks` folder, then choose it in
**Options → Video Settings → Shader Packs**. Do not unpack it: the zip already has
`shaders/` at its top level, which is the shape Iris reads.

There are two kinds of release. **Versions** (`1.0.0`, `1.1.0`) are builds that passed
every check and are never rewritten — recommend these. **Preview** is the current build
of `main`, rewritten on every push, so there is always something to test while a version
is not yet worth cutting. It is labelled a pre-release and says which commit it was
built from. [CHANGELOG.md](CHANGELOG.md) says what changed and when.

If you would rather have a folder, unpack it and rename the result to `Solace-LowEnd`,
so the game finds `shaderpacks/Solace-LowEnd/shaders/`. Copying the `Solace-LowEnd`
folder out of this repository works the same way.

Typical locations:

```
Linux     ~/.minecraft/shaderpacks/
Windows   %APPDATA%\.minecraft\shaderpacks\
Prism     <instance>/.minecraft/shaderpacks/
```

### If it freezes

[ERRORS.txt](ERRORS.txt) says which log to send, where the game keeps it, and how to
collect it in one file. On Linux the decisive line for a freeze is in the kernel log,
not the game log: `journalctl -k -b | grep -iE "gpu hang|i915|reset"`.

If you want to narrow it down without a log — which is how the freeze in this pack was
eventually found — the **Diagnose** workflow builds a set of probe packs on demand.
Each is the real pack with a family of programs removed; Iris substitutes its own
program for anything missing, so each still loads and still draws, and each one either
runs or freezes. Read together the answers name a file. They are attached to the
workflow run as artifacts and are never published as releases.

## Settings that matter more than the pack

1. **Render distance.** Chunk building is what costs the most on two cores. Six is a
   good starting point.
2. **Resolution.** The pack is fill-rate bound, not geometry bound. 1600x900 or
   1366x768 is where an HD 5500 lives.
3. **Java: 3 GB, minimum equal to maximum.** `-Xms3G -Xmx3G` with the G1 flags, not
   more — on 8 GB the desktop and the integrated GPU need the rest, and heap does not
   raise frame rate, only smooth out hitching. All of it, with copy-paste arguments,
   swap and the BIOS setting: [docs/linux-jvm.md](docs/linux-jvm.md).
4. Profiles, named for what they cost you: `Potato` (holds 60 fps at 1366x768),
   `Smooth` (what the pack ships on, and what it was written for), `HD` (water comes
   alive, plus ambient occlusion and a cloud deck), `HDR` (shadows, bloom, auto
   exposure and temporal AA), `Everything` (every effect at its cheapest samples).

## Repository layout

```
Solace-LowEnd/            the pack: copy this folder into shaderpacks/
  README.md               its own documentation: options, profiles, troubleshooting
  shaders/                the GLSL, block lists, languages, texture generator
docs/linux-jvm.md         heap, JVM flags, swap and the iGPU on 8 GB / Mint XFCE
tools/                    the checks that run in CI, also runnable by hand
.github/workflows/        validation on every push, packaging and the latest release
```

## Continuous integration

There is no compiler for GLSL that runs without a GPU, so the checks are structural
and they run on every push:

```bash
python3 tools/validate_pack.py    # includes, preprocessor balance, program pairs, DRAWBUFFERS
python3 tools/check_lang.py       # options against the language files
python3 tools/check_textures.py   # runs the texture generator and verifies its output
python3 tools/compile_check.py    # glslang on every stage, under every profile
```

The first three need nothing but Python 3; the fourth needs `glslang-tools`, because
it compiles the pack for real. A red run means a file the game would refuse to load,
or a setting that would show up in the options screen as a raw identifier.

Publishing is separate from that. The **Release** workflow runs on a `v*` tag, or by hand
with a version number, and publishes that **version** — never rewritten, always built
after all four checks including the compiler. Running it by hand with the version box
empty publishes a **preview** of `main` instead, as a pre-release. A push to `main` does
not publish anything on its own: the release page carries versions, and a test build is
something asked for.

The **Diagnose** workflow builds the diagnostic and probe packs on demand and attaches
them to the run as artifacts, and the **Delete every release** workflow is the reset that
removes every release, every tag and every workflow artifact — the code is untouched, so
a clean release page can be built on the same commits.

## Status

The pack is code complete — every effect listed above is implemented, every stage
compiles under seven option sets with a real GLSL front end, and the structure is
checked on every push.

The audit is in [AUDIT.md](AUDIT.md): first against the working pack — every file of ours
against its counterpart — and then against the specification itself, the official Iris
documentation, kept here as
[docs/Iris-Shaderpack-Tutorial.md](docs/Iris-Shaderpack-Tutorial.md). Eight defects came
out of the first pass, twelve out of the second, and a third that walked the pack file by
file found two more in the Distant Horizons path. Three of them were enough on their own
to stop the pack loading: a buffer read and written inside one draw in every profile, a
`worldN` folder layout that kept `final`, `composite2`, `deferred` and `shadow` from
running in any dimension, and `gl_ModelViewProjectionMatrix`, which is not one of the
legacy built-ins the mods rewrite and was in eleven vertex stages.

The picture has been looked at once, on the machine this pack was written for. 1.0.0
loaded and stopped freezing, and showed a set of faults in the colour and sky model that
nothing in this repository can catch - a rectangle where the sun should be, an ambient
term taken straight from the sky's blue, and water that was flat paint. They are listed
and fixed in [CHANGELOG.md](CHANGELOG.md) under 1.0.1. Start on `Smooth`.

If the game freezes, the **Diagnose** workflow builds one zip per post-chain program,
each the whole pack minus exactly that file; the removal that makes it load names the
culprit, and that is the fastest way back to a fix.


## Licence

MIT — see [LICENSE](LICENSE). Do what you like with it.
