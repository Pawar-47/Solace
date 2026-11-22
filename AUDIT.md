# Audit: Solace against the working pack

The reference is `MakeUp - UltraFast 9.6a`. It is not in this repository — it is
third-party code under its own licence, kept outside the project for reading, and
`.gitignore` refuses it here. Everything below is a comparison of **our** file against
**its** file, line by line, and what came out of it.

Statuses: **same** (compared, no defect), **fixed** (a defect was found and corrected,
with the commit), **by design** (deliberately different, with the reason), **queued**
(not yet compared).

## The list

### Pipeline and configuration

| Ours | Reference | Checked | State |
| --- | --- | --- | --- |
| `shaders.properties` | `shaders.properties` (213) | pass switching, `program.*.enabled`, `flip`, blend lines, texture bindings, profile syntax, custom uniforms | **fixed** `8ad20bd` — the reference switches no pass off by expression and has no `flip` lines; ours did both, and a pass that is present but disabled is still a program the mod builds |
| `lib/buffers.glsl` | directives in `common/final_fragment.glsl` | formats in a block comment, clear flags as code, mipmap flags, which buffers are declared | **fixed** `38c9b8d`, `8ad20bd` — formats were real code (the first compile error); mipmap flags were on buffers nothing samples at a mip level |
| `lib/config.glsl` | `lib/config.glsl` (331) | order of the `const` block against the `#define`s it reads, `sunPathRotation`, `shadowMapResolution`/`shadowDistance` with shadows off, `ambientOcclusionLevel` | **fixed** `bee50a0`, `2098453` — a `const` read above its option is silently wrong; shadow constants must be declared even with the pass off |
| `lib/shadowmap.glsl` | same block in `lib/config.glsl` | constants always declared, hardware filtering only with the pass, `shadowDistanceRenderMul` | **fixed** `bee50a0` |
| `lib/uniforms.glsl` | same content inside the reference's libs | every uniform the pack uses is declared once, no stage misuse | **same** |
| `lib/math.glsl` | `lib/basic_utils.glsl`, `lib/luma.glsl` | `sat` overloads for every type called, integer `%` replaced, no `texelFetch` | **fixed** `8e2d897`, `d40a588` |
| `lib/io_geometry.glsl` | `src/writebuffers.glsl`, `src/finalcolor.glsl` | varyings declared once, matching types, `DRAWBUFFERS` per program | **same** |
| `lib/pack_textures.glsl` | `texture.gbuffers.noisetex` binding | sampler names the mod can bind: only `noisetex` is bound by convention | **fixed** `d529536` — the pack declared `noise` and `clouds`, which the mod never binds |

### The post chain

| Ours | Reference | Checked | State |
| --- | --- | --- | --- |
| `composite2.fsh` | `common/composite2_fragment.glsl` (156) | `DRAWBUFFERS` on the same conditions as the samplers; the history buffer not read and written in one draw; depth sampler only when used | **fixed** `070bdf1` — this was the freeze: `DRAWBUFFERS:03`, the colortex3 sampler and the second write were unconditional, so every frame at every shipped profile read and wrote colortex3 inside one draw |
| `lib/composite_body.glsl` | `common/composite_fragment.glsl` (242) | same class: colortex6 read and written in one pass; exposure attachment only when the option is on | **fixed** `070bdf1` |
| `deferred.fsh` | `common/deferred_fragment.glsl` (200) | reads colortex0, writes colortex4, never the same buffer; nothing sampled that is not written | **same** (buffer contract); its AO/cloud content is **by design** — this pack computes fog per vertex instead of in that pass |
| `final.fsh` | `common/final_fragment.glsl` (168) | scene sampler declared by literal name; no `#extension`; depth samplers only when the effects that read them are on; no buffer read that the pass writes | **fixed** `00e61fc`, `070bdf1`, this commit — the depth sampler is now declared only for depth of field, where the reference declares none at all |
| `final.vsh` | `common/final_vertex.glsl` | full-screen quad, texture coordinates | **same** |
| `composite.vsh`, `composite2.vsh` | `common/composite_vertex.glsl`, `composite2_vertex.glsl` | full-screen quad, no texture sampling in the vertex stage | **same** |
| `prepare.*` | `common/prepare_fragment.glsl` (57) | horizon fill, `DRAWBUFFERS`, what it writes and reads | **fixed** `435662c` — removed while chasing the freeze, then restored in all four dimensions once the freeze was traced to `composite2`. It writes one target and reads nothing, which is the whole of its contract; the reference also writes its fog colour to a second buffer here, which this pack does not need because it measures fog per vertex |

### Geometry stage

| Ours | Reference | Checked | State |
| --- | --- | --- | --- |
| `lib/vertex_geometry.glsl` | `common/solid_blocks_vertex.glsl` (215) + `src/light_vertex.glsl`, `src/position_vertex.glsl`, `src/fog_vertex.glsl` | per-vertex light, fog distance, waving, sub-pixel jitter, `DRAWBUFFERS` in the vertex stage | **queued** |
| `lib/fragment_geometry.glsl` | `common/solid_blocks_fragment.glsl` (302) | lightmap de-bias, candle curve, gloss, emissive, portal, fog mix | **queued** (the lighting model was compared during the original port; the buffer/write contract has not) |
| `gbuffers_*` wrappers | same wrappers | `#version`, `#extension`, defines, includes | **same** |
| every `.vsh` that positions a quad or a block | `common/*_vertex.glsl`, `lib/mu_ftransform.glsl` | how `gl_Position` is produced | **fixed** — all 16 of ours called `ftransform()`; the reference never does, it writes `gl_ModelViewProjectionMatrix * gl_Vertex`, and reserves its own `muFtransform()` for line width only |
| `gbuffers_armor_glint.*` | `common/glint_blocks_*` | exposure read in the fragment stage, implicit-LOD sampling not used in a vertex stage | **fixed** `031c857`, `d529536` |

### Sky, clouds, water

| Ours | Reference | Checked | State |
| --- | --- | --- | --- |
| `lib/fragment_skybasic.glsl` | `common/skybasic_fragment.glsl` (96) | sky ray, star hash, sun halo | **queued** |
| `lib/fragment_clouds.glsl` | `common/clouds_blocks_fragment.glsl` (38) | vanilla cloud geometry lighting | **queued** |
| `lib/fragment_water.glsl` | `common/water_blocks_fragment.glsl` (321), `lib/water.glsl` (325) | fresnel, refraction, reflection, absorption, buffer writes | **queued** (physics ported earlier; contract not audited) |
| `lib/ssao.glsl` | `lib/ao.glsl` (46) | tap pattern, depth linearisation | **queued** |
| `shadow.fsh`, `shadow.vsh` | `common/shadow_*` | `DRAWBUFFERS`, lock, culling | **queued** |

### Distant Horizons and Voxy

| Ours | Reference | Checked | State |
| --- | --- | --- | --- |
| `dh_terrain.*`, `dh_water.*`, `lib/depth_dh.glsl`, `lib/voxy_body.glsl`, `voxy*.glsl`, `voxy.json` | `common/solid_dh_*`, `water_dh.glsl`, `solid_voxy_*`, `voxy.json` | projection, depth, draw buffers | **queued** |

### Options, languages, tools

| Ours | Reference | Checked | State |
| --- | --- | --- | --- |
| `lang/*.lang` | `lang/*.lang` (305 each) | every option has a name in `en_US` | **same** for `en_US`; the eight translations are missing 15 new option names each — **queued** |
| `block.properties`, `item.properties`, `entity.properties`, `dimension.properties` | same | ids resolve, no duplicates, legacy and modern lists | **same** |
| `tools/*.py`, workflows | — | the reference has none; ours check structure, options, textures, stage pairs and compile every stage | **by design** |

## What the audit has found so far

Six defects that would each have stopped the pack from working, in the order they were
found and fixed:

1. buffer format names written as GLSL — no program could compile (`38c9b8d`);
2. `sat()` missing its `vec2` overload — every vertex stage that touches the lightmap
   failed to link (`8e2d897`);
3. the integer `%` operator, which is GLSL 1.30, in the composite and shadow passes
   (`d40a588`);
4. `depthtex0` declared twice in `final` with ambient occlusion on (`7d4dd25`);
5. `texture2DLod` in a vertex stage without the extension (`031c857`);
6. **colortex3 and colortex6 read and written inside one draw, every frame, in every
   profile** — the freeze (`070bdf1`).
7. **`ftransform()` in all sixteen vertex stages.** The reference never calls it: its
   vertex stages write `gl_ModelViewProjectionMatrix * gl_Vertex`, and its own
   `muFtransform()` exists only to fake a two-pixel line width, which is why it still
   reads `gl_Normal`. `ftransform()` is a legacy built-in that a core-profile driver
   does not have and that the mod has to rewrite; with the matrix product written out
   there is nothing to rewrite.

Five of those were compile failures with a clear message. The sixth was silent, which is
why it took a bisection with probe packs to find: the game freezes with nothing in the
log because the driver is waiting on a framebuffer feedback loop, not because anything
in the source is invalid.

## Order of work from here

1. `prepare` back in, and its pass compared line by line with `common/prepare_fragment.glsl`.
2. `final` in full: tone chain, grading, dither, FXAA — compared against
   `common/final_fragment.glsl` function by function.
3. The geometry stage: `vertex_geometry` and `fragment_geometry` against
   `solid_blocks_vertex/fragment` and the four `src/` chunks they include.
4. Water, then sky and clouds, then `shadow`, then Distant Horizons and Voxy.
5. The eight missing translations.
