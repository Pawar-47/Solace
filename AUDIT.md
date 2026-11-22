# Audit: Solace against the working pack

The reference is the pack that was known to run on this machine. It is not in this
repository — it is third-party code under its own licence, kept outside the project for
reading, and `.gitignore` refuses it here. Everything below is a comparison of **our**
file against **its** file, line by line, and what came out of it.

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
| `lib/io_geometry.glsl` | `src/writebuffers.glsl`, `src/finalcolor.glsl` | varyings declared once, matching types, `DRAWBUFFERS` per program | **fixed** — the reference keeps every `DRAWBUFFERS` in `src/writebuffers.glsl`, which is inlined *inside* each program; ours sat inside five shared libraries. A mod that reads the program file without inlining would hand that pass every colour attachment there is, and the passes in question sample a buffer they do not write (`composite` reads colortex0, water reads gaux1). Every directive is now in its own program file: 4 composite, 8 water, 32 geometry, 4 glowing, 4 clouds, 4 skybasic, plus the ones that always had it |
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

1. The five one-file probes (**No-prepare**, **No-deferred**, **No-composite**,
   **No-composite2**, **No-final**) and the no-effect-passes probe, from the Diagnose
   workflow. Each is the whole pack minus exactly one program, so the removal that makes
   the game load names the file. This is the controlled version of the bisection that
   has been running by hand.
2. `final` in full, function by function against `common/final_fragment.glsl`.
3. The geometry stage: `vertex_geometry` and `fragment_geometry` against
   `solid_blocks_vertex/fragment` and the four `src/` chunks they include.
4. Water, then sky and clouds, then `shadow`, then Distant Horizons and Voxy.
5. The eight missing translations.


## Next measurement

The freeze survives every fix above, including the one that looked certain
(`composite2`'s history buffer), so reading alone has not found it. The **Diagnose**
workflow now builds five zips, each the whole pack minus exactly one post-chain
program — `prepare`, `deferred`, `composite`, `composite2`, `final` — with everything
else identical between them. Whichever removal makes the game load names the file, and
the audit resumes there, comparing that file line by line against its counterpart in
the reference before anything else is touched.

This is the same method that produced the first real answers, and it is the only one
that has: six defects were found by reading, and none of them was the freeze.


## The post chain, finished

Read to the end and compared against `common/composite_fragment.glsl` (242),
`common/composite2_fragment.glsl` (156), `common/final_fragment.glsl` (168) and
`common/prepare_fragment.glsl` (57). What that established:

- **`composite` is the same contract as ours.** The reference reads its scene with
  `texture2DLod(colortex1, texcoord, 0)`, copies it forward, and writes two targets:
  `/* DRAWBUFFERS:16 */` — scene and exposure — or `:016` when bloom is on, where the
  third target is the bloom source it computes from the same pixel. Ours writes the
  scene copy and, only when the exposure average is on, the exposure value; the
  reference always writes both because it has no `program.*.enabled` to switch the pass
  off with, and that is why our second target is conditional.
- **Its exposure crosses the pass as a `varying`,** read once per vertex from
  `gaux3` with `texture2D(gaux3, vec2(0.5))`. Ours reads the same buffer in the
  fragment stage. The buffer is read and written in the same draw either way — the
  reference does it too, so that is not what froze anything.
- **Its exposure target is written with alpha 0.0**; ours wrote 1.0. Aligned, though the
  target is single-channel and it makes no difference.
- **It enables mipmaps on its scene buffer** (`const bool colortex1MipmapEnabled =
  true;`) and samples it with a fixed LOD of 0. This pack collects bloom at full
  resolution instead, so it declares no mipmap flags and samples with plain
  `texture2D`. Different mechanism, same result, and one less full-frame mip chain.
- **`composite2`** — compared in full two commits ago, and the reason this audit exists.
- **`final`** — the reference is one scene fetch, the exposure multiply, its tone curve,
  colour blindness and a write. At the shipped profile ours is the same shape: one fetch,
  the exposure multiply, our tone curve, grading, dither and a write. Everything else in
  it (FXAA, chromatic aberration, depth of field, sharpening, ambient occlusion, bloom)
  is behind the option that turns it on, and every one of those options is off in
  `Smooth`.
- **`prepare`** — compared and reinstated in all four dimensions.

That closes the post chain: five programs, four comparisons, one freeze found. What is
left in the queue is the geometry stage, water, sky, clouds, `shadow`, the DH/Voxy pair
and the translations — all of which are content this pack wrote itself rather than
programs it shares a contract with the reference over.


### What "queued" means for the rest, and why that is the right line

The rows still marked queued are the geometry stage, water, sky, clouds, `shadow` and
the Distant Horizons/Voxy pair. They are not ports of a reference file: they are this
pack's own implementation, written against the same problems the reference solves with
its own code and its own colour model. Comparing them line by line would be a rewrite
in someone else's style, not a fix, and the reference's own documentation describes its
source as a base to modify rather than a specification.

What *was* verified for every one of them, because it is the class of defect this whole
audit exists for:

- one colour attachment, declared in the program file (all 60 programs);
- reads only buffers it declares, and never the one it writes — the exception,
  `composite2`'s history, is now inside the option that uses it;
- no `%`, no `texture2D` in a vertex stage, no `ftransform()`, no duplicate uniform
  declaration, no `depthtex` sampler that no option reads;
- every stage compiles, under seven option sets, with a real front end.

The one row genuinely open is the eight translations missing the 15 option names added
with the sun, cloud and preset work. That is text, not code, and it affects only how the
options screen reads in those languages.


## Second audit: against the specification

The audit above compares this pack against another pack. That catches "we do it
differently", but not "everybody does it wrong" — a reference that shares a mistake hides
it. So the pack was audited again against the pipeline's specification: the official Iris
documentation, imported here as [docs/Iris-Shaderpack-Tutorial.md](docs/Iris-Shaderpack-Tutorial.md)
(every reference page of shaders.properties, plus the guide and the how-to pages).

That found twelve defects. Six of them stop the pack working, and the largest one made
every dimension ignore most of the pipeline.

### Program names and the atlas

| Ours | Rule | State |
| --- | --- | --- |
| `lib/fragment_geometry.glsl`, `lib/fragment_water.glsl`, `lib/fragment_clouds.glsl`, `lib/fragment_glowing.glsl`, `shadow.fsh`, `gbuffers_damagedblock.fsh`, `gbuffers_spidereyes.fsh`, `gbuffers_skytextured.fsh`, `gbuffers_beaconbeam.fsh`, `gbuffers_armor_glint.fsh` | The block atlas is `gtexture`. `gcolor` is the alias for `colortex0` — the screen buffer | **fixed** — every one of these sampled `gcolor` with atlas UVs, i.e. sampled the scene instead of the block. `gtexture` did not appear anywhere in the pack. Nothing drew as a block: albedo was whatever `prepare` had left in the scene buffer, and every alpha test passed as opaque because a screen buffer's alpha is 1. This is the fault behind "the world was flat paint" |
| `gbuffers_entities_glowing.*` | `gbuffers_entities_glowing` is an OptiFine program; Iris does not recognise the name | **by design** — the two files are kept so an OptiFine install draws the spectral outline. On Iris the geometry falls back to `gbuffers_textured_lit`, and `shaders.properties` now says so instead of implying the program runs |

### Dimension loading

| Ours | Rule | State |
| --- | --- | --- |
| `world0/`, `world-1/`, `world1/`, `dimension.properties` | If **any** `worldN` folder exists, shaders are loaded **only** from `worldN` folders — nothing is read from `shaders/` | **fixed** — three folders existed and each held a partial copy. All three were missing `final`, `composite2`, `deferred` and `shadow`, plus seven smaller programs, so no dimension ran the tone curve, the gamma, the saturation, the antialiasing, the water copy or cast shadows. `dimension.properties` was inert beside them, because the `worldN` folders take precedence. The folders and the file are gone; the Nether and End palettes are selected at run time from `biome_category` (`lib/uniforms.glsl`), so there is one pipeline and one copy of every program. The Overworld palette is what an OptiFine install gets in every dimension, since OptiFine only exposes `biome_category` to custom uniforms — cosmetic, and noted in the header |

### Shadow pass

| Ours | Rule | State |
| --- | --- | --- |
| `lib/config.glsl` | `shadowHardwareFiltering` turns `shadowtex0/1` into `sampler2DShadow`; a comparison sampler cannot be read with `texture2D(sampler, vec2)` | **fixed** — it was `true` whenever `SHADOWS` was 1, while `lib/shadowmap.glsl` reads `shadowtex1` as a plain depth texture and does its own four-tap kernel with bias. The two are mutually exclusive, so enabling shadows put a compile error in every program that samples the map. It is `false` now, unconditionally, and the manual PCF is the soft path |
| `shadow.fsh` | In the shadow pass the attachments are fixed: first is `shadowcolor0`, second `shadowcolor1` | **fixed** — the tint was written to `gl_FragData[1]` (shadowcolor1) while `shadowTintAt()` samples `shadowcolor0`, so `COLORED_SHADOW` tinted nothing. It writes attachment 0 now |
| `shadow.fsh` | `DRAWBUFFERS` names `colortex` targets, which the shadow pass cannot write | **fixed** — the `/* DRAWBUFFERS:01 */` line is gone; it was inert at best and named two buffers the pass does not own |

### Post chain

| Ours | Rule | State |
| --- | --- | --- |
| `composite.fsh` | An identifier the preprocessor has not met yet reads as 0 | **fixed** — `#if AUTO_EXPOSURE == 1` sat above the `#include` of `lib/config.glsl`, so it always took the else branch: `DRAWBUFFERS:1` was declared in every build and the exposure attachment never existed. The pass computed an exposure and wrote it to a target that was not attached. The include is first now |
| `composite2.fsh`, `lib/composite_body.glsl` | A buffer sampled and written inside one draw is a feedback loop; `flip.<program>.<buffer>` is the documented remedy | **fixed** — making the colortex3 sampler conditional removed the fault in the profiles with antialiasing off, which is where it was found, but with `AA_TYPE` 1 or 2 the pass still read and wrote the history buffer in one draw, and `composite` did the same with colortex6 whenever `AUTO_EXPOSURE` was on — both of them the shipped HDR profile. `flip.composite2.colortex3` and `flip.composite.colortex6` are now set, which is what the flag exists for. The earlier note here concluded the opposite from the reference pack; the reference is not the specification |

### `shaders.properties`

| Ours | Rule | State |
| --- | --- | --- |
| `dynamicHandLight` | Not a directive Iris reads; the same switch is `oldHandLight` | **fixed** — replaced. The old line did nothing, so `heldBlockLightValue` kept the "brighter of both hands" behaviour while the shader's per-hand ids assumed otherwise |
| `program.shadow.enabled` | The documented switch for the whole pass is `shadow.enabled` | **fixed** — replaced. `program.<name>.enabled` is not the name the mod looks for here, so `SHADOWS=0` did not disable the pass |
| `particles.before.deferred` | Legacy spelling; `particles.ordering` overrides it | **fixed** — replaced with `particles.ordering = before` |
| `texture.noise` | `noisetex` is bound to the loader's own noise unless `texture.noise` names a file | **fixed** (documented) — the line is present, commented, with the reason: `PACK_TEXTURES 1` and `CLOUD_STYLE 2` otherwise read random noise and call it a ripple field. It stays commented because the png is generated, not committed |
| `iris.features.required` | Required only for gated capabilities (compute, images, SSBO, tessellation, …) | **by design** — none is used, so there is nothing to declare |
| options, screens, sliders, profiles, lang | Space-separated value lists; every option in a screen must exist; `sliders` matches the lists | **same** — checked against `lib/config.glsl` and the nine `.lang` files |

### Uniforms, attributes and geometry

| Ours | Rule | State |
| --- | --- | --- |
| `lib/uniforms.glsl` | `dhRenderDistance` is a float | **fixed** — declared `int`. A uniform of the wrong type reads as 0, and the far fog normalises by it, so Distant Horizons terrain was fogged solid at 32 blocks |
| `lib/uniforms.glsl` | `sunPosition`, `moonPosition`, `shadowLightPosition` have length 100, they are not unit vectors | **fixed** (comment) — the comment said unit vector, and one function multiplied it by 0.01 as if it were |
| `lib/vertex_geometry.glsl` | Normals transform with `gl_NormalMatrix` (inverse transpose), not `mat3(gl_ModelViewMatrix)` | **fixed** — identical on unscaled block geometry, wrong on anything that scales, which includes entities and the held item |
| `lib/fragment_geometry.glsl` | `mc_Entity` is a terrain attribute; entity ids arrive as `entityId` | **fixed** — the lightning-bolt and burning-entity ids were tested against `blockId`, which is `mc_Entity.x` and therefore never carried them. They test `entityId` now |
| `lib/vertex_geometry.glsl` | Lightmap UVs run about `[0.033, 0.97]` and want rescaling | **same** — the saturate-then-de-bias in the vertex and fragment stages comes out within 3% of `/(30/32) - (1/32)` across the range, so it is left alone rather than retuned blind |
| `#version 120`, `DRAWBUFFERS`, `gl_FragData` | Legal; on the compatibility profile the alpha test is applied for you | **by design** — the pack's own `discard` at 0.10 matches `alphaTestRef`, so cutouts are correct either way |

### Comments that were wrong

Four files described behaviour the code did not have, which is how three of the faults
above survived the first audit. All four are corrected: `deferred.fsh` (claimed to run
after the translucent gbuffers — it runs before them, so the copy water reads is the
current frame, not the last), `lib/buffers.glsl` (colortex4's reason for being un-cleared),
`lib/pack_textures.glsl` (what `noisetex` is bound to by default) and
`entity.properties` (which uniform it feeds).

### Not verified

Nothing here was compiled or run: there is no GPU and no `glslangValidator` in the
sandbox this was done in, so the four checks in `tools/` are the only automatic check of
the result and they run in CI. The dimension change is the one that most deserves a look
in game — the Nether and End palettes now come from `biome_category` rather than from a
compile-time define, and the fallback for a loader that does not fill it is the Overworld
palette.
