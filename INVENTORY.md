# local Solace - everything in the folder, studied

This is a complete inventory of the project as it stands and a study of what each
part does and costs, written offline: no page, repository or archive was fetched
for it, and every statement below comes from the files in this folder (the pack's
own `README.md` and `ParaDesarrolladores.ES.md`, the header of each shader, and
the `#include` graph).

Totals: **344 files under `shaders/`**, plus 4 documents and one archive at the
top level, and `Solace-LowEnd/` with 51 files of shader code written from scratch
for this machine - it shares no file and no line with the pack above, which was
used only as the guide to which programs Minecraft asks for.

---

## 1. Top level

| Path | Lines / size | What it is |
| --- | --- | --- |
| `README.md` | 34 | MakeUp - Ultra Fast **v9.6** readme: feature list, tested hardware, LGPL-3.0 grant to use, fork and modify, credit ask |
| `ParaDesarrolladores.ES.md` | 109 | The author's own explanation (Spanish) of the four folder kinds (`common`, `lib`, `src`, `worldX`) and of the draw flow and buffer assignment. Primary source for sections 2-4 below |
| `helpful.txt` | 30 | Minecraft commands kept by hand: dimension teleports, `doDaylightCycle`, effects, moon phases. Not read by the shader |
| `Shader.zip` | 538 KB | The archive of the pack as it was provided |
| `OPTIMIZED.md` | 114 | Tuning notes for this machine, with the code checks behind them |
| `INVENTORY.md` | this file | The inventory and study |
| `shaders/` | 344 files | The pack itself |
| `Solace-LowEnd/` | 48 files + `README.md` | A shader pack written from scratch for the i3-5005U / HD 5500 / 8 GB machine; the pack above is only its guide to which programs exist |

The upstream publisher's `LICENSE` and `Credits` files are **not** in this folder;
`README.md` carries the licence text and links instead. Anything redistributed
from here needs those two files added back.

---

## 2. The pack, in one paragraph

MakeUp is a **single-buffer forward pack**. It does not build a G-buffer of
normals/depth for a lighting pass; `gbuffers_*` programs light and shade the
geometry themselves, in one texture fetch, and write straight into `colortex1`.
Everything after that is screen-space: `deferred` (AO and clouds), `composite`
(auto exposure, volumetric light, bloom preparation), `composite1` (bloom, DOF),
`composite2` (AA, motion blur), `final` (aberration, exposure, tonemap, output).
The pack targets OptiFine and Iris 1.5.1+, Minecraft 1.12 through 26.x, and the
author's own note in `ParaDesarrolladores.ES.md` describes the buffers and the
nine-step flow that sections 3 and 4 follow.

---

## 3. Buffers (as `ParaDesarrolladores.ES.md` documents them)

| Buffer | Format | Role |
| --- | --- | --- |
| `colortex0` | R11F_G11F_B10F | Bloom auxiliary; `composite2` also writes the final AA/motion-blur result here |
| `colortex1` | R11F_G11F_B10F (RGBA16 with DOF) | The scene. Sky, geometry, water, then every full-screen pass |
| `colortex2` | R8 | Reserved; only bound in `shaders.properties` when a blue-noise texture is uncommented |
| `colortex3` | R11F_G11F_B10F (RGBA16 with DOF) | TAA history |
| `gaux1` | R11F_G11F_B10F | Scene copy for screen-space reflections, then the bloom chain |
| `gaux2` | R8 | Cloud map (bound to `textures/clouds_*_512_R_8bit.png`) |
| `gaux3` | R16F | Previous auto-exposure value |
| `gaux4` | - | Sky colour used as the fog colour; sampled by every block, entity and hand pixel through `src/finalcolor.glsl` |

`noisetex` is `textures/water_256_RG_8bit.png` (RG holds the water normal, the
third component is computed).

---

## 4. The passes, and which ones still run here

Order of a frame, with the state of this configuration:

| # | Pass | `Render:` in its header | State here |
| --- | --- | --- | --- |
| 1 | `prepare` | Sky | runs: sky colour to `colortex1` + `gaux4` |
| 2 | `gbuffers_skybasic`, `gbuffers_skytextured` | Sky, sun/moon | runs |
| 3 | `gbuffers_terrain`, `_entities`, `_entities_glowing`, `_block`, `_hand`, `_hand_water`, `_textured`, `_weather`, `_beaconbeam`, `_armor_glint`, `_basic`, `_line`, `_damagedblock`, `_spidereyes`, `_clouds` | Almost everything / Droped objects, mobs / Glow objects / ... | runs |
| 4 | `deferred` | Ambient occlusion, volumetric clouds | runs, but both effects are off: it still writes `colortex4` (gaux4), the fog colour every block pixel samples |
| 5 | `gbuffers_water` | Water and translucent blocks | runs, reflections and refraction off |
| 6 | `composite` | Bloom and volumetric light | runs: auto exposure and the exposure write; bloom and godrays off |
| 7 | `composite1` | Bloom and DoF | **skipped**: `program.composite1.enabled = BLOOM || DOF` |
| 8 | `composite2` | Antialiasing and motion blur | **skipped**: `program.composite2.enabled = AA_TYPE || MOTION_BLUR` |
| 9 | `final` | Final renderer | runs: tonemap + exposure. Its extra fetches are inside `#if CHROMA_ABER == 1`, `#if AA_TYPE == 3` and `#ifdef DEBUG_MODE` |
| - | `shadow`, `dh_terrain`, `dh_water` | Shadowmap / DH Terrain / DH Water | **never run**: `program.shadow.enabled = SHADOW_CASTING` (off) and the DH pair needs Distant Horizons |

So a frame costs geometry plus **three** full-screen passes (`deferred`,
`composite`, `final`) instead of five.

---

## 5. Root wrappers - 25 programs, 50 files

Every `gbuffers_*.fsh` / `*.vsh` at the root of `shaders/` is a thin wrapper: a
`#version` line, a header comment, a few `#define`s that select the dimension or
the behaviour, and one `#include` into `common/`. That is why the wrappers are
11-19 lines each and the real programs are in `common/`.

| Program | Fragment includes | Draws |
| --- | --- | --- |
| `prepare` | `common/prepare_fragment.glsl` | sky gradient, writes fog colour |
| `gbuffers_skybasic` | `common/skybasic_fragment.glsl` | stars, void, sky effects |
| `gbuffers_skytextured` | `common/skytextured_fragment.glsl` | sun, moon |
| `gbuffers_terrain` | `common/solid_blocks_fragment.glsl` | almost all blocks |
| `gbuffers_block` | `common/solid_blocks_fragment.glsl` | blocks drawn in the block pass |
| `gbuffers_entities` | `common/solid_blocks_fragment.glsl` | dropped items, mobs |
| `gbuffers_entities_glowing` | `common/solid_blocks_fragment.glsl` | glowing entities |
| `gbuffers_hand` | `common/solid_blocks_fragment.glsl` | held opaque object |
| `gbuffers_hand_water` | `common/solid_blocks_fragment.glsl` | held translucent object |
| `gbuffers_textured` | `common/solid_blocks_fragment.glsl` | particles |
| `gbuffers_weather` | `common/solid_blocks_fragment.glsl` | rain, snow |
| `gbuffers_beaconbeam` | `common/solid_blocks_fragment.glsl` | beacon beam |
| `gbuffers_water` | `common/water_blocks_fragment.glsl` | water, stained glass, translucents |
| `gbuffers_armor_glint` | `common/glint_blocks_fragment.glsl` | enchantment glint |
| `gbuffers_basic` | `common/basic_blocks_fragment.glsl` | hitboxes, outlines |
| `gbuffers_line` | `common/line_blocks_fragment.glsl` | debug lines, fishing line |
| `gbuffers_damagedblock` | `common/damage_fragment.glsl` | block-breaking overlay |
| `gbuffers_spidereyes` | `common/spidereyes_blocks_fragment.glsl` | spider/enderman eyes |
| `gbuffers_clouds` | `common/clouds_blocks_fragment.glsl` | vanilla-style cloud geometry |
| `deferred` | `common/deferred_fragment.glsl` | AO + volumetric clouds |
| `composite` | `common/composite_fragment.glsl` | exposure, volumetric light, bloom prep |
| `composite1` | `common/composite1_fragment.glsl` | bloom, DOF |
| `composite2` | `common/composite2_fragment.glsl` | AA, motion blur |
| `final` | `common/final_fragment.glsl` | aberration, tonemap, output |
| `shadow` | `common/shadow_fragment.glsl` | shadowmap fill |

Each `.vsh` counterpart includes `/common/<name>_vertex.glsl`, which pulls the
shared vertex chunks from `src/` (position, light, fog, write-buffers).

---

## 6. `shaders/common` - 41 files, the actual programs

Seventeen fragment/vertex pairs, plus the Distant Horizons and Voxy variants:

| Pair | Does |
| --- | --- |
| `solid_blocks_*` (302 / 215 lines) | the main geometry program: one texture fetch, per-vertex light, shadow lookup, fog, gloss/material paths |
| `water_blocks_*` (321 / 154) | water surface: normals from `noisetex`, refraction, reflection, absorption; the heaviest fragment program of the pack |
| `deferred_*` (200 / 59) | ambient occlusion, volumetric clouds, and the fog-colour write to gaux4 |
| `composite_*` (242 / 111) | auto exposure, volumetric light, bloom preparation, underwater handling |
| `composite1_*` (73 / 12) | DOF and bloom application |
| `composite2_*` (156 / 12) | TAA/FXAA and motion blur |
| `final_*` (168 / 29) | chromatic aberration, exposure, tonemap, colour-blindness help, output |
| `skybasic_*` (96 / 68) | procedural sky and stars |
| `skytextured_*` (48 / 50) | sun/moon quads |
| `clouds_blocks_*` (38 / 40) | cloud geometry colours |
| `prepare_*` (57 / 37) | sky gradient, fog-colour seed |
| `shadow_*` (32 / 47) | shadowmap write |
| `basic_blocks_*` (15 / 54) | outlines/hitboxes |
| `line_blocks_*` (13 / 29) | lines |
| `glint_blocks_*` (20 / 28) | glint |
| `damage_*` (17 / 26) | breaking overlay |
| `spidereyes_*` (18 / 27) | eyes |
| `solid_dh_blocks_*` (82 / 70) | Distant Horizons terrain |
| `solid_dh_water_*` (231 / 92) | Distant Horizons water |
| `solid_voxy_blocks_fragment` (220) | Voxy terrain (no separate vertex file; the Voxy vertex maths is `src/voxy_position_light.glsl`) |
| `water_voxy_blocks_fragment` (223) | Voxy water |
| `voxy.json` (37) | the Voxy bridge: uniform list, samplers, `opaqueDrawBuffers: [1, 4]`, `translucentDrawBuffers: [1]` |

---

## 7. `shaders/lib` - 38 files, declarations and functions (included outside `main`)

| File | Role |
| --- | --- |
| `config.glsl` (331) | **every user option**, then the derived constants: reflection mode, AO level, shadow map size and distance, cloud steps, godray steps, `NETHER_SIGHT`, the twelve shadow-slider combinations |
| `water.glsl` (325) | water shading: normals, refraction, reflection, absorption (largest library) |
| `water_dh.glsl` (135), `water_voxy.glsl` (198) | the same for Distant Horizons and Voxy geometry |
| `dither.glsl` (235) | ordered and blue-noise dithering; largest single lib |
| `fxaa.glsl` (204) | FXAA 3.11 |
| `fast_taa.glsl` (185) | TAA history, neighbourhood clamp, selective blending |
| `color_conversion.glsl` (156) | RGB/HSV/luma conversions |
| `color_utils.glsl` (181) | overworld sky and light colour computation |
| `color_utils_end.glsl` (49), `color_utils_nether.glsl` (45) | per-dimension colour sets |
| `shadow_frag.glsl` (154) | shadow sampling with blur (PCF) |
| `volumetric_light.glsl` (117) | godrays march (its header still says `volumetric_clouds.glsl`) |
| `volumetric_clouds.glsl` (106), `_end` (98), `_vertex` (51) | the cloud raymarch and its plane setup |
| `ao.glsl` (46) | ambient-occlusion taps used by `deferred` |
| `bloom.glsl` (34), `blur.glsl` (36) | bloom chain and the separable blur under it |
| `cas.glsl` (41) | AMD FidelityFX contrast-adaptive sharpening (AMD copyright header), behind `IMAGE_SHARPENING` |
| `aberration.glsl` (17) | chromatic aberration offsets |
| `color_blindness.glsl` (40) | colour-blindness correction |
| `tone_maps.glsl` (19) | tonemap operators |
| `luma.glsl` (13), `vector_utils.glsl` (17), `basic_utils.glsl` (73) | small shared maths |
| `day_blend.glsl` (41) | day/sunset/night weights |
| `depth.glsl` (9), `depth_dh.glsl` (9) | linearised depth |
| `end_portal.glsl` (71) | end portal and gateway effect |
| `motion_blur.glsl` (34) | reprojection motion blur |
| `material_gloss_fragment.glsl` (28), `_voxy` (28) | gloss on metal/sand/fabric block classes |
| `mu_ftransform.glsl` (18) | the pack's own replacement for the old fixed-function transform |
| `post.glsl` (9), `projection_utils.glsl` (15), `projection_utils_voxy.glsl` (15) | post-chain and projection helpers |
| `shadow_vertex.glsl` (20) | shadow projection |

---

## 8. `shaders/src` - 22 files, snippets poured **inside** `main`

| File | Role |
| --- | --- |
| `light_vertex.glsl` (136), `light_vertex_dh.glsl` (96) | per-vertex light: blocklight, skylight, AO mix, held-light, emissive classes |
| `position_vertex.glsl` (87) | final `gl_Position` plus the TAA sub-pixel offset |
| `position_vertex_dh.glsl` (24), `position_vertex_water.glsl` (15) | the same for DH and for water |
| `fog_vertex.glsl` (56), `fog_vertex_dh.glsl` (9) | fog distance in the vertex stage |
| `finalcolor.glsl` (44) | the shared tail of every geometry fragment: fog mix against gaux4, then the buffer writes |
| `finalcolor_dh.glsl` (17), `finalcolor_voxy.glsl` (17) | the same tails for DH and Voxy |
| `cloudfinalcolor.glsl` (16) | cloud pixel tail |
| `hi_sky.glsl` (18), `hi_sky_voxy.glsl` (21) | high-detail sky gradient |
| `low_sky.glsl` (18), `low_sky_voxy.glsl` (21) | cheap sky gradient |
| `writebuffers.glsl` (37) | the `DRAWBUFFERS` list each program uses |
| `shadow_src_vertex.glsl` (38) | vertex side of the shadow pass |
| `taa_offset.glsl` (30) | applies the `taaOffset` uniform computed in `shaders.properties` |
| `basiccoords_vertex.glsl` (9), `basiccoords_vertex_dh.glsl` (7) | coordinates for basic/line programs |
| `voxy_position_light.glsl` (74), `voxy_uniforms_replace.glsl` (18) | Voxy vertex transform and uniform substitution |

---

## 9. `shaders/textures` - 6 files

| File | What |
| --- | --- |
| `water_256_RG_8bit.png` + `.mcmeta` (67 KB) | RG water normal map bound to `noisetex`; the `.mcmeta` frames it as a tiling/animated texture |
| `clouds_natural_512_R_8bit.png` + `.mcmeta` (91 KB) | cloud density for `CLOUD_VOL_STYLE == 0`, bound to `gaux2` |
| `clouds_blocky_512_R_8bit.png` + `.mcmeta` (6 KB) | cloud density for `CLOUD_VOL_STYLE == 1` |

Only the water map and the natural cloud map are used here: `V_CLOUDS` is 0 and
`CLOUD_VOL_STYLE` is 0.

---

## 10. `shaders/lang` - 9 files

`en_US` (305), `es_ES` (305), `es_AR` (305), `es_MX` (305), `ko_KR` (304),
`ru_RU` (305), `sv_SE` (303), `tr_TR` (300), `zh_CN` (305). They give a display
name and a tooltip to every option in `config.glsl`; an option with no entry
shows its raw name.

---

## 11. Dimension folders - `world0` 58, `world1` 57, `world-1` 55

`dimension.properties` maps them: `world0 = minecraft:overworld`,
`world-1 = minecraft:the_nether`, `world1 = minecraft:the_end`. Any other
dimension falls back to the root wrappers.

Each folder repeats the 26-27 wrappers of the root, with one difference: the
`#define`s that select the dimension and the colour set (end clouds, nether fog,
`UNKNOWN_DIM` for custom dimensions) before including the same `common/` file.
They are not duplicate code, only duplicate entry points - which is why the pack
needs ~55 files per dimension for programs that share their bodies.

Differences worth knowing:
- `world-1` has **no** `shadow` pair - the Nether never casts shadows.
- `world0` carries its own `entity.properties` (lightning bolt only).
- `world0` and `world1` carry `shadow.fsh`/`.vsh`, which `program.shadow.enabled`
  keeps switched off here.
- Several headers in these copies are wrong, copied from a sibling: in `world0`,
  `world1` and `world-1`, `gbuffers_block.fsh` says "Render: Beacon beam",
  `gbuffers_line.fsh` says `gbuffers_line.vsh`, and `composite2.vsh` says
  `composite1.fsh`. They are comments only; nothing reads them.

---

## 12. The property files

| File | Lines | What |
| --- | --- | --- |
| `shaders.properties` (235) | options | The user interface: `screen.*` layouts, the `sliders` list, the profiles, the custom-uniform chain (`dayMixer`, `dayNightMixer`, `taaOffset`, `softLod`, `fovYInverse`), the `program.*.enabled` switches, texture bindings, DH blending |
| `block.properties` (102) | ~90 KB of very long lines | Block → `ENTITY_*` id map. Only 102 lines because each line is a whole block list; the ids are the ones `config.glsl` names (10008 water, 10018 leaves, 10031 grass-like, 10079 glass, 10089/10090 emissive, 10175/10176 tall plant halves, 10400/10410/10440 gloss classes, ...) |
| `item.properties` (5) | 2 lines of items | Held-item light classes: `11001` normal light, `11002` low light |
| `entity.properties` (10) | - | `10101` lightning bolt, `10201` entity flames (Iris), `10202` glowing entity |
| `dimension.properties` (3) | - | the dimension mapping above |
| `voxy.json` (1), `voxy_opaque.glsl` (4), `voxy_translucent.glsl` (4), sub-folder `voxy.json` files | - | Voxy mod entry points: `<dim>/voxy.json` includes `/common/voxy.json`; the two `.glsl` define `VOXY_BLOCK` / `VOXY_WATER` and include the Voxy fragment programs |

---

## 13. What each lever costs on an HD 5500, and where it stands

| Lever | Where | Now | Cost if enabled |
| --- | --- | --- | --- |
| `SHADOW_CASTING` | `config.glsl` | off | a second scene render, the largest single cost |
| `V_CLOUDS` | `config.glsl` | 0 (vanilla) | a raymarch per pixel plus a cloud reflection pass |
| `REFLECTION_SLIDER` | `config.glsl` | 0 | up to ten screen-space raymarch steps per reflective pixel |
| `AA_TYPE` / `MOTION_BLUR` | `config.glsl` | 0 / off | a history buffer, a full-screen resolve, `composite2` |
| `BLOOM` / `DOF` | `config.glsl` | off / off | `composite1` and a mipmap chain |
| `AO` | `config.glsl` | 0 | `AOSTEPS` depth taps per pixel in `deferred` |
| `VOL_LIGHT` / `RAYMARCH_STEPS` | `config.glsl` | 0 / 5 | a depth-based march per pixel |
| `CLOUD_STEPS_AVG` | `config.glsl` | 7 (minimum) | samples per cloud pixel |
| `MATERIAL_GLOSS`, `COLORED_SHADOW`, `REFRACTION`, `SUN_REFLECTION`, `CHROMA_ABER`, `IMAGE_SHARPENING` | `config.glsl` | all off | per-pixel work in the geometry or post programs |
| `WAVING` | `config.glsl` | **0** (was 1) | per-vertex animation on every grass and leaf vertex |
| `FOG_ACTIVE` | `config.glsl` | on | one `gaux4` fetch and a mix on every block pixel; `profile.lowend_hd5500_nofog` turns it off for comparison |
| `composite1`, `composite2` | `shaders.properties` | skipped | two full-screen passes |

---

## 14. Two files here that are not the pack

- `Shader.zip` - the archive the pack arrived in.
- `OPTIMIZED.md` and this file - written in this project, not part of MakeUp.

Everything else in `shaders/` is the pack's own content: the Voxy and Distant
Horizons files (`voxy*`, `solid_dh_*`, `water_dh.glsl`, `*_dh.glsl`,
`*_voxy.glsl`) and the three dimension folders are files MakeUp v9.6 ships, not
anything added here.

---

## 15. What was and was not verified

- Read line by line: `config.glsl`, `shaders.properties`, the fragment include
  graph of all 105 wrapper programs, and the header of every shader.
- Cross-checked: `ParaDesarrolladores.ES.md` against the buffers and passes it
  describes, and every option in `config.glsl` against the `screen.*` and
  `sliders` lists in `shaders.properties`.
- Not run: nothing here was compiled or rendered. There is no GPU, no Minecraft
  and no Iris in this environment, so framerate on the i3-5005U is unmeasured and
  the pack's first launch on your machine is the real test.
