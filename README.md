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

Download `Solace-LowEnd.zip` from the [Releases](../../releases) page — the `latest`
release is rebuilt and re-uploaded on every push to `main` — and **copy the zip
itself** into your `shaderpacks` folder, then choose it in **Options → Video Settings →
Shader Packs**. Do not unpack it: the zip already has `shaders/` at its top level,
which is the shape Iris reads.

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

Every release carries four probe zips besides the pack. Each is the real pack with a
family of files removed, so Iris falls back to its own equivalent for those programs
and the zip still loads and still draws. Each one either runs or freezes, and the four
answers together name the file family — no log and no guessing:

- `Solace-Probe-Bare` — two files, a pass-through `final`, and no configuration at
  all. If this freezes, none of the pack's GLSL is involved.
- `Solace-Probe-BareConfig` — those two files plus `shaders.properties`, the languages
  and the block/item/entity/dimension lists. If Bare runs and this freezes, the
  configuration is at fault rather than the shaders.
- `Solace-Probe-PostOnly` — no `gbuffers_*` anywhere: vanilla draws, the pack only
  post-processes.
- `Solace-Probe-Geometry` — no `prepare`, `composite`, `composite2`, `deferred`,
  `final` or `shadow`: the raw geometry buffer goes straight to the screen.

`Solace-Diagnostic.zip` is the whole pack with only the last pass bypassed. It looks
flat and wrong on purpose; it exists for that one answer. [ERRORS.txt](ERRORS.txt) says
which log to send, where it is, and how to collect it in one file. On Linux the
decisive line for a freeze is in the kernel log, not the game log:
`journalctl -k -b | grep -iE "gpu hang|i915|reset"`.

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

Packaging runs on the same trigger. Every push to `main` rebuilds `Solace-LowEnd.zip`
and replaces it on the rolling **latest** release, so the download is always the
current code; the zip is also attached to each run as a workflow artifact. Pushing a
version tag (`v1.0.0`) publishes a release of its own with generated notes.

## Status

The pack is code complete — every effect listed above is implemented, and the
structure is checked on every push.

It now also loads. The cause of a freeze that dogged every earlier build was found by
removing whole families of programs and seeing which combination still froze: the
antialiasing pass read its history buffer and wrote it again inside the same draw,
which is undefined behaviour and, on an Intel driver, a hung GPU. The flag meant to
switch that pass off was written in a form that leaves a pass *enabled* when the
expression cannot be evaluated, so it ran in every profile. The history and exposure
buffers are now flipped so the read and the write are different buffers, and the
switches use the plain form the mods have always been able to evaluate.

What has still not happened is anyone judging the picture: nobody has looked at the
result on real hardware and said whether it is any good. Treat the first run as a
test. Start on `Smooth`.

If something breaks, the two places I would look first are temporal anti-aliasing
(it depends on a history buffer and a reprojection only a real frame can validate)
and the water reflections (they read a copy of the scene that is one frame old by
design).

## Licence

MIT — see [LICENSE](LICENSE). Do what you like with it.
