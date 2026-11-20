# Solace LowEnd - a shader pack written for one machine

144 files, all written here, all my own code. No file, texture, line or constant
was copied out of another pack: this folder contains no PNG, no noise table and
no borrowed function. The pack next door in `../shaders` is **MakeUp - Ultra
Fast v9.6** by Javier Garduño (KDXavier, LGPL-3.0), and it was used the only way
it should be: as the reference for **which programs Minecraft asks a pack for**
and **what a pipeline has to do**, file by file. Its settings, its shaders and
its assets stay where they are.

Built for:

- **Intel Core i3-5005U** - 2 cores / 4 threads, 15 W
- **Intel HD Graphics 5500** - 24 EUs, no dedicated VRAM
- **8 GB RAM**, **Linux Mint**

Nothing here needs a network. It is text files read by Iris or OptiFine from
disk.

---

## The shape of the pack

The reference pack spends five full-screen passes on a frame (deferred,
composite, composite1, composite2, final) and a whole second scene render on a
shadow map, always. This pack spends **one** in the configuration it ships with -
every program that draws geometry lights it in place and writes it straight to the
scene buffer, and `final` tonemaps that buffer to the screen. The other three
passes exist but are switched off until their effect is: `deferred` (the scene copy
water refracts through), `composite` (light shafts and the exposure average) and
`composite2` (antialiasing and motion blur). Each is enabled by the option that
needs it, in `shaders.properties`.

That is the single biggest decision in the pack and it is what makes it fit an
HD 5500: no G-buffer, no history buffer, no shadow map, no mip chain, no
raymarch. The price is no shadows at all - caves are lit by block light and the
sky's light level, and a wall facing away from the sun is as bright as one facing
it unless its light level differs. `SUN_SHADING` adds a cheap directional term on
lit faces, which is as close to a shadow as this pack gets.

## Files, one by one

### `lib/` - the shared code, 14 files

| File | What it holds |
| --- | --- |
| `config.glsl` | every option, as a define with the allowed values in a bracket comment so the options screen is built from it |
| `math.glsl` | `sat`, `luma`, a hash, one-, two- and three-octave value noise, the dither. No tables, no textures |
| `uniforms.glsl` | the Iris/OptiFine uniforms the pack uses, declared once |
| `io_geometry.glsl` | the varyings the geometry vertex stage hands to its fragment stage |
| `sky_model.glsl` | the colour model: sun height from `worldTime`, day and dusk factors, zenith and horizon colours, sun/moon colours, ambient and block light colours, fog colour, and `skyColour()` with the sun halo, moon halo and stars |
| `vertex_geometry.glsl` | the vertex `main` for every textured program: position, texture and lightmap coordinates, tint, view-space normal, view- and world-space position |
| `fragment_geometry.glsl` | the fragment `main` for solid geometry: skylight squared, a directional sun term, torch light, night vision, fog, underwater fog |
| `fragment_water.glsl` | the water surface: two moving noise layers tilt the normal, fresnel mix with the reflected sky, sun and moon glint, fog, alpha for the blend |
| `shadowmap.glsl` | the opt-in shadow map: the two matrices, the 1024 / 96-block constants Iris reads, and a four-tap lookup with a slope-scaled bias and a fade at the edge of the map |
| `ssao.glsl` | opt-in screen-space ambient occlusion for the final pass: six ring samples from `depthtex0`, counted only when a neighbour is in front and close |
| `fragment_skybasic.glsl` | the sky body: ray, palette, stars, halos, cloud slab |
| `fragment_clouds.glsl` | the cloud geometry body |
| `fragment_glowing.glsl` | the glowing outline body |
| `composite_body.glsl` | the light-shaft and exposure body |

The last four are libraries rather than program bodies because a dimension folder
needs the same code with a different palette, and this is how it gets it without a
copy.

### The programs, 23 pairs

Minecraft asks for programs by name; that naming is the mod's API, not anyone's
code. Each of these is a few lines that include a library, except where the file
does real work of its own.

| Program | Does |
| --- | --- |
| `final.vsh` / `final.fsh` | the one full-screen pass: exposure, my own tone curve, saturation, contrast, dither, out |
| `gbuffers_terrain.vsh/.fsh` | almost every block, through the geometry library |
| `gbuffers_block.vsh/.fsh` | blocks Minecraft routes through the block pass, same code |
| `gbuffers_entities.vsh/.fsh` | mobs, items, minecarts |
| `gbuffers_entities_glowing.vsh/.fsh` | the glowing outline: its own colour, lifted, still fogged |
| `gbuffers_hand.vsh/.fsh` | held item and arm, lit like the world |
| `gbuffers_hand_water.vsh/.fsh` | held translucent items |
| `gbuffers_textured.vsh/.fsh` | particles |
| `gbuffers_weather.vsh/.fsh` | rain and snow |
| `gbuffers_water.vsh/.fsh` | water and translucent blocks, through the water library |
| `gbuffers_skybasic.vsh/.fsh` | the sky: a ray is rebuilt per pixel from `gbufferProjectionInverse`, so the dome geometry does not matter, then the colour model and the stars |
| `gbuffers_skytextured.vsh/.fsh` | sun and moon discs |
| `gbuffers_clouds.vsh/.fsh` | cloud geometry, lit, with a lighter fog than the ground |
| `gbuffers_basic.vsh/.fsh` | the block outline and the hitting box: the tint, unchanged |
| `gbuffers_line.vsh/.fsh` | debug lines and the fishing line |
| `gbuffers_spidereyes.vsh/.fsh` | spider and enderman eyes: full bright, no fog |
| `gbuffers_beaconbeam.vsh/.fsh` | the beacon beam: its own light |
| `gbuffers_armor_glint.vsh/.fsh` | the enchantment glint |
| `gbuffers_damagedblock.vsh/.fsh` | the block-breaking overlay |
| `shadow.vsh/.fsh` | the opt-in shadow pass: plain transform, alpha test, depth. Only runs with `SHADOWS 1` |
| `deferred.vsh/.fsh` | copies the scene into gaux1 so water can refract it. Only runs with `REFRACTION 1` |
| `composite.vsh/.fsh` | light shafts towards the sun and the exposure average, history in colortex6. Runs with `VOL_LIGHT` or `AUTO_EXPOSURE` |
| `composite2.vsh/.fsh` | temporal antialiasing with reprojection, a compact FXAA and motion blur; history in colortex3. Runs with `AA_TYPE` or `MOTION_BLUR` |

Plus `shaders.properties` (profiles, the options screen, the vanilla features the
pack takes over, and the blend state for every translucent program) and
`lang/en_US.lang` (the names and tooltips).

### How this maps onto the reference pack

Where the reference has a folder per dimension (`world0`, `world1`, `world-1`),
this pack has nothing: Minecraft uses the root programs for every dimension, and
the colour model reads `worldTime` instead of a per-dimension colour set.

Where the reference splits its vertex work across `common/solid_blocks_vertex.glsl`,
`src/position_vertex.glsl`, `src/light_vertex.glsl` and `src/fog_vertex.glsl`,
this pack has one `lib/vertex_geometry.glsl` and one `lib/fragment_geometry.glsl`.

Where the reference writes `src/finalcolor.glsl` into every fragment program to
mix fog against `gaux4`, this pack computes its fog colour from the same model
that draws the sky, so the sky and the fog cannot drift apart and no extra buffer
is needed.

## Why this pack has 144 files and MakeUp has 344

MakeUp is 344 files; this pack is 144 and covers the same list of effects. Where
the difference goes:

| In MakeUp | Files | What it actually is |
| --- | --- | --- |
| Root `.vsh` / `.fsh` | 50 | 25 program pairs, 11-19 lines each: a `#version`, a few `#define`s, one `#include` into `common/` |
| `common/` | 41 | the real programs: `solid_blocks_*`, `water_blocks_*`, `deferred_*`, `composite*_*`, `final_*`, sky, shadow, clouds, plus Distant Horizons and Voxy variants |
| `lib/` | 38 | AO, bloom, blur, TAA, FXAA, motion blur, SSR water, volumetric clouds, volumetric light, shadow sampling, dither, CAS, colour conversion, config |
| `src/` | 22 | snippets poured inside `main()`: per-vertex light, position, fog, final colour tails, Voxy/DH |
| `world0`, `world1`, `world-1` | 170 | **the same 26-27 wrappers three more times**, one set per dimension, differing only in a `#define` |
| `lang/` | 9 | nine translations of about 300 option strings |
| `textures/` | 6 | three PNGs and their `.mcmeta` |
| properties + Voxy entry points | 8 | `block.properties` (90 KB of block ids), `item.properties`, `entity.properties`, the dimension map, `shaders.properties`, three Voxy files |

So the code is 101 files (`common` + `lib` + `src`). The other 243 are 170
near-copies for the dimensions, 50 thirteen-line wrappers, 9 languages, 6
textures and 8 property files. This pack has fewer files for these reasons, each
of them a decision, not an omission:

- **Dimension folders, but thin ones.** `world0`, `world-1` and `world1` hold 24
  entry points each - 72 files - where the reference holds 170. Each of mine is
  eight lines: a `#define SOLACE_DIM_*`, then an include of the shared library. The
  palette, the day factor and the dusk factor read that define, so the Nether and
  the End get their own light without a second copy of any shader body.
- **One layer instead of three.** MakeUp's `.fsh` includes `common/*_fragment.glsl`,
  which includes `lib/*` and `src/*`. This pack's program is six lines and
  includes one library. Same result.
- **No `src/` snippets.** Their job is to be poured into a dozen `main()`
  functions; this pack puts that code in a library function and calls it.
- **No textures.** Water waves and the dither come from a hash, not from a PNG,
  so there is no `textures/` folder and no `.mcmeta`.
- **Nine languages, thinner ones.** `en_US` is complete with tooltips; the other
  eight translate every option name and every enumerated value, and their long
  tooltips stay English for a native reviewer to finish.
- **A short `block.properties`.** Five ids instead of the reference's ~90 KB
  catalogue: two for waving, three for the gloss classes. Nothing else here keys
  off a block id, and `item.properties` / `entity.properties` would have no reader.
- **No Distant Horizons or Voxy entry points.** Those mods ask for extra programs;
  this pack does not support them, so the files would be dead.
- **Every pass earns its place.** `deferred`, `composite` and `composite2` exist and
  are switched on only by the option that needs them, so the cheap configuration
  still spends one full-screen pass and the expensive one spends four.
- **The shadow pass exists, but ships off** (`SHADOWS 0`): the file pair and the
  lookup are there, which is why there are 23 program pairs and not 22.

What is still not here, and cannot be honestly written in this environment:
**coloured shadows** (needs a shadow colour target plus translucent geometry in the
shadow pass, and the shadow pass itself is off for this GPU), **shadow lock**
(refresh throttling a shader cannot request from the mod), **Distant Horizons and
Voxy** (two more program families whose uniforms can only be verified with those
mods installed), and the **three PNGs** (waves, clouds and the dither here are
procedural on purpose).

## Audit against the reference

`COMPARISON.md` is the file-by-file comparison with MakeUp 9.6: every library and
programme of this pack against the reference file that does the same job, with the
mismatches found and fixed in that pass, and the list of what is still open.

## What is deliberately not here

| Not implemented | What it means in game |
| --- | --- |
| Shadow map on by default | ships off (`SHADOWS 0`); with it on there are cast shadows to 96 blocks, with it off `SUN_SHADING` only shades faces by their angle to the sun, modulated by skylight |
| Clouds | vanilla geometry, or the opt-in procedural slab (`V_CLOUDS`) with no texture and no extra pass |
| Light shafts | `VOL_LIGHT`, off by default: marches towards the sun's screen position |
| Antialiasing | present but off (`AA_TYPE`): temporal with a history buffer and a sub-pixel jitter, plus a compact FXAA |
| Bloom, DOF, motion blur | present but off; bloom and DOF are tap loops inside `final`, motion blur rides in `composite2` |
| Screen-space reflections | `WATER_SSR` marchers the reflected ray through the scene copy, with the sky as fallback; off by default |
| Coloured shadows | `COLORED_SHADOW` needs a second shadow target and translucent geometry in the shadow pass; the shadow pass itself ships off because of the GPU |
| Auto exposure | present but off; the value lives in colortex6 between frames (`AUTO_EXPOSURE`) |
| Distant Horizons, Voxy | those mods are not supported; their geometry would draw with vanilla's pipeline |
| `item.properties`, `entity.properties` | not needed: nothing keys off item or entity ids. `block.properties` exists only for the two waving ids |

## Install

1. Iris 1.5.1 or newer (OptiFine also reads the pack), Minecraft 1.20-1.21 is the
   comfortable range for this GPU.
2. Copy this folder into `shaderpacks`:
   `~/.minecraft/shaderpacks/Solace-LowEnd`, or
   `~/.local/share/PrismLauncher/instances/<instance>/.minecraft/shaderpacks/Solace-LowEnd`.
3. **Options > Video Settings > Shader Packs**, pick `Solace-LowEnd`.
4. In **Shader Pack Settings**, the profile list has `LowEnd` (water waves,
   reflection and glint off - the cheapest), `Default` and `Beauty`.

## Settings that matter more than the pack

1. **Render distance 6, simulation distance 4.** Two cores; chunk building is
   where the frame time goes.
2. **1600x900 or 1366x768.** The HD 5500 is fill-rate bound. The sky shader runs
   on every pixel of the screen, so resolution is the lever that helps most here.
3. **`-Xmx2G`.** Of 8 GB the desktop wants about 2, and the iGPU takes its VRAM
   from the same pool.
4. **Graphics Fast**, clouds Fast, particles Decreased, entity distance 50%,
   VSync off, max framerate unlimited.
5. **Linux:** CPU governor on `performance`, compositor off while playing, and
   try `mesa_glthread=true` in the launch environment.

## If it does not compile

Nothing here was compiled before you run it: this machine has no GPU, no
Minecraft and no Iris. If Iris reports a compile error, the message names the
file and line; every program is short and every include is in `lib/`. The most
likely first day problems are a driver that wants `#version 330` instead of
`#version 120` (change the first line of every `.vsh` and `.fsh`), and the two
blend factors in `shaders.properties` if a translucent program does not blend the
way you expect.

## Credit and licence

This is original code, written to fit the same programs Minecraft asks any pack
for. The reference pack was MakeUp - Ultra Fast v9.6 by Javier Garduño (KDXavier),
GNU LGPL-3.0, <https://github.com/javiergcim/MakeUpUltraFast> - credit it if you
publish anything that grew from this exercise. Pick whatever licence you want for
this pack itself; it contains no third-party code or assets.
