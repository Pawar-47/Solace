# Optimized for max FPS on a Core i3 / integrated graphics

This folder is **MakeUp - Ultra Fast v9.6** by Javier Garduño (KDXavier), tuned
here for an **Intel Core i3-5005U** (2 cores / 4 threads, 15 W), **Intel HD
Graphics 5500** (24 EUs, no dedicated VRAM) and **8 GB of RAM** on **Linux Mint**.

`INVENTORY.md` lists every file in the reference pack, what it does, and what it
costs. `Solace-LowEnd/` is a different thing: a shader pack written from scratch
for this machine, its 48 files mapped out in `Solace-LowEnd/README.md` together
with the install steps and the settings that matter more than the shader.

## Licence and credit

MakeUp is **GNU Lesser General Public License v3.0**. Its README grants use and
modification without restriction and asks for credit plus the official links if
you redistribute it:

- https://modrinth.com/shader/makeup-ultra-fast-shaders
- https://github.com/javiergcim/MakeUpUltraFast
- https://www.planetminecraft.com/mod/makeup-ultra-fast-shader/
- https://www.curseforge.com/minecraft/customization/makeup-ultra-fast-shader

This folder carries the pack's `shaders/` tree plus its `README.md`,
`ParaDesarrolladores.ES.md` and `helpful.txt`; it does not include the upstream
`LICENSE` or `Credits` files, so add them back before redistributing anything
from here.

## Part 1 - the defaults

Every change is a value in `shaders/lib/config.glsl`, plus the profiles and two
pass switches in `shaders/shaders.properties`. No shader logic was rewritten, so
the pack stays updatable and every effect can be switched back on from its own
options screen.

| Option | Was | Now | Why |
| --- | --- | --- | --- |
| `V_CLOUDS` | 1 (volumetric) | 0 (vanilla) | A raymarch at 10 samples per pixel plus cloud reflections: the single largest cost |
| `CLOUD_REFLECTION`, `END_CLOUDS` | on | off | Re-render the cloud layer again |
| `REFLECTION_SLIDER` | 2 (raymarched SSR) | 0 | Ten screen-space raymarch steps on reflective pixels |
| `AA_TYPE` | 2 (TAA + FXAA) | 0 | A history buffer and a full-screen resolve |
| `BLOOM` | on | off | Extra passes and a mipmap chain |
| `AO` | 1 (5 taps) | 0 | With AO off the pack falls back to vanilla's baked AO |
| `AOSTEPS` | 5 | 3 | Only matters if AO is re-enabled |
| `VOL_LIGHT` | 1 (godrays) | 0 | A depth-based screen-space march |
| `GODRAY_STEPS` | 6 | 4 | Same |
| `RAYMARCH_STEPS` | 10 | 5 | Same, for reflections |
| `CLOUD_STEPS_AVG` | 10 | 7 | Same, for volumetric clouds |
| `MATERIAL_GLOSS` | on | off | Per-pixel gloss on metal-like blocks |
| `REFRACTION`, `SUN_REFLECTION` | on | off | Water sampling |
| `COLORED_SHADOW` | on | off | Meaningless without a shadow pass |
| `SHADOW_CASTING` | on | **off** | A whole second scene render: the biggest single saving |
| `SHADOW_QTY_SLIDER`, `SHADOW_DISTANCE_SLIDER` | 2 / 1 | 1 / 0 | So re-enabling shadows is affordable (300 map, 75 blocks) |

`WAVING` went from 1 to 0 as well: plant waving is per-vertex work on every grass
and leaf vertex, which the 15 W CPU has no room for. It is one value to turn back.

Two passes are skipped when nothing in them can run:

- `program.composite1.enabled = BLOOM || DOF` - bloom and depth of field only.
- `program.composite2.enabled = AA_TYPE || MOTION_BLUR` - antialiasing and motion blur only.

A **MAX_FPS** profile at the top of the profile list restores all of this in one
click.

## Part 2 - what was checked in the code, and why it stops here

The obvious next step would be to delete passes. Before doing that, these were
read line by line:

1. **`deferred` cannot be removed.** With AO and volumetric clouds off it is
   almost a pass-through, but it writes `DRAWBUFFERS:14` - colortex**4**, which
   is `gaux4`, the fog colour that **every** block, entity, hand and water pixel
   samples in `src/finalcolor.glsl`. Removing it would break fog everywhere.
2. **`composite` is already lean.** With bloom off it writes `DRAWBUFFERS:16`:
   it does not touch the bloom buffer at all, only the scene and the exposure
   value that `final` tonemaps with.
3. **`final` skips everything it should.** Its second scene fetch, its
   `colortex2` fetch and its shadow/debug fetches all sit inside
   `#if CHROMA_ABER == 1`, `#if AA_TYPE == 3` and `#ifdef DEBUG_MODE` blocks, so
   with this configuration the pass is one fetch plus the tonemap.
4. **The terrain shader is already tight.** `solid_blocks_fragment.glsl` is one
   texture fetch and about twenty instructions: with shadows off the shadow
   lookup collapses to `abs(dayNightMix * 2.0 - 1.0)`, and the ambient-occlusion,
   gloss and material paths are compiled out. Its render-target writes are one or
   two buffers per program.
5. **The one `pow` in `composite` that looked expensive sits inside
   `if (isEyeInWater == 1)`** - a uniform branch, so it costs nothing on land.
   Changing it would have been a fake saving, so it was left alone.

Conclusion: there is no waste left to cut without changing the look. MakeUp's
author guards the expensive work correctly; what remains is four full-screen
passes and roughly one texture fetch per pixel, which is the shape of the pack.

## Part 3 - what is actually left for this machine

Ordered by effect per unit of effort. The first three matter more than anything
that can be done inside the shader.

1. **Resolution.** The HD 5500 is fill-rate bound and its VRAM is system RAM:
   1080p to 1600x900 is about 30% fewer pixels, 1280x720 about 55% fewer, and on a
   laptop panel the difference is hard to see. The largest single lever.
2. **Render distance 6, simulation distance 4.** The i3-5005U has two cores, every
   chunk is CPU work, and the chunk builder is where a frame's time usually goes.
3. **Allocate 2 GB, not more.** Of 8 GB the desktop needs about 2, and the iGPU
   takes its VRAM from the same pool. `-Xmx3G` only if you run many mods; never
   more than that.
4. **Keep the desktop off the frame path.** Compositor effects off, a 1600x900 or
   1366x768 mode, and the CPU governor on `performance`. Iris rather than OptiFine:
   on Linux the pack goes through Mesa, which is far better at this than the
   OptiFine pipeline.
5. **`FOG_ACTIVE` off** - the last real per-pixel saving in the pack. That define
   gates one full-screen `gaux4` fetch on every block pixel; turning it off
   removes the fetch *and* the mix, at the cost of chunks popping at render
   distance with no distance haze. Turn it off to measure, decide with your eyes.
6. If you want beauty back, in this order: `REFLECTION_SLIDER = 1` (flipped-image
   water reflection, one screen read, no raymarch), then `AO = 1` with
   `AOSTEPS = 3`, then `AA_TYPE = 2` if foliage shimmer bothers you, then
   `SHADOW_CASTING` with the sliders left at 1 / 0.

## What has and has not been verified

- Verified by reading the code: the five findings in part 2, that every default
  above is a supported option of this pack, and that each skipped pass contains
  only the work named in its own guard.
- Not verified: framerate on your machine, and how it looks. Nothing here was run
  on a GPU. Measure with F3 before and after, and revert anything you dislike -
  each change is a single value.
