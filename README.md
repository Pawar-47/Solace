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
- Eight colour themes plus a custom one, each with its own ambient light and water
  colour
- Optional: cast shadows (with coloured shadows and a refresh lock), volumetric
  clouds, light shafts, ambient occlusion, bloom, depth of field, temporal
  anti-aliasing, FXAA, motion blur, auto exposure, chromatic aberration, sharpening
- Distant Horizons and Voxy support, so the far world is lit by the same model as
  the near world
- 89 options in fourteen sub-screens, and nine languages

## Requirements

- **Iris 1.5.1 or newer**, or OptiFine
- **Minecraft 1.20 – 1.21** is the comfortable range; older versions load, but the
  block lists only carry modern block names
- No mods required. Distant Horizons and Voxy are optional, and are detected if
  present

## Install

Copy the `Solace-LowEnd` folder into your `shaderpacks` folder so the game finds
`shaderpacks/Solace-LowEnd/shaders/`, then choose it in **Options → Video Settings →
Shader Packs**.

Typical locations:

```
Linux     ~/.minecraft/shaderpacks/
Windows   %APPDATA%\.minecraft\shaderpacks\
Prism     <instance>/.minecraft/shaderpacks/
```

A zip with `shaders/` at its top level works too — that is what a release build
produces.

## Settings that matter more than the pack

1. **Render distance.** Chunk building is what costs the most on two cores. Six is a
   good starting point.
2. **Resolution.** The pack is fill-rate bound, not geometry bound. 1600x900 or
   1366x768 is where an HD 5500 lives.
3. **`-Xmx2G`.** Of 8 GB the desktop wants about 2, and the integrated GPU takes its
   video memory out of the same pool.
4. Start on the `LowEnd` profile, then try `Default`. `Beauty` and `PerformancePlus`
   exist for machines with more headroom.

## Repository layout

```
Solace-LowEnd/            the pack: copy this folder into shaderpacks/
  README.md               its own documentation: options, profiles, troubleshooting
  shaders/                the GLSL, block lists, languages, texture generator
tools/                    the checks that run in CI, also runnable by hand
.github/workflows/        validation on every push, packaging on a version tag
```

## Continuous integration

There is no compiler for GLSL that runs without a GPU, so the checks are structural
and they run on every push:

```bash
python3 tools/validate_pack.py    # includes, preprocessor balance, program pairs, DRAWBUFFERS
python3 tools/check_lang.py       # options against the language files
python3 tools/check_textures.py   # runs the texture generator and verifies its output
```

All three need nothing but Python 3. A red run means a file the game would refuse to
load, or a setting that would show up in the options screen as a raw identifier.

## Status

The pack is code complete — every effect listed above is implemented, and the
structure is checked on every push. What has not happened yet is the one check that
needs a GPU with Minecraft and Iris in front of it: **nobody has looked at the
picture yet**. Treat the first run as a test. Start on `LowEnd`.

If something breaks, the two places I would look first are temporal anti-aliasing
(it depends on a history buffer and a reprojection only a real frame can validate)
and the water reflections (they read a copy of the scene that is one frame old by
design).

## Licence

MIT — see [LICENSE](LICENSE). Do what you like with it.
