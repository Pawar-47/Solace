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
