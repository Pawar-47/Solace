# Solace-LowEnd

A shader pack for Minecraft, written for laptops that other packs have left behind.

The target is an Intel Core i3-5005U with Intel HD 5500 graphics and 8 GB of RAM. On
hardware like that, "high quality" is not a setting, it is a budget. So this pack
works the other way round from most: the cheap configuration is the default, and each
effect has a lowest setting that keeps it running rather than switching it off
entirely. If you want everything on at once, the `PerformancePlus` profile does
exactly that — every effect enabled, every sample count at its minimum.

Everything here is one pack: the `shaders` folder next to this file.

## Install

1. Iris 1.5.1 or newer (OptiFine also reads it), Minecraft 1.20–1.21.
2. Drop the `Solace-LowEnd` folder into your `shaderpacks` folder. The game should
   find `shaderpacks/Solace-LowEnd/shaders/`.
3. **Options → Video Settings → Shader Packs → Solace-LowEnd**.
4. Open **Shader Pack Settings** and pick a profile, then tune from there.

## Profiles

| Profile | What it is |
| --- | --- |
| `Potato` | The cheapest pack that still looks shaded: no waves, nothing reflected, no waving, flat grading. For 1366x768 on the iGPU when you want the framerate. |
| `LowEnd` | What the pack ships on, and what it was written for. Waving, gloss, stars and the sun halo, but no water effects — water is where the fill rate goes on an HD 5500. |
| `Default` | Water comes alive: ripples, the sky reflection, the sun glint. Still no extra passes, so the frame cost barely moves from `LowEnd`. |
| `Beauty` | The same frame graded warmer and slower, with temporal AA on. For looking at the picture rather than at the framerate counter. |
| `PerformancePlus` | Every effect enabled at its cheapest sample count: 512 px shadows over 75 blocks with hard taps, four-step reflections and clouds, four AO taps, three-sample shafts and motion blur, four-sample depth of field, slow auto exposure. The heavy end, and it exists so nothing has to be switched off. |

## The options, by screen

The settings menu is grouped rather than one long scroll.

**Water** — waves and their speed and scale, opacity, sky reflection, the sun glint,
refraction (bends what is behind the surface, needs a scene copy), screen-space
reflections and their step count, absorption, and whether the resource pack's water
texture or vanilla's colour wins.

**Geometry** — plant waving and its strength, the cheap directional sun term, torch
light strength and colour temperature, night brightness, the floor under the light in
caves, night vision, held-light, the damage tint, the four material gloss classes and
their strength, and the emissive boost that keeps glowstone and lava from looking
dimmed.

**Shadows** — cast shadows and their resolution and distance, the soft-tap filter and
its spread, coloured shadows, and the refresh lock.

**Sky** — sun and moon halos, stars, volumetric clouds with their sample count, height,
thickness and coverage.

**Ambient occlusion** — on/off, strength, radius, tap count (four or six) and the
distance at which it fades out.

**Bloom** — strength, radius and the mip level the glow is gathered from.

**Depth of field** — on/off, strength, and samples in the ring.

**Antialiasing** — off, temporal, temporal + FXAA, or FXAA alone, with the blend
weight and the edge threshold.

**Motion blur** — on/off, samples, strength.

**Light** — light shafts and their samples and strength, auto exposure and how fast it
follows the scene.

**Fog** — density, and the underwater fog.

**Colour** — exposure, saturation, contrast, the tone curve, red/green/blue channel
gain, output gamma, dithering, chromatic aberration and its strength, sharpening and
its amount. The channel gains and the gamma are what you reach for when the picture is
right but your monitor is not: they cost nothing at their defaults, because the
shader drops both steps from the compiled program at 100.

**Palette** — the theme (eight presets plus custom) and the custom zenith, horizon,
ambient and water colours.

**Accessibility** — the colour-blindness aid and which weakness it helps with.

## What happens each frame

Worth knowing if you are tuning, because it tells you which options cost a pass
rather than a few instructions.

- `prepare` fills the screen with the horizon colour before anything else is drawn.
- The geometry programs (`gbuffers_*`) write colour and depth. Everything expensive
  per pixel lives in shared libraries under `lib/`, so terrain, entities, the hand and
  water cannot drift apart.
- `deferred` copies the finished scene into a second buffer. Water reads that copy for
  refraction and reflections, which is why it lags a frame — that copy is written after
  the water is drawn. It only runs when refraction or reflections are on.
- `composite` draws light shafts and works out the exposure, and only runs when either
  of those is on.
- `composite2` does temporal anti-aliasing and motion blur, and only runs for those.
- `final` applies depth of field, ambient occlusion, bloom, chromatic aberration,
  sharpening, the exposure, the tone curve and the dither, in that order. FXAA runs
  here too, because it needs no history and a whole pass for it would be wasted.

So a "cheap" configuration is two full-screen passes, and the expensive one is four.
Everything else is per-pixel work inside a pass you are already paying for.

## Water, in more detail

Two things are worth understanding because they look like bugs otherwise.

**Refraction measures water thickness, not distance.** The pack compares the depth of
the water surface with the depth of whatever is behind it, so a shallow pool over
stone still shows the stone and a deep ocean goes opaque. If refraction looks wrong,
the usual cause is a scene where the surface and the bottom are at the same depth —
glass over glass, for example.

**Reflections can lag by one frame.** See the `deferred` note above. With temporal
anti-aliasing on, you will not see it. Everything off-screen falls back to the sky
reflection, and the image is folded at the screen edge and faded out rather than
smeared along the border.

## Shadows

Off by default; a second scene render is the most expensive thing a pack can do.

- **Coloured shadows** write the colour of translucent blocks into a second shadow
  target, so stained glass tints the shadow under it and water tints the bed beneath
  it. The light shafts take the same tint.
- **Shadow lock** redraws the shadow pass every N frames instead of every frame. The
  shadow maps are never cleared, so on skipped frames the old map stays put. 64 is a
  sixty-fourth of the shadow cost, at the price of shadows that lag the world a little.

## Distant Horizons and Voxy

Both are supported and neither is required.

- **Distant Horizons**: the far terrain and far water have their own programs in every
  dimension and are shaded by the same libraries as the near world, so the distance
  does not change the colour. Far geometry is projected with the mod's own matrix, and
  the band where the near world fades out is deliberately un-fogged so the two meet
  without a bright seam. Water absorption looks at the far depth buffer too, so an
  ocean over far land is not infinitely deep.
- **Voxy**: the far world goes through Voxy's own fragment entry point and comes out
  with the same palette model. It has no shadow map out there and no reflection
  functions (Voxy does not give a basis for them), which at that distance is the right
  trade.

## The texture files

The ripples and the cloud density are computed in the shader, so the pack works with
no texture files at all. If you want them cheaper, run the generator once:

```bash
cd shaders/textures
python3 generate_textures.py
```

It writes `noise.png`, `clouds.png` and `clouds_blocky.png`, then set `PACK_TEXTURES`
to 1. The water then costs two texture fetches instead of six noise evaluations, and
each cloud sample one fetch instead of two noise octaves. On an HD 5500 that is the
difference between "free" and "noticeable".

The generator is plain Python 3 with no dependencies, and CI runs it on every push and
checks the output, so it cannot rot.

## If something looks wrong

**It will not compile.** Iris names the file and the line. Every program is short and
every include lives in `lib/`, so the message is usually enough. A driver that wants
`#version 330` instead of `#version 120` is the classic complaint — that means editing
the first line of every `.vsh` and `.fsh`.

**It is too dark or too bright.** Start from a profile rather than from defaults, then
move `EXPOSURE` first. `NIGHT_AMBIENT` and `BLOCK_LIGHT` are the two that decide how
night and caves read.

**The water is a mirror, or has no reflection at all.** `WATER_REFLECTION` controls the
sky reflection and `WATER_SSR` the world reflection. SSRs need `deferred` to run, and
`deferred` needs refraction or SSRs to be on.

**Shimmering at a distance.** That is aliasing, not a bug: try `AA_TYPE 1` and give the
temporal pass a moment to settle, or drop the resolution.

**Stutters instead of low frame rate.** Turn `SHADOWS` off first, then `V_CLOUDS`. Both
add work per frame rather than per pixel.

## What is deliberately not here

- **A shadow map on by default**, and no shadow support at all for Distant Horizons
  geometry: one shadow map is enough for a machine this size.
- **Colour grading in Oklab.** The perceptual round trip costs several transcendentals
  per pixel, every frame; at the saturation levels this pack uses, scaling chroma
  around the luma is indistinguishable and far cheaper.
- **A separate pass for bloom or ambient occlusion.** Both run inside `final`, because
  a separate pass would have to read and write the same buffer.
- **Mod block lists.** `block.properties` covers vanilla only. Nothing here needs a mod.

## Layout

```
shaders/
  lib/          shared code: config, maths, colour model, geometry stages, water, AO, shadows
  world0/       the overworld's thin entry points
  world-1/      the Nether's
  world1/       the End's
  lang/         nine languages; English carries the full tooltips
  textures/     the generator for the three optional textures, and their mcmeta files
  block.properties   ten ids: waving, four gloss classes, emissive, portal, water,
                     glass - listed twice, in modern and in pre-1.13 names
  item.properties    items that light the world when held
  entity.properties  the two entity ids the pack reacts to
  shaders.properties profiles, the options screen, pass switches, blend state
```

## Licence

MIT. Do what you like with it.
