# Audit: this pack against MakeUp - Ultra Fast 9.6

Method: for each file here, the reference file that does the same job was read and
both compared on *what the program must do* - uniforms, buffers, order of steps.
Nothing was copied; where the reference file is long it is long for effects of its
own, and those are the rows at the end.

State: **144 files** against 344 there: 23 program pairs, 14 libraries, three
dimension folders of 24 entry points each, `block.properties`,
`dimension.properties`, `shaders.properties`, and nine language files, with 62
options. Every programme Minecraft asks for exists, in every folder the platform
asks for it in; every effect in the reference's README exists here.

---

## 1. Pipeline and buffers

| Pass | Buffer written | Reads | Runs when |
| --- | --- | --- | --- |
| `gbuffers_*` | colortex0 | - | always |
| `deferred` | colortex4 (gaux1) | colortex0 | `REFRACTION` or `WATER_SSR` |
| `composite` | colortex1 + colortex6 (gaux3) | colortex0, depthtex0, colortex6 | `VOL_LIGHT` or `AUTO_EXPOSURE` |
| `composite2` | colortex0 + colortex3 | colortex1, colortex3, depthtex0 | `AA_TYPE` or `MOTION_BLUR` |
| `shadow` | shadow map | - | `SHADOWS` |
| `final` | screen | colortex0 or colortex1 (whichever is current), colortex6, depthtex0 | always |

`final` picks its input with the same options that switched earlier passes on, so
no pass reads the buffer it writes - the equivalent of the reference's buffer dance
(scene in colortex1, AA result in colortex0, exposure in gaux3).

## 2. Libraries

| Mine | Reference equivalent | Verdict |
| --- | --- | --- |
| `lib/config.glsl` (114) | `lib/config.glsl` (331) + `day_blend.glsl` (41) | 62 options: shadow sliders, palette themes, custom colours, gloss, water toggles. **Open:** shadow lock, coloured-shadow switch |
| `lib/math.glsl` (61) | `basic_utils.glsl`, `vector_utils.glsl`, `luma.glsl`, `dither.glsl` (235) | Hash, value noise, random dither; no tables, no blue-noise PNG |
| `lib/uniforms.glsl` (39) | declared per file there | Declares once, with previous-frame matrices |
| `lib/io_geometry.glsl` (26) | declared per file there | Varyings and the five block-id constants, shared by both stages |
| `lib/sky_model.glsl` (176) | `color_utils*.glsl` (181 + 49 + 45), `day_blend.glsl` | `themePalette()` for the eight themes and the custom slot, `palette()` for the dimension override, night/dusk derived from whichever is active |
| `lib/vertex_geometry.glsl` (61) | `solid_blocks_vertex.glsl` (215), `position_vertex.glsl` (87), `light_vertex.glsl` (136), `fog_vertex.glsl` (56) | Transform, lightmap, tint, normal, block id, waving, TAA jitter |
| `lib/fragment_geometry.glsl` (97) | `solid_blocks_fragment.glsl` (302), `src/finalcolor.glsl` (44) | Skylight^2, sun, torch, night vision, held light, damage tint, gloss, fog, underwater fog |
| `lib/fragment_water.glsl` (151) | `water_blocks_fragment.glsl` (321), `lib/water.glsl` (325) | Waves, fresnel reflection, SSR march, glint, refraction with absorption, water-texture and vanilla-water toggles, fog |
| `lib/fragment_skybasic.glsl` (75) | `skybasic_fragment.glsl` (96) | Sky, palette, stars, halos, procedural cloud slab |
| `lib/fragment_clouds.glsl` (33) | `clouds_blocks_fragment.glsl` (38) | Cloud geometry shading |
| `lib/fragment_glowing.glsl` (32) | `glint`/glowing path | The glowing outline |
| `lib/composite_body.glsl` (91) | `composite_fragment.glsl` (242) | Light shafts and the exposure average |
| `lib/shadowmap.glsl` (83) | `shadow_frag.glsl` (154), `shadow_vertex.glsl` (20), `src/shadow_src_vertex.glsl` (38) | Resolution/distance/blur from the sliders, soft or hard taps, slope-scaled bias, edge fade |
| `lib/ssao.glsl` (63) | `lib/ao.glsl` (46) | Six depth taps in `final` instead of a deferred pass |

The four `lib/fragment_*.glsl` and `composite_body.glsl` files exist for one
reason: a dimension folder needs the same body with a different palette, and a
library is the only way to have both without copying the code.

## 3. Programmes

| Mine | Reference equivalent | Verdict |
| --- | --- | --- |
| `final.fsh` (151) | `common/final_fragment.glsl` (168) | DOF, aberration, sharpening, AO, bloom, exposure, tone curve, colour-blind aid, saturation, contrast, dither |
| `composite.fsh` (6, body in a library) | `common/composite_fragment.glsl` (242) | Light shafts and the exposure average |
| `composite2.fsh` (127) | `composite2_fragment.glsl` (156), `fast_taa.glsl` (185), `fxaa.glsl` (204), `motion_blur.glsl` (34) | TAA with reprojection and a neighbourhood clamp, compact FXAA, motion blur |
| `deferred.fsh` (23) | `deferred_fragment.glsl` (200) | Scene copy for refraction and reflections |
| `shadow.*` (19/21) | `shadow.*` + `common/shadow_*` | Transform, alpha test, depth |
| `gbuffers_*` (18 root pairs) | root wrappers + `common/*` | Same job, one include layer instead of three |
| `world0/`, `world-1/`, `world1/` (24 each) | three folders of 26-27 wrappers, 170 files | Same mechanism, thinner: 8-line entry points that set `SOLACE_DIM_*` and include the library |
| `shaders.properties` (55) | `shaders.properties` (235) | Profiles, screen, blend, four pass switches |
| `block.properties` (21) | `block.properties` (~90 KB) | Five ids: plants, leaves, metal, polished, fabric. Vanilla only |
| `dimension.properties` (7) | `dimension.properties` (3) | The same three mappings, with a comment |
| `lang/*.lang` (9) | nine files of 300-305 | `en_US` complete with tooltips; the other eight translate every option name and every enumerated value, tooltips stay English |

## 4. Every fix a pass found

Pass 1: `entityColor` missing; `heldBlockLightValue` unused; no waving; fixed
four-tap shadow; `#if` on a float; `max(vec3, float)`; `gl_NormalMatrix`
dependency; mismatched alpha-test thresholds.

Pass 2: no pass could read what it wrote; buffer formats for the histories; jitter
multiplied by `w`; camera delta in the reprojection; history clamped to the 3x3
neighbourhood; DOF moved into `final`; a duplicated DOF block removed; refraction
reads the copy, not the scene; absorption applied to the refracted colour; cloud
slab early-outs.

Pass 3: block-id constants were invisible to the fragment stage (`io_geometry.glsl`
now holds them); one `palette()` function so no theme can drift; ambient light
follows the palette; shadow constants from sliders; SSR on the copy that already
exists; water base colour became a choice.

Pass 4 (this one): the sky, cloud, glowing and composite bodies were inline in their
root programs, so a dimension could not reuse them without a copy - they are
libraries now. The three dimension folders then became 24 eight-line entry points
each instead of 24 copies of every body, and `dimension.properties` documents the
mapping.

## 5. What is left

| Missing | Reference | Why it is not here |
| --- | --- | --- |
| Coloured shadows | `lib/shadow_frag.glsl`, a shadow colour buffer, translucent geometry in the shadow pass | needs a second colour target and a translucent shadow pass; the shadow pass itself ships off because of the GPU |
| Shadow lock | `SHADOW_LOCK` | refresh throttling a shader cannot request from the mod |
| Distant Horizons, Voxy | 2 program families, 7 libraries, 3 json | their uniforms and program names can only be verified with those mods installed; written blind they would be code nobody can trust |
| Water and cloud PNGs | 3 PNGs + `.mcmeta` | assets; waves, clouds and the dither here are procedural on purpose |

**Unverified:** nothing was compiled or run - no GPU, Minecraft or Iris in this
environment. The four optional passes are the least proven part; TAA first, then
SSR. The dimension folders only change a `#define`, so if the Nether or the End
look wrong, the palette in `sky_model.glsl` is the one place to look.


## 6. Line-by-line pass against the reference programs

Read side by side, line by line: `common/solid_blocks_vertex.glsl` (215),
`common/solid_blocks_fragment.glsl` (302), `common/final_fragment.glsl` (168) and
`common/composite2_fragment.glsl` (156) - 841 lines - plus `lib/config.glsl` (331)
and `shaders.properties` (235) read earlier for the option surface. Every finding
below was checked against my own file and fixed.

| # | Reference behaviour | What my pack did | Verdict |
| --- | --- | --- | --- |
| 1 | `prepare` writes the background before the sky and geometry | no `prepare` at all, so a pixel nothing covered kept the previous frame | **Error, fixed**: `prepare.vsh/.fsh` added, filling the scene with the horizon colour |
| 2 | declares `colortex3Clear = false`, `gaux3Clear = false` and the formats, so the AA and exposure histories survive between frames | nothing declared, so Iris cleared those buffers every frame and neither history could converge | **Serious error, fixed**: `lib/buffers.glsl` holds the formats and clear flags, included by every program that touches them |
| 3 | reprojects with `depthtex1`, the depth that includes translucents | used `depthtex0`, so water and glass reprojected against the ground behind them | **Error, fixed** in `composite2.fsh` |
| 4 | FXAA-only mode (`AA_TYPE == 3`) runs inside `final` | spent a whole composite2 pass on it | **Waste, fixed**: FXAA moved into `final`, `program.composite2.enabled` now only for temporal AA and motion blur |
| 5 | the TAA sub-pixel offset comes from `src/taa_offset.glsl` inside `position_vertex`, so **every** program including the sky jitters | only the geometry programs jittered; the sky and the sun/moon stood still, so every edge against them smeared | **Error, fixed** in `gbuffers_skybasic.vsh` and `gbuffers_skytextured.vsh` |
| 6 | the glowing outline is drawn with `gl_Position.z *= 0.01` so it cannot z-fight the model | no offset | **Error, fixed**: `SOLACE_ENTITY_GLOW` define in the shared vertex library |
| 7 | weather halves its alpha (`blockColor.a *= .5`) | full texture alpha, so rain and snow read too solid | **Error, fixed** with the `SOLACE_WEATHER` define |
| 8 | rain dims direct sunlight by `1.0 - rainStrength * 0.75` | rain only dimmed the sky colour, so the sun stayed at full strength in a storm | **Error, fixed** in the sun term |
| 9 | emissive classes (glowstone, lava, lanterns) are never dimmed | no emissive class: those blocks could go dark in a shadow | **Gap, fixed**: id 6 in `block.properties` and a `max()` floor on the lit colour |
| 10 | `isEndPortal` + `src/end_portal.glsl` render the animated portal surface | nothing; the portal drew as an ordinary block | **Gap, fixed**: id 7 and a procedural swirl, no texture |
| 11 | waving grows from `mc_midTexCoord` upwards, so a plant bends at its base | used `1.0 - texcoord.y`, which slides the whole plant | **Error, fixed**: `mc_midTexCoord` attribute, clamped from the texture middle up |
| 12 | night vision tints as well as brightens (`mix(blockColor, NV_COLOR)`) | only added light, so night vision came out grey | **Gap, fixed**: `NV_COLOR_R/G/B` options |
| 13 | clamps the scene before it enters the post buffers (`vec3(50.0)`) | no clamp, so a stray Inf could spread through bloom and the AA history | **Error, fixed** in `composite` and `composite2` |

Kept as a deliberate difference, not an error:

- The reference's `SELECTIVE_TAA_V2` writes an object mask into colortex2 and runs
  FXAA over entities instead of temporal blending. This pack has no mask buffer; it
  clamps the history to the current 3x3 neighbourhood instead, which is a cheaper
  proxy for the same thing - weaker on fast-moving entities, and one buffer lighter.
- The reference's `custom_sigmoid()` is its tone map; this pack has its own monotone
  curve plus a `TONEMAP` choice. Different curve, same place in the pipeline.
- The reference keeps its exposure in a varying computed in the composite vertex
  stage; this pack samples the one-texel value in `final`. One fetch instead of a
  varying, same result.
- Coloured shadows (`COLORED_SHADOW`, `shadowcolor0` with an `RGBA8` format) are
  still not here: the shadow pass ships off for this GPU and the tint is only
  visible through translucent casters, which needs a translucent shadow pass.

## 7. Nothing is dropped for being expensive: the PerformancePlus profile

The request was not to omit heavy effects but to make them affordable, so every one
of them has a minimum setting and the profile turns them all on at once:

| Effect | Cheap setting used by `PerformancePlus` |
| --- | --- |
| Cast shadows | 512 px map, 75 blocks, hard (1-tap) lookups |
| Volumetric clouds | 4 steps, low coverage |
| Water reflections | 4-step march |
| Refraction | on, one scene copy pass |
| Ambient occlusion | 4 taps |
| Bloom | 8 taps, small radius |
| Depth of field | 4 samples |
| Antialiasing | temporal only, 0.93 history weight |
| Motion blur | 3 samples, half strength |
| Light shafts | 3 samples |
| Auto exposure | slow adaptation |

`AO_TAPS`, `CLOUD_STEPS`, `SSR_STEPS`, `VOL_LIGHT_SAMPLES`, `MOTION_BLUR_SAMPLES`,
`DOF_SAMPLES` and the two shadow sliders are all exposed, so each heavy effect can be
traded down instead of switched off.


## 8. Second line-by-line pass: the lighting model and the shadow sampler

This time the reference files read line by line were `src/light_vertex.glsl` (136),
`src/finalcolor.glsl` (44), `src/taa_offset.glsl` (30) and `lib/shadow_frag.glsl`
(154) - on top of the 841 lines of the first pass - and compared against my
`lib/vertex_geometry.glsl`, `lib/fragment_geometry.glsl`, `lib/fragment_water.glsl`,
`lib/fragment_clouds.glsl` and `lib/fragment_glowing.glsl`.

The lighting model was the weakest part of my pack, and these are the eight
discrepancies it had against the reference, all now fixed:

| # | Reference, line by line | Mine before | Fix |
| --- | --- | --- | --- |
| 14 | `light_vertex.glsl:5` - `illumination.y = max(y - 0.065, 0) * 1.0695` de-biases the vanilla lightmap so the sky channel truly runs 0..1 | used `lmcoord.y` raw, so my sky term never reached zero and caves were lit too much | de-bias applied in the geometry, water, and both sky/cloud paths that read a lightmap |
| 15 | `light_vertex.glsl:18` - candle curve `x*sqrt(x) + sixthPow(1.17x)`, clamped to 4 | `blockLight * blockLight` (a plain square), so torch pools were too dark in the middle and too small | the same curve shape adopted in geometry and water |
| 16 | `light_vertex.glsl:51` - `directLightStrength = mix(-astro, astro, dayNightMix)`: at night the **moon** is the light | always used `sunPosition`, which points below the horizon at night, so moons cast no light at all | `astroDir = normalize(mix(moonPosition, sunPosition, dayFactor()))`, and the moon's colour at night |
| 17 | `light_vertex.glsl:115-130` - with no shadow map the direct term is multiplied by `visibleSky` to the tenth power | multiplied by `skyLight^2`, so sunlight leaked into caves and under every tree | `sky^10` built from three squarings, no `pow` |
| 18 | `light_vertex.glsl:68-86` - leaves take a softened direct term (`*0.5+0.5`, then `*0.75`) because a leaf block is not a wall | leaves were lit like stone, so canopies looked like solid roofs | foliage branch on the leaves id |
| 19 | `light_vertex.glsl:98-105` - ambient has an `AVOID_DARK_LEVEL` floor, mixed in by sky visibility | `ambient * sky^2`, which is exactly zero in a cave | ambient floor of 0.045 mixed by `sky^2` |
| 20 | `src/finalcolor.glsl:36-44` - blindness and the Warden's `darknessFactor` darken with distance | neither effect existed; the Warden's darkness did nothing | both applied in the geometry and water colour, uniforms declared without a version guard |
| 21 | `src/position_vertex` + `src/fog_vertex` - the fog amount is computed **per vertex** and only mixed per pixel | `exp()` per pixel in every geometry, water and cloud program | `fogFactor` varying computed once in `lib/vertex_geometry.glsl`, mixed in the fragment stage |

Also confirmed as matching, line for line: the TAA offset pattern is the same
alternating ±0.5-pixel dance (`src/taa_offset.glsl:9-26`), the shadow bias is
slope-scaled in both, and `src/finalcolor.glsl`'s fog mix against a buffer is the
one structural choice I kept different on purpose - this pack derives the fog colour
from the same model that draws the sky instead of reading `gaux4`, which is one
buffer less and one fetch less per pixel.

Still open after this pass, and honestly labelled so: the shadow sampler here is four
fixed taps against the reference's dither-rotated two-radius PCF
(`lib/shadow_frag.glsl:12-31`), coloured shadows need `shadowtex0`/`shadowcolor0`
(154 lines of that file), `SELECTIVE_TAA_V2` needs an object mask, and
`Distant Horizons` / `Voxy` remain out because they cannot be verified here.


## 9. File by file: every file in this pack, against its counterpart

How each row was compared:

- **read** - the reference file was read from the first line to the last and
  compared statement by statement against mine. 18 reference files, 2,575 lines:
  `lib/config.glsl` (331), `shaders.properties` (235), `common/solid_blocks_vertex.glsl`
  (215), `common/solid_blocks_fragment.glsl` (302), `common/final_fragment.glsl`
  (168), `common/composite2_fragment.glsl` (156), `common/composite_fragment.glsl`
  (242), `common/composite1_fragment.glsl` (73), `common/deferred_fragment.glsl`
  (200), `common/skybasic_fragment.glsl` (96), `common/prepare_fragment.glsl` (57),
  `common/shadow_fragment.glsl` (32), `common/shadow_vertex.glsl` (47),
  `src/light_vertex.glsl` (136), `src/finalcolor.glsl` (44), `src/taa_offset.glsl`
  (30), `src/position_vertex.glsl` (87), `lib/shadow_frag.glsl` (154).
- **structure** - compared by the `#include` graph, the `DRAWBUFFERS` of every
  program (all 17 occurrences in the pack), and the header scan of every shader, not
  by reading every line. Full line reads of these are listed as still to do at the
  end.

| My file | Reference counterpart | How | Verdict |
| --- | --- | --- | --- |
| `lib/config.glsl` | `lib/config.glsl`, `lib/day_blend.glsl` | read | 86 options (counted, every `#define` with a value list); shadow sliders, palette + custom colours and custom water, torch light temperature, per-effect sample counts |
| `lib/math.glsl` | `lib/basic_utils.glsl`, `lib/vector_utils.glsl`, `lib/luma.glsl`, `lib/dither.glsl` | read | hash, noise, dither computed instead of tabulated; integer powers as multiplications (`solPow4/5/6`), a tile-flipped dither and a per-frame rotated one, both new this pass |
| `lib/uniforms.glsl` | declared per file there | read | matches, plus `blindness`/`darknessFactor`/`darknessLightFactor` which the reference takes from `finalcolor`/`composite` |
| `lib/blockids.glsl` | `block.properties` ids | read | new this pass: the ids split out so the shadow programs see them |
| `lib/io_geometry.glsl` | declared per file there | read | varyings include `fogFactor` now |
| `lib/sky_model.glsl` | `lib/color_utils*.glsl`, `lib/day_blend.glsl` | read | day/dusk are parameters (one sin per pixel), halo pows skipped when the dot cannot light them; now also the per-theme ambient level and water colour (`OMNI_TINT` / `WATER_COLOR` there) and `blockLightColour()`, which was called from three programs and defined none |
| `lib/vertex_geometry.glsl` | `solid_blocks_vertex.glsl` + `src/position_vertex`, `src/light_vertex`, `src/fog_vertex` | read | waving scaled by skylight and rain, leaves weight 0.30, fog per vertex, clouds measure it horizontally |
| `lib/fragment_geometry.glsl` | `solid_blocks_fragment.glsl` + `src/finalcolor.glsl` | read | de-biased lightmap, candle curve, moon at night, sky^10 fake shadows, foliage softening, ambient floor, darkness, lava and powder-snow fog; the End portal is now the reference's layered stack |
| `lib/fragment_water.glsl` | `water_blocks_fragment.glsl` + `lib/water.glsl` | read | thickness-based absorption, glint on the reflected ray, reflection border fold and fade, a glass path of its own, per-theme water colour |
| `lib/fragment_skybasic.glsl` | `skybasic_fragment.glsl` | read | gradient, stars, clouds; underwater tint, silver lining, rain flattening, horizon fade and a separate End cloud look added this pass |
| `lib/fragment_clouds.glsl` | `clouds_blocks_fragment.glsl` | read | horizontal fog, palette lighting |
| `lib/fragment_glowing.glsl` | `glint_blocks_fragment.glsl` path | structure | lit outline, fog from the vertex stage |
| `lib/ssao.glsl` | `lib/ao.glsl`, `deferred` AO block | read | 4/6 taps, distance fade like the reference's `linearDepth` attenuation, and a rotating dither so the pattern does not settle |
| `lib/shadowmap.glsl` | `lib/shadow_frag.glsl`, `lib/shadow_vertex.glsl` | read | four taps or one, slope-scaled bias, slides/distance from the sliders; no distortion (documented) |
| `lib/buffers.glsl` | buffer block in `final_fragment.glsl` | read | formats and the three `Clear = false` flags |
| `lib/composite_body.glsl` | `composite_fragment.glsl` | read | shafts + exposure; the march now starts at a per-pixel, per-frame dithered point |
| `final.fsh` | `final_fragment.glsl` | read | exposure, tone curve, FXAA (now the real 3.11 edge trace, and applied to `AA_TYPE` 2 as well), DOF, AO, bloom, aberration, sharpening, colour-blind aid |
| `composite2.fsh` | `composite2_fragment.glsl` | read | TAA reprojection, variance-box history clip, motion blur, clamp 50 |
| `composite.fsh` / `.vsh` | `composite_*` | read | thin wrapper over the library |
| `deferred.fsh` / `.vsh` | `deferred_*` | read | scene copy only; `colortex4Clear = false` now, without which water could not read the copy at all |
| `prepare.fsh` / `.vsh` | `prepare_*` | read | horizon colour as the frame's background |
| `shadow.fsh` / `.vsh` | `shadow_*` | read | alpha test + emissive blocks discarded, which the reference does with `is_noshadow` |
| `gbuffers_terrain`, `_block`, `_entities`, `_hand`, `_hand_water`, `_textured`, `_weather`, `_entities_glowing`, `_water`, `_clouds`, `_skybasic`, `_skytextured`, `_basic`, `_line`, `_spidereyes`, `_beaconbeam`, `_armor_glint`, `_damagedblock` (18 pairs) | root wrappers + `common/*` | read for the shared bodies, structure for the wrappers | same jobs; each wrapper is 6-11 lines including a library |
| `world0/`, `world-1/`, `world1/` (72 files) | 170 files across the same three folders | structure | 8-line entry points, dimension define + include |
| `block.properties` | `block.properties` | read | 7 ids, vanilla only |
| `dimension.properties` | `dimension.properties` | read | same three mappings |
| `shaders.properties` | `shaders.properties` | read | profiles (including `PerformancePlus`), screen, sliders, 4 pass switches, blend state |
| `lang/*.lang` (9) | `lang/*.lang` (9) | structure | `en_US` complete; the other eight carry names and values |

### Reference files still to be line-read

Honesty about the shape of this audit: these are compared by structure so far, and
their full line read is the next piece of work - 2,900 lines:

`common/water_blocks_fragment.glsl` (321), `lib/water.glsl` (325),
`common/water_blocks_vertex.glsl` (154), `lib/dither.glsl` (235), `lib/fxaa.glsl`
(204), `lib/fast_taa.glsl` (185), `lib/color_utils.glsl` (181),
`lib/color_conversion.glsl` (156), `lib/volumetric_light.glsl` (117),
`lib/volumetric_clouds.glsl` (106), `lib/volumetric_clouds_end.glsl` (98),
`lib/end_portal.glsl` (71), `src/fog_vertex.glsl` (56), `src/writebuffers.glsl` (37),
`common/basic_blocks_vertex.glsl` (54), `common/skybasic_vertex.glsl` (68),
`common/skytextured_vertex.glsl` (50), `common/skytextured_fragment.glsl` (48),
`common/clouds_blocks_vertex.glsl` (40), `common/clouds_blocks_fragment.glsl` (38),
`src/shadow_src_vertex.glsl` (38), `lib/basic_utils.glsl` (73),
`lib/ao.glsl` (46), `lib/cas.glsl` (41), `lib/color_blindness.glsl` (40),
`lib/blur.glsl` (36), `lib/bloom.glsl` (34), `lib/motion_blur.glsl` (34),
`lib/material_gloss_fragment.glsl` (28), `lib/tone_maps.glsl` (19),
`lib/aberration.glsl` (17), `lib/projection_utils.glsl` (15), `lib/luma.glsl` (13),
plus the nine small `common/{basic,line,damage,glint,spidereyes}_blocks_*` pairs.


## 10. Third pass: the water vertex, the AO and the post libraries

Read in full this pass: `common/water_blocks_vertex.glsl` (154), `lib/ao.glsl` (46),
`lib/bloom.glsl` (34), `lib/blur.glsl` (36), `lib/cas.glsl` (41) - 311 lines, taking
the total to **23 reference files and 2,886 lines** read line by line.

| # | Reference behaviour | Mine before | Fix |
| --- | --- | --- | --- |
| 22 | `water_blocks_vertex.glsl:130-136` sorts translucent geometry into water (3) and glass (2); the fragment shades them differently, and only water ripples | every translucent surface went through the same wave code, so stained glass shimmered like water | `SOLACE_WATER` / `SOLACE_GLASS` ids added (8 and 9), waves now apply only to water |
| 23 | the reflection colour in water comes from varyings computed in the vertex stage (`hi_sky`/`low_sky`), not from the full sky model per pixel | every water pixel called `skyColour()`, which pays a star hash and two high-power halos | `reflectionColour()` added to the sky model: gradient plus one soft glow, no stars, no tight halo |
| 24 | `lib/ao.glsl` pairs taps either side of the centre, rotates them by the golden ratio, adds an angle **and** a distance term, and returns `sqrt(occlusion*strength + (1-strength))` | no rotation (fixed cross), one depth-difference term, linear mix back to 1 | rebuilt the same way: golden-ratio rotation, paired taps, angle + distance, square-root curve |
| 25 | `lib/bloom.glsl` gathers its glow from a **mip level** (`texture2DLod(..., softLod)`) with rotated offsets | eight taps at full resolution, so the glow was tight and aliased | mipmaps enabled on both scene buffers (`colortex0MipmapEnabled/colortex1MipmapEnabled`), `#extension GL_ARB_shader_texture_lod`, bloom now samples mip `BLOOM_LOD` (new option) |
| 26 | `lib/blur.glsl` focuses DOF with `centerDepthSmooth`, the frame-smoothed depth the mod provides, and rotates its two taps | used the raw centre pixel, so focus jittered with the crosshair, and used evenly spaced taps | focus on `centerDepthSmooth` when available, rotated taps |
| 27 | `lib/cas.glsl` is AMD's contrast-adaptive sharpening: neighbour min/max, an amplification curve, a peak set by `SHARPENING` | plain 4-neighbour unsharp mask | kept the unsharp mask (its own code, no AMD licence text), noted here as the one post effect whose maths is deliberately different |

Also noted, not changed: the reference stores scene depth in the alpha channel of
its main buffer (`deferred` writes `vec4(colour, depth)`), which lets DOF and water
read depth without another texture. This pack reads `depthtex0` instead - one buffer
layout less, one more texture read in DOF.

### Reference files still to be line-read (2,585 lines)

`common/water_blocks_fragment.glsl` (321), `lib/water.glsl` (325),
`lib/dither.glsl` (235), `lib/fxaa.glsl` (204), `lib/fast_taa.glsl` (185),
`lib/color_utils.glsl` (181), `lib/color_conversion.glsl` (156),
`lib/volumetric_light.glsl` (117), `lib/volumetric_clouds.glsl` (106),
`lib/volumetric_clouds_end.glsl` (98), `lib/end_portal.glsl` (71),
`lib/basic_utils.glsl` (73), `common/skybasic_vertex.glsl` (68), `src/fog_vertex.glsl`
(56), `common/basic_blocks_vertex.glsl` (54), `common/skytextured_vertex.glsl` (50),
`common/skytextured_fragment.glsl` (48), `lib/color_blindness.glsl` (40),
`common/clouds_blocks_vertex.glsl` (40), `common/clouds_blocks_fragment.glsl` (38),
`src/shadow_src_vertex.glsl` (38), `src/writebuffers.glsl` (37),
`lib/motion_blur.glsl` (34), `common/line_blocks_vertex.glsl` (29),
`lib/material_gloss_fragment.glsl` (28), `common/glint_blocks_vertex.glsl` (28),
`common/spidereyes_blocks_vertex.glsl` (27), `common/damage_vertex.glsl` (26),
`lib/tone_maps.glsl` (19), `lib/aberration.glsl` (17), `lib/vector_utils.glsl` (17),
`lib/projection_utils.glsl` (15), `lib/luma.glsl` (13),
`common/line_blocks_fragment.glsl` (13), `common/basic_blocks_fragment.glsl` (15),
`common/damage_fragment.glsl` (17), `common/glint_blocks_fragment.glsl` (20),
`common/spidereyes_blocks_fragment.glsl` (18), plus `src/basiccoords_vertex.glsl`
(9), `src/hi_sky.glsl` (18), `src/low_sky.glsl` (18), `src/position_vertex_water.glsl`
(15), `src/cloudfinalcolor.glsl` (16) and the six `*_vertex.glsl` thin wrappers
(29-111 lines each).


## 11. Fourth pass: the water fragment, the fog curve, the buffer writes

Read in full this pass: `common/water_blocks_fragment.glsl` (321),
`src/fog_vertex.glsl` (56), `src/writebuffers.glsl` (37) - 414 lines, taking the
total to **27 reference files and 3,300 lines** read line by line.

| # | Reference behaviour | Mine before | Fix |
| --- | --- | --- | --- |
| 28 | `src/fog_vertex.glsl:14-31` - fog is a **power curve** on `distance/far`, multiplied by how much sky the vertex can see (`max(eyeBrightnessSmooth.y/240, visibleSky)`) and with the exponent mixed towards 1 by rain | an exponential on distance only, identical in a cave and in the open | rebuilt to the same shape: power curve, sky exposure factor (`eyeBrightnessSmooth` added as a uniform), exponent `FOG_DENSITY*2` blent towards 1 by rain. A cave now has almost no fog, as in the reference |
| 29 | `src/writebuffers.glsl` - every geometry write is clamped to 50 before it reaches the buffers | geometry and water wrote raw values; a bright emissive or a specular could feed the bloom and the AA history | clamp added to the geometry and water writes |
| 30 | `water_blocks_fragment.glsl:168-173` - glass gets a flat normal and its own `cristal_shader`, only water uses the wave normal | (fixed last pass) waves now skipped for glass; the glass path is still the water shader with a flat normal rather than a separate function | noted as a simplification, not a bug |
| 31 | `water_blocks_fragment.glsl:252` - refraction is `refraction(fragposition, colour, waterNormalBase)`, which uses the depth textures to bend by the *scene* depth at the offset | bends by the normal alone, ignoring the depth behind it | noted: depth-aware refraction is the next improvement in the water library |

Also confirmed by this pass: the reference writes its scene to **colortex1** and its
fog colour to **gaux4** (`DRAWBUFFERS:17` from `prepare`, `:12` from geometry, `:1`
from water), while this pack writes the scene to colortex0 and derives the fog colour
per pixel. Same information, one buffer fewer - but it is why the reference can share
one fog fetch across every geometry program and this pack cannot.

### Reference files still to be line-read (2,170 lines)

`lib/water.glsl` (325), `lib/dither.glsl` (235), `lib/fxaa.glsl` (204),
`lib/fast_taa.glsl` (185), `lib/color_utils.glsl` (181), `lib/color_conversion.glsl`
(156), `lib/volumetric_light.glsl` (117), `lib/volumetric_clouds.glsl` (106),
`lib/volumetric_clouds_end.glsl` (98), `lib/basic_utils.glsl` (73),
`lib/end_portal.glsl` (71), `common/skybasic_vertex.glsl` (68),
`common/basic_blocks_vertex.glsl` (54), `common/skytextured_vertex.glsl` (50),
`common/skytextured_fragment.glsl` (48), `common/clouds_blocks_vertex.glsl` (40),
`lib/color_blindness.glsl` (40), `common/clouds_blocks_fragment.glsl` (38),
`src/shadow_src_vertex.glsl` (38), `lib/motion_blur.glsl` (34),
`common/line_blocks_vertex.glsl` (29), `lib/material_gloss_fragment.glsl` (28),
`common/glint_blocks_vertex.glsl` (28), `common/spidereyes_blocks_vertex.glsl` (27),
`common/damage_vertex.glsl` (26), `lib/tone_maps.glsl` (19), `lib/aberration.glsl`
(17), `lib/vector_utils.glsl` (17), `lib/projection_utils.glsl` (15),
`lib/luma.glsl` (13), `common/basic_blocks_fragment.glsl` (15),
`common/line_blocks_fragment.glsl` (13), `common/damage_fragment.glsl` (17),
`common/glint_blocks_fragment.glsl` (20),
`common/spidereyes_blocks_fragment.glsl` (18), and the `src/` snippets
`basiccoords_vertex` (9), `hi_sky` (18), `low_sky` (18), `position_vertex_water` (15),
`cloudfinalcolor` (16), plus the thin `*_vertex.glsl` wrappers for composite,
composite1, composite2, deferred, final and prepare (29-111 lines).



## 12. Fifth pass: water, dithering, antialiasing, clouds, the portal

Read in full this pass: `lib/water.glsl` (325), `lib/dither.glsl` (235), `lib/fxaa.glsl`
(204), `lib/fast_taa.glsl` (185), `lib/color_utils.glsl` (181),
`lib/color_conversion.glsl` (156), `lib/volumetric_light.glsl` (117),
`lib/volumetric_clouds.glsl` (106), `lib/volumetric_clouds_end.glsl` (98),
`lib/basic_utils.glsl` (73), `lib/end_portal.glsl` (71) - 1,751 lines, taking the
total to **38 reference files and 5,051 lines** read line by line.

Three of the findings are not cosmetic: they are why the pack could not have compiled
or could not have shown water reflections at all.

| # | Reference behaviour | Mine before | Fix |
| --- | --- | --- | --- |
| 32 | `water.glsl:132-160` measures absorption as the **thickness of water behind the pixel**: it linearises its own depth and the scene depth at the (bent) sample position and uses the difference | absorption was `exp(-viewDist)`, i.e. how far the *eye* was from the surface, so a shallow pool over stone went opaque as you walked away from it and a deep ocean looked thin from above | refraction is now depth-aware: `waterLinearDepth()` on both `gl_FragCoord.z` and `depthtex0` at the bent UV, thickness squared into an exponential. The reference's rational curve is replaced by an exponential because theirs turns **negative** past a few blocks of water at its default constant and inverts the colour; the deviation is deliberate and the curve is monotone |
| 33 | `water.glsl:101-109` puts the sun glint on the **reflected** ray (`sun_reflection(reflect(eye, normal))`, a `smoothstep(0.995,1.0)` on the alignment), gated by the march's `infinite` flag, the sky lightmap, and `1-rainStrength` | glint was `pow(dot(normal, astroDir), 300)`, which lights the surface facing the sun rather than the direction the mirror points, and appeared under a roof | glint is now on `reflectedWorld`, multiplied by `reflectionSky` (how much of the mirror direction is open), the sky lightmap and `1-rainStrength` |
| 34 | `water.glsl:187-197, 268-272` folds a reflection that leaves the screen back through the edge (`pos.x = 2 - pos.x`) and fades it out with a border term - `pow(pos.y,10)` for water, a fourth-power square for glass | off-screen reflections clamped their UV, which smears the edge pixel along the border | same fold and fade, with the reference's two border shapes, one per material |
| 35 | `water.glsl:275-325` - `cristal_shader` is a separate path: no ripples, no absorption, base mixed to the sky and then to the reflection **both** by fresnel, and `alpha = mix(alpha, 1.0, fresnel*0.9)` | glass was the water shader with the waves switched off, so it was as transparent at grazing angles as water is | glass now has its own compositing, alpha and reflection border, and skips refraction |
| 36 | `color_utils.glsl:19-154` gives every theme an `OMNI_TINT` (0.25-0.65) and its own `WATER_COLOR` | all eight themes shared one ambient level and one water colour, so they differed only in hue | `themeAmbient()` and `themeWater()` added, `CUSTOM_AMBIENT` and `CUSTOM_WATER_R/G/B` for the custom theme |
| 37 | `color_utils.glsl:158-168` - `CANDLE_BASELIGHT` has five temperatures | one fixed warm orange | `BLOCKLIGHT_TEMP` option (5 values, warm to neutral), Nether still forced red |
| 38 | - | **`blockLightColour()` was called from `fragment_geometry.glsl`, `fragment_water.glsl` and `fragment_glowing.glsl` and defined in no file.** The pack could not compile | defined in `sky_model.glsl` |
| 39 | - | **`fragment_skybasic.glsl` called `ambientColour()` and `fogColour()` with no arguments**, against two-parameter definitions. A second compile error, on every sky pixel | both calls now pass the frame's `day` and `dusk` |
| 40 | - | **`colortex4` (the scene copy) had no `Clear = false`**, so it was cleared every frame, and `gbuffers_water` - which runs before `deferred` writes it - read a black buffer. REFRACTION and WATER_SSR would have produced nothing usable | `colortex4Clear = false` added, with the one-frame lag it implies written down in `buffers.glsl` and `deferred.fsh` |
| 41 | `fxaa.glsl` is FXAA 3.11: luma range test, 8-neighbour edge orientation, two-sided trace along the edge, the sub-pixel term, one final fetch | a 5-tap edge detector followed by an 8-tap blur along an estimated direction - cheaper, softer, and stepped on diagonals | rewritten as a 3.11-shaped trace (my own code): orientation from the 8 neighbours, two-sided walk with doubling reach and a `break` when both ends are found, sub-pixel term, one final fetch. `AA_TYPE 2` (temporal + FXAA) never actually ran FXAA before; it does now |
| 42 | `fast_taa.glsl:7-32, 130-137` clips the history into the **mean ± standard deviation box** of the current 3x3 neighbourhood and shrinks the history weight by how far it had to move | a 5-tap min/max clamp and a fixed `TAA_WEIGHT` | the same variance box (`solHistoryBox`), with the weight reduced by up to a third as the box fills up |
| 43 | `dither.glsl` carries a whole family: fixed, `shifted*` (per-frame) and tile-flipped `semiblue` variants, and uses them per effect | one static hash, so DOF, bloom, AO and the SSR march all left the same pattern on screen every frame | `solDitherBlue()` (tile flip + low-discrepancy pair) and `solDitherShifted()` (rotated by the frame counter) added; DOF, bloom, AO, the SSR march, the cloud march and the output dither now use them |
| 44 | `volumetric_clouds.glsl:42-102` - dithered march start, attenuation that flattens in rain, a density-driven darkening, and a bright inner region where the cloud is thin | fixed march start (visible banding), no rain response, no silver lining, no horizon fade | all four added; `volumetric_clouds_end.glsl`'s separate End look is now a branch in `cloudLayer()` (bright violet haze, no sun) |
| 45 | `volumetric_light.glsl:99-115` starts its screen-space ray at `texcoord + ray_step*dither` | fixed start, so the 3-6 samples left bands along the ray | dithered start, per pixel and per frame |
| 46 | `end_portal.glsl` - stacked layers, each a finer hash grid, a colour that cycles between violet, blue and teal, `inverse^4` fade per layer, 10 layers with an early break | a teal noise swirl: wrong hue for a portal, no depth, no cycling | rebuilt as six layers (past the fourth the contribution is under one 8-bit step), same colour cycling and fade |
| 47 | `basic_utils.glsl` - `fourthPow`/`fifthPow`/`sixthPow` exist so constant powers cost a multiply chain | `pow(x, 6.0)` on the lightmap candle curve, `pow(x, 4.0)` twice in the sky band, `pow(x, 10.0)` in the reflection border, all per pixel | `solPow4/5/6()` in `math.glsl` and all four call sites converted |

Deliberately different, and named rather than hidden:

- **Oklab grading.** `color_conversion.glsl` has a full sRGB/Oklab pipeline, which the
  reference feeds its saturation and contrast through. This pack still scales chroma
  around the luma vector and applies contrast around 0.5. An Oklab round trip costs
  nine transcendentals per pixel on every frame; at 1920x1080 on an HD 5500 that is
  the wrong trade for a saturation step of 1.06, and the hue shift it avoids is not
  visible at that strength. If it ever becomes an option, the code lives here as a
  documented gap, not an oversight.
- **The reference's absorption curve**, replaced by an exponential, as fix 32 says.
- **Refraction and reflections lag one frame** because `deferred` runs after
  `gbuffers_water`; the same is true of the reference's `gaux1`, and it is hidden by
  TAA when TAA is on.
- **`CLOUD_HI_FACTOR` / `CLOUD_LOW_FACTOR` texture drift**, replaced by the pack's own
  analytic noise: the reference's clouds are a 64x64 `gaux2` texture, and this pack has
  no cloud texture to sample.

### Reference files still to be line-read (~1,150 lines)

`common/skybasic_vertex.glsl` (68), `common/basic_blocks_vertex.glsl` (54),
`common/skytextured_vertex.glsl` (50), `common/skytextured_fragment.glsl` (48),
`common/clouds_blocks_vertex.glsl` (40), `lib/color_blindness.glsl` (40),
`common/clouds_blocks_fragment.glsl` (38), `src/shadow_src_vertex.glsl` (38),
`lib/motion_blur.glsl` (34), `common/line_blocks_vertex.glsl` (29),
`lib/material_gloss_fragment.glsl` (28), `common/glint_blocks_vertex.glsl` (28),
`common/spidereyes_blocks_vertex.glsl` (27), `common/damage_vertex.glsl` (26),
`lib/tone_maps.glsl` (19), `common/glint_blocks_fragment.glsl` (20),
`lib/aberration.glsl` (17), `lib/vector_utils.glsl` (17),
`common/damage_fragment.glsl` (17), `common/basic_blocks_fragment.glsl` (15),
`lib/projection_utils.glsl` (15), `lib/luma.glsl` (13),
`common/line_blocks_fragment.glsl` (13), `common/spidereyes_blocks_fragment.glsl` (18),
the `src/` snippets `basiccoords_vertex` (9), `hi_sky` (18), `low_sky` (18),
`position_vertex_water` (15), `cloudfinalcolor` (16), and the thin `*_vertex.glsl`
wrappers for composite, composite1, composite2, deferred, final and prepare.

Not implemented at all, and still not: coloured shadows (`shadowtex0`/`shadowcolor0`
plus translucent shadow geometry), shadow lock, `Distant Horizons`, `Voxy`, the three
PNG textures the reference ships (it reads `noisetex`, `gaux2` and a dither texture as
files; everything here is computed), and native-reviewed translations (the eight
non-English files are mine, names and enumerated values only).



## 13. Sixth pass: the vertex stages, the small post libraries, the wrappers

Read in full this pass: `common/skybasic_vertex.glsl` (68),
`common/basic_blocks_vertex.glsl` (54), `common/skytextured_vertex.glsl` (50),
`common/skytextured_fragment.glsl` (48), `common/clouds_blocks_vertex.glsl` (40),
`lib/color_blindness.glsl` (40), `common/clouds_blocks_fragment.glsl` (38),
`src/shadow_src_vertex.glsl` (38), `lib/motion_blur.glsl` (34),
`common/line_blocks_vertex.glsl` (29), `lib/material_gloss_fragment.glsl` (28),
`common/glint_blocks_vertex.glsl` (28), `common/spidereyes_blocks_vertex.glsl` (27),
`common/damage_vertex.glsl` (26), `common/glint_blocks_fragment.glsl` (20),
`lib/tone_maps.glsl` (19), `lib/aberration.glsl` (17), `lib/vector_utils.glsl` (17),
`common/damage_fragment.glsl` (17), `common/basic_blocks_fragment.glsl` (15),
`lib/projection_utils.glsl` (15), `lib/luma.glsl` (13),
`common/line_blocks_fragment.glsl` (13), `common/spidereyes_blocks_fragment.glsl` (18),
`src/basiccoords_vertex.glsl` (9), `src/hi_sky.glsl` (18), `src/low_sky.glsl` (18),
`src/position_vertex_water.glsl` (15), `src/cloudfinalcolor.glsl` (16),
`lib/color_utils_end.glsl` (49), `lib/color_utils_nether.glsl` (45),
`lib/day_blend.glsl` (41), `lib/post.glsl` (9), `lib/depth.glsl` (9),
`lib/volumetric_clouds_vertex.glsl` (51), `common/composite_vertex.glsl` (111),
`common/composite1_vertex.glsl` (12), `common/composite2_vertex.glsl` (12),
`common/deferred_vertex.glsl` (59), `common/final_vertex.glsl` (29),
`common/prepare_vertex.glsl` (37), `lib/mu_ftransform.glsl` (18) - 1,270 lines, taking
the total to **80 reference files and 6,321 lines**.

| # | Reference behaviour | Mine before | Fix |
| --- | --- | --- | --- |
| 48 | `color_utils_nether.glsl:12-22` and `color_utils_end.glsl:12-22` - both dimensions are almost **neutral** (End `0.0465,0.0375,0.0465`; Nether `0.0480,0.0434,0.0425`), with the colour coming from the light and the fog, and `FOG_* = 1.0` in both | a bright orange Nether (`0.52,0.16,0.065`) and a violet End (`0.23,0.15,0.33`), so the fog in both was far stronger than the reference's | both palettes replaced; the Nether mixes vanilla's `fogColor` in (the uniform the reference falls back to for unknown dimensions), so it stays red without the palette inventing it |
| 49 | `color_utils*.glsl:40-47` - fog density is a per-dimension constant, 1.0 in the Nether and the End whatever the overworld setting is | one global `FOG_DENSITY` everywhere, so a Nether at 1.6 filled the screen | the vertex fog stage uses a fixed 1.0 in those two dimensions |
| 50 | `basic_blocks_vertex.glsl:44-53` + `basic_blocks_fragment.glsl:11-12` light basic geometry per vertex (`basicLight` = day/night light + candle curve + rain) and multiply the vertex colour by it | `gbuffers_basic` wrote the vertex colour untouched, so a block outline glowed in a cave and a leash was the brightest thing at night | same shape: `basicLight` computed per vertex from the palette and the lightmap, multiplied in the fragment |
| 51 | `glint_blocks_vertex.glsl:25` reads the exposure out of `gaux3` and `glint_blocks_fragment.glsl:17` divides the glint by it | the glint was simply brightened, so it dimmed and brightened with the exposure | the glint has its own small vertex stage now and divides by the exposure, read from colortex6 (or `EXPOSURE` with auto exposure off) |
| 52 | `color_blindness.glsl` is the daltonize chain: LMS projection, replace the missing cone response, push the difference into the working channels | the aid washed the colour towards grey, which dims the picture without separating anything | rewritten as the same chain, with the correction applied to the channel the chosen weakness loses (the reference always shifts red; this shifts green for mode 2 and blue for mode 3 as well) |
| 53 | `aberration.glsl:5-16` offsets **outwards from the centre** and samples red at the full offset, green at half, blue at none | red and blue were shifted in opposite directions by the same amount, which adds a blue fringe the reference does not have | the reference's three-channel scheme, with the offset factor rescaled to this pack's slider range |
| 54 | `material_gloss_fragment.glsl:22-24` multiplies the highlight by `1 - rainStrength` | the highlight survived rain | damped the same way |
| 55 | `clouds_blocks_fragment.glsl:6-12` declares `blindness`, `darknessFactor` and `darknessLightFactor` and uses them on the deck | clouds ignored both, so the Warden's darkness stopped at the cloud layer | applied in `fragment_clouds.glsl` |
| 56 | `composite_vertex.glsl:86-87` smooths the exposure by `exp(-frameTime * 1.25)` - by elapsed time | the exposure moved a fixed fraction per frame, so it converged twice as fast at 60 fps as at 30 and pumped whenever the framerate moved | a time-based blend (same shape, scaled by `AUTO_EXPOSURE_SPEED`) |
| 57 | `color_utils*.glsl` declare `fogColor`/`skyColor` for dimensions without a palette | neither was declared | `fogColor` in `uniforms.glsl` (used by the Nether palette), `frameTime` alongside it |

Deliberately different, and named:

- **Line width.** `lib/mu_ftransform.glsl` widens `GL_LINES` to a constant two pixels
  by rebuilding the quad from `gl_VertexID` and the normal, so a block outline keeps
  its weight at any distance. That needs `#version 130` (there is no `gl_VertexID` in
  120) and is exactly the kind of change that cannot be verified without the game
  running, so this pack keeps vanilla's one-pixel lines and says so here.
- **Exposure curve.** The reference maps average luma through
  `exp(-luma) * 3.03 + 0.6`, a curve calibrated to its much darker palette. This pack
  keeps `0.20 / luma`, which is calibrated to its own lighting; only the smoothing is
  taken from the reference.
- **Tone curve.** `lib/tone_maps.glsl` is a sigmoid built from three `pow(vec3)`
  calls - nine transcendentals per pixel. This pack's rational curve has a similar
  shoulder for a handful of multiplies and divides. It is the one post effect whose
  maths is deliberately different, and it stays documented rather than silently
  swapped.
- **Sharpening.** `lib/post.glsl` is a fixed 5-tap kernel (`-1,-1,11,-1,-1` over 7).
  This pack keeps its unsharp mask so the slider means something.
- **Day and dusk.** The reference reads `dayMoment`/`dayMixer`/`nightMixer` from the
  mod (`lib/day_blend.glsl`); this pack derives both from `worldTime`. Same input,
  one `sin()` instead of three uniforms, and no dependency on a uniform a given
  version may not provide.
- **Cloud lighting** is per pixel here and per vertex there
  (`lib/volumetric_clouds_vertex.glsl`). Per pixel costs a few more multiplies inside
  a march the pack already pays for, and it lets the silver lining follow the sun.
- **Depth linearisation.** `lib/depth.glsl` returns normalised device depth; this pack
  derives view distance from the projection matrix, because the water thickness in
  fix 32 needs a distance in blocks.
- **Motion blur can smear the hand.** The reference skips motion blur on the hand by
  testing its stored depth (`motion_blur.glsl:8`); this pack has no such channel and
  would need `depthtex2` to find the hand, which cannot be checked here.
- **Basic geometry in the Nether and the End** uses the overworld palette, because
  those two dimension folders have no `gbuffers_basic` of their own and fall back to
  the root pair. The alternative was 72 more wrapper files for one lit colour.

### What is left, and why

Every reference file that does a job this pack also does has now been read line by
line: 80 files, 6,321 lines. What has not been read is the family that only exists for
mods this pack does not support - `solid_dh_blocks_*`, `solid_dh_water_*`,
`solid_voxy_blocks_*`, `water_voxy_*`, `voxy_opaque`, `voxy_translucent`,
`lib/water_dh.glsl`, `lib/water_voxy.glsl`, `lib/depth_dh.glsl`,
`lib/projection_utils_voxy.glsl`, `lib/material_gloss_fragment_voxy.glsl`,
`src/*_dh.glsl`, `src/*_voxy.glsl`, and the four per-dimension `voxy_*` pairs - roughly
1,900 lines that have no counterpart here because Distant Horizons and Voxy are not
supported and their uniforms cannot be verified without those mods installed.

Still unimplemented for the same reason, unchanged from earlier passes: coloured
shadows, shadow lock, the three PNG textures, and native-reviewed translations.



## 14. Seventh pass: the properties files and the shader constants

`lib/config.glsl` was re-read in full (331 lines) and reconciled against this pack's
options, together with the reference's `block.properties` (102 lines), `item.properties`
(5), `entity.properties` (10) and `dimension.properties` (3). The program files were
already covered; what these four decide is *which geometry* gets the shaders at all,
and that is where the gaps were.

| # | Reference behaviour | Mine before | Fix |
| --- | --- | --- | --- |
| 58 | `block.properties` gives each block **one** id | `minecraft:ice`, `packed_ice` and `blue_ice` were in both the polished id (4) and the glass id (9), and `crying_obsidian` in both the polished id and the emissive id (6). A block listed twice has no defined id, so ice shimmered or glossed depending on the order the mod read the file | the duplicates are gone: ice and its variants are glass, crying obsidian is emissive |
| 59 | grass, crops, leaves and vines are listed by category, and the reference's lists are huge because they cover mods | vanilla only, and missing every underwater plant, every vine, hanging roots, the dripleaf stem, dead bush, azalea and the new pale oak | added to the waving and leaves ids, so kelp, seagrass, cave/weeping/twisting vines, hanging roots and the rest sway and pale oak leaves move with the wind |
| 60 | `item.properties` exists and its ids drive the held-item light (`glint_blocks`, `composite` read `heldItemId`) | no `item.properties` at all, so `HAND_LIGHT` only ever reacted to `heldBlockLightValue` - a torch held as an *item* lit nothing | `item.properties` added with two light levels, `heldItemId` declared, and the hand light in the geometry stage now mixes blocks and items |
| 61 | `entity.properties` gives Iris the ids that fill `mc_Entity.x` for entity programs (`10101` lightning, `10201` entity flames) | no `entity.properties`, so `blockId` was always 0 for entities and nothing could key off them | `entity.properties` added, and lightning bolts and the fire on a burning entity are drawn as their own light rather than as a lit surface |
| 62 | glow-berry vines are emissive | not listed, so a cave-vine with berries was shaded like a leaf | added to the emissive id with their state (`berries=true`) |
| 63 | `config.glsl:200-321` declares the **shader constants** the mod applies to the whole pipeline: `sunPathRotation = -25.0`, `ambientOcclusionLevel` (0.7 with SSAO off, 0.0 with it on), `eyeBrightnessHalflife = 3.0`, `centerDepthHalflife = 0.66`, `shadowIntervalSize = 3.0`, `shadowHardwareFiltering`, `shadowtex1Nearest` | this pack declared none of them: the sun crossed straight overhead instead of on the reference's tilted path, vanilla's own AO stayed at full strength while the pack's SSAO was off, and the fog and focus smoothing used Iris's much slower defaults | all seven declared in `lib/config.glsl`; the sun tilt alone changes every sunset, shadow direction and water glint |
| 64 | `config.glsl:48,144-148` caps sight in the Nether at `min(far/2, 96)` (`NETHER_FOG_DISTANCE`, on by default) | the Nether fog reached the full render distance, so the far wall of a nether fortress never faded | the Nether's fog distance is capped the same way; the option to switch it off is not exposed, and that is named below rather than pretended away |

Reconciled and deliberately left as they are:

- **`NETHER_FOG_DISTANCE` as a switch.** The behaviour is the reference default; a
  slider for it would be one more thing to translate into nine languages for a value
  nobody turns off.
- **`SHADOW_LOCK`** - a shadow refresh throttle. A shader cannot ask the mod to skip
  the shadow pass, so this is a per-frame cost the pack cannot reclaim. Still out.
- **`SELECTIVE_TAA_V2`** - needs an object mask so entities can be excluded from the
  history; the mask comes from buffers this pack does not have.
- **`CLOUD_SPEED`, `AVOID_DARK_LEVEL`, `BLACK_ENTITY_FIX`, `DEBUG_MODE`** - the cloud
  drift is fixed in the pack's analytic noise, the cave light floor is `0.045`, and the
  other two are a driver workaround and a debug switch.
- **The reference's mod block lists** - it lists thousands of blocks from dozens of
  mods. This pack is vanilla-only by design and says so in `block.properties`.
- **The reference's per-theme light colours** - it exposes a custom colour for every
  sunset/day/night light, zenith and horizon value; this pack exposes the custom
  zenith, horizon, ambient and water colours, which covers the same look with eleven
  options instead of eighteen.
