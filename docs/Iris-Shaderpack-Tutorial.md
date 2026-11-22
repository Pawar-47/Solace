# Iris Shaderpacks — The Complete Tutorial

A single-file course and reference for writing Minecraft Java shaderpacks for **Iris**
(the open-source shader loader that is integrated with Sodium and compatible with
OptiFine's pipeline). It teaches the practical build first, then documents every
program, attribute, buffer, constant, macro, uniform and `shaders.properties`
directive the loader understands.

Everything here is based on the official Iris documentation at
**https://shaders.properties** (Iris Docs: Reference, Guides and How-To sections),
plus the conventions the docs assume from OptiFine's `shaders.txt`.

---

## Table of contents

**Part 0 — Groundwork**
1. [What Iris is, and what a shaderpack is](#1-what-iris-is-and-what-a-shaderpack-is)
2. [Prerequisites and development environment](#2-prerequisites-and-development-environment)
3. [Core concepts you must have straight](#3-core-concepts-you-must-have-straight)
4. [Shaderpack file layout](#4-shaderpack-file-layout)

**Part 1 — Build a shaderpack from scratch**
5. [Your first shader effect (composite)](#5-your-first-shader-effect-composite)
6. [The gbuffers](#6-the-gbuffers)
7. [Deferred lighting](#7-deferred-lighting)
8. [Shadows](#8-shadows)
9. [Fog](#9-fog)
10. [Next steps and where tutorials stop](#10-next-steps-and-where-tutorials-stop)

**Part 2 — Reference**
11. [Programs](#11-programs)
12. [Attributes](#12-attributes)
13. [Buffers](#13-buffers)
14. [Constants](#14-constants)
15. [Macros](#15-macros)
16. [Uniforms](#16-uniforms)
17. [`shaders.properties`](#17-shadersproperties)

**Part 3 — Auxiliary files, techniques, ecosystems**
18. [Auxiliary `*.properties` files](#18-auxiliary-properties-files)
19. [How-to topics: profiles, coordinate spaces, PBR](#19-how-to-topics-profiles-coordinate-spaces-pbr)
20. [Mod support](#20-mod-support)
21. [Debugging, performance and shipping](#21-debugging-performance-and-shipping)
22. [Cheat sheet](#22-cheat-sheet)

---

# Part 0 — Groundwork

## 1. What Iris is, and what a shaderpack is

**Iris** is a shader loader for Minecraft: Java Edition, built as a Fabric mod and
integrated with the **Sodium** renderer. It loads *shaderpacks*: folders (usually
shipped as `.zip`) containing GLSL programs plus configuration files that replace
or extend how the game draws the world.

A shaderpack has two kinds of work:

- **Real geometry passes** (`gbuffers`, `shadow`): the game feeds the pack the
  actual vertices of terrain, entities, block entities, hand items, weather and
  so on. You decide what to write into the pack's own buffers.
- **Fullscreen passes** (`setup`, `begin`, `shadowcomp`, `prepare`, `deferred`,
  `composite`, `final`): the pack draws one fullscreen triangle/quad per program
  and runs a fragment shader over every pixel of the screen.

A pack is "OptiFine-compatible" if it uses the classic OptiFine pipeline. Iris
implements a superset of that pipeline: everything OptiFine supports works, and
Iris adds extra programs, buffers, uniforms and settings. The documentation marks
those additions **Iris Only / Iris Exclusive**. This tutorial flags them inline.

### Audience and assumptions

The docs are explicit: *you are expected to already know how to code.* A general
grasp of computer graphics helps but is not required. What you do need:

- a text editor,
- a GPU that exposes **OpenGL 3.3** (basically everything),
- Minecraft with Iris, OptiFine or Oculus installed.

Some advanced features need **OpenGL 4.2** (custom images) or **4.3** (SSBOs,
compute shaders). macOS caps OpenGL at 4.1, so those features are unavailable
there (see [macOS](#196-macos-and-the-opengl-ceiling)).

### The two paths through the docs

- **New to shader development** → follow Parts 0 and 1 of this document in order.
- **Migrating a pack from OptiFine** → read [Programs](#11-programs),
  [`shaders.properties`](#17-shadersproperties) and
  [Mod support](#20-mod-support), and watch for **Iris Only** badges.

---

## 2. Prerequisites and development environment

### Minecraft side

Install Iris (with Sodium) through your launcher, then put the pack folder in:
`.minecraft/shaderpacks/<pack-name>/`.

### Editor

Any editor works. VS Code is the community favourite, with two extensions:

- **GLSL Syntax** — syntax highlighting for `.vsh/.fsh/.gsh/.csh/.tcs/.tes`.
- **Language Server for Minecraft Shaderpacks** — completion and validation of
  shaderpack specifics (uniform names, properties, includes).

Both are worth the install: the language server catches typos in uniform names,
which are otherwise painfully silent.

### Logs

Shader compile errors only show up in the game log. Two ways to watch it:

- **Vanilla launcher**: enable *Keep launcher open* and *Open output log* in the
  launcher's installation settings, then watch the log window.
- **Prism/MultiMC launcher**: open the instance → *Logs*.

### Debug mode — turn this on immediately

On the **shader selection screen**, press **Ctrl + D** (Windows/Linux) or
**Cmd + D** (macOS). This toggles Iris **debug mode**. With debug mode on:

- shader compile/link errors are printed to the log with file and line,
- the pack is not silently rejected — you see the failure,
- patched (preprocessed) shader sources are dumped to
  `.minecraft/patched_shaders/`.

Debug mode persists across restarts. Turn it on before you write your first line.

---

## 3. Core concepts you must have straight

### 3.1 OpenGL and GLSL versions

Minecraft historically ran on OpenGL 2.0, which means most older packs are
**GLSL 120**. Minecraft 1.17 moved to OpenGL 3.2 / **GLSL 150**. Iris/OptiFine will
load a program with any version header you choose, so a pack can mix.

This tutorial (like the docs) uses:

```glsl
#version 330 compatibility
```

Why 330? It has modern syntax (`in`/`out`, `layout(location = …)`,
`texture()` instead of `texture2D`) and the `compatibility` profile, which keeps
all the legacy built-ins (`gl_Vertex`, `gl_ModelViewMatrix`, `ftransform()`, …)
that Minecraft shaderpacks depend on.

### 3.2 What "shader" means here

A shader is a **program that runs on the GPU**. Each program is built from
stages:

| Stage | Extension | Required? |
|---|---|---|
| Vertex | `.vsh` | Yes, for every program |
| Fragment | `.fsh` | Yes, for every program |
| Geometry | `.gsh` | Optional (gbuffers-style only) |
| Tessellation control / evaluation | `.tcs` / `.tes` | Optional (gbuffers-style only) |
| Compute | `.csh` | Optional (never with a gbuffers/shadow program) |

File name = `<program_name>.<stage>`: `composite.vsh`, `deferred8.fsh`,
`gbuffers_terrain.gsh`, `setup.csh`.

### 3.3 The two program families

**Gbuffers-style** — real geometry:

- `gbuffers_*` and `shadow` (plus `shadow_*`)
- vertex + fragment required, geometry and tessellation allowed
- compute (`.csh`) is *not* allowed
- these are the only programs that can read **vertex attributes**
  (`gl_Vertex`, `mc_Entity`, `at_tangent`, …)

**Composite-style** — fullscreen:

- `begin`, `shadowcomp`, `prepare`, `deferred`, `composite`, `final`
- one fullscreen quad per program; vertex/geometry/fragment/**compute** allowed
- up to 100 programs per pass (the suffixless one, plus `1`…`99`)
- compute shaders in the pass run before the vertex stage

**Compute-only** — `setup`: runs once on pack load and on window resize.

### 3.4 CPU vs GPU, and why that matters

The CPU issues draw calls sequentially; the GPU runs millions of invocations in
parallel. That is why a shader cannot keep a running counter the way a loop in
Java can — every fragment is racing every other fragment. The tools Iris gives
you to get around this:

- `atomics` on SSBOs / images (parallel-safe increments),
- multiple passes, where pass *n* reads what pass *n−1* wrote to a buffer,
- the ordering guarantees discussed under
  [`allowConcurrentCompute`](#173-programs--ordering).

### 3.5 Rendering model: forward vs deferred

**Forward (vanilla-ish)**: light is applied while drawing each piece of geometry.
Cheap, but each draw call can only see itself, so post-effects are impossible.

**Deferred**: the first set of passes (**gbuffers**) writes raw surface data —
albedo, lightmap coordinates, normals — into screen-sized buffers. Later
fullscreen passes (**deferred**, **composite**) read those buffers back and do
lighting, shadows, fog and post-processing on the whole image. Every pixel of the
image is available to every pixel-shader invocation, so screen-space effects
become possible. This is the architecture every serious Iris pack uses.

---

## 4. Shaderpack file layout

A minimal pack:

```
shaderpacks/MyPack/
├── shaders/
│   ├── composite.vsh
│   ├── composite.fsh
│   ├── gbuffers_terrain.vsh
│   ├── gbuffers_terrain.fsh
│   ├── shadow.vsh
│   ├── shadow.fsh
│   ├── final.vsh
│   ├── final.fsh
│   ├── shaders.properties        ← user options, program toggles, features
│   ├── block.properties          ← block IDs for mc_Entity.x
│   ├── entity.properties         ← entity IDs for entityId
│   ├── item.properties           ← item IDs for heldItemId / currentRenderedItemId
│   ├── dimension.properties      ← per-dimension shader folders
│   ├── lang/
│   │   ├── en_us.lang
│   │   └── de_de.lang
│   ├── textures/
│   │   └── noise.png
│   └── lib/
│       └── util.glsl
└── (optional) LICENSE, README.md
```

Path notation used throughout the docs and this tutorial:

- **`shaders/`** is the pack's root, i.e. the folder holding the shader files.
- A leading `/` in an `#include` or a texture path means "relative to `shaders/`".
- `*` is a wildcard: `*.fsh`, `dimension.nether = minecraft:the_nether *`.
- `<pack>` means your pack folder; `<mc>` is `.minecraft/`.

**Only `shaders/shaders.properties` is special-cased by name.** Everything else
that is not a `.vsh/.fsh/.gsh/.csh/.tcs/.tes/.properties` file is ignored, so you
can keep a README and a LICENSE inside the pack (and you should — packs are
software, respect and state licences).

---

# Part 1 — Build a shaderpack from scratch

The following is the "Your First Shaderpack" tutorial track from the docs,
rebuilt here as one continuous build. Each chapter produces a working pack; each
one builds on the last. Do them in order, check the log after every change, and
look at the result in-game — shader development is entirely visual feedback.

## 5. Your first shader effect (composite)

### 5.1 Get a base

"Base-330" is a minimal community template that has the correct file skeleton
(available from the shaderLABS community). Download it, extract it into
`shaderpacks/`, rename the folder to something like `composite-tutorial`, and
delete its LICENSE/README if you like — but note what a licence says before you
redistribute anything derived from it. Base-330 is released under the Unlicense,
so you are free to do what you want with it.

### 5.2 The vertex shader: `composite.vsh`

```glsl
#version 330 compatibility

out vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
```

Three things to understand:

1. **`#version 330 compatibility`** — Iris *patches* compatibility-profile code
   into modern GLSL internally, and does it better than it patches `core`. There
   is no performance or feature benefit to using `core`; see
   [Compatibility vs. Core](#191-compatibility-vs-core-profiles).
2. **`out` / `in` varyings** — `out` in the vertex shader becomes `in` in the
   fragment shader, interpolated across the triangle. By default values are
   perspective-correct interpolated; add `flat` (`flat out int foo;`) to disable
   interpolation for integer-like data.
3. **`ftransform()`** — the deprecated-but-patched "model space → clip space"
   helper. It is exactly equivalent (after patching) to
   `gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex`. Iris patches it, so
   it keeps working in every profile.
4. **UVs** — `(0,0)` is the bottom-left, `(1,1)` the top-right of the surface.
   `gl_TextureMatrix[0]` *must* be applied: it is usually identity, but not for
   things like the enchantment glint.
   Swizzling (`.xy`, `.rgb`, `.xyz`) selects components.

### 5.3 The fragment shader: `composite.fsh`

```glsl
#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    color = texture(colortex0, texcoord);
}
```

- **`colortex0`** is the main scene buffer: the game has already drawn the whole
  world into it before `composite` runs. It is screen-sized. There are 16 of
  these by default (`colortex0`…`colortex15`; 32 since Iris 1.10.5).
- **`/* RENDERTARGETS: 0 */`** tells Iris which buffer(s) this program writes
  into. It must be a **block comment on its own line**, and it is read by Iris,
  never reaching the GPU.
- **`layout(location = 0) out vec4 color;`** binds this output variable to the
  *first entry of the RENDERTARGETS list* — not to `colortex0` by number. Write
  `/* RENDERTARGETS: 5,3 */` and `location = 0` writes `colortex5`.

### 5.4 Your first effect

```glsl
void main() {
    vec4 albedo = texture(colortex0, texcoord);
    float grayscale = dot(albedo.rgb, vec3(1.0 / 3.0));
    albedo.rgb = vec3(grayscale);
    color = albedo;
}
```

(The local variable cannot be called `color` — that name is taken by the output
variable.) `dot(rgb, vec3(1.0/3.0))` is a fast, slightly-wrong
luminance: it weights red, green and blue equally. The perceptually correct
version uses `vec3(0.2126, 0.7152, 0.0722)` (Rec. 709) or `vec3(0.299, 0.587,
0.114)` (Rec. 601).

**Exercise:** make the left half red and the right half green using `texcoord`:

```glsl
color.rgb = texcoord.x < 0.5 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
```

You now have a working post-processing pipeline. Everything else in this tutorial
is the same pattern: read buffers, compute, write buffers.

---

## 6. The gbuffers

`gbuffers_*` programs are where the world is actually drawn. To see what they do,
strip a fresh copy of Base-330 down to only:

- `composite.vsh` / `composite.fsh`
- `gbuffers_terrain.vsh` / `gbuffers_terrain.fsh`
- `final.vsh` / `final.fsh` (once we get to gamma in the next chapter)

**Delete every other `gbuffers_*` and `deferred*` file.** Missing programs
**fall back** along the chain in [the fallback table](#1111-gbuffers) — entities
fall back to `gbuffers_textured_lit`, that to `gbuffers_textured`, and so on —
and any geometry with nowhere left to fall back to uses Iris's built-in default
program. That is why a pack with only one gbuffers program still draws the whole
world, and why the result looks wrong in specific, predictable ways.

### 6.1 Vertex outputs: UVs, lightmap, colour, normal

```glsl
#version 330 compatibility

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = ftransform();

    // atlas UV
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    // lightmap UV, rescaled
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);

    // vertex colour (biome tint, vanilla AO)
    glcolor = gl_Color;

    // normal: model -> view -> player space
    normal = gl_NormalMatrix * gl_Normal;
    normal = mat3(gbufferModelViewInverse) * normal;
}
```

Details worth memorising:

- **`texcoord` in a gbuffers program is an *atlas* coordinate**, not a 0–1 UV
  into a single texture. `gtexture` is the block atlas; the UV selects a tile out
  of it.
- **`gl_MultiTexCoord1` is the lightmap coordinate.** Its raw range is roughly
  `[0.033, 0.97]` (the first half-texel is unusable), so rescale it to `[0,1]`
  by dividing by `30/32` and subtracting `1/32`. `x` = **block light**,
  `y` = **sky light**.
- **`gl_Color`** is vertex colour: biome tint (grass, leaves, water) plus
  vanilla ambient occlusion. Setting it to `vec4(1.0)` removes the grass tint —
  great for debugging, wrong for shipping.
- **Normals**: `gl_NormalMatrix * gl_Normal` takes *model space → view space*.
  Multiplying by `mat3(gbufferModelViewInverse)` then converts *view space →
  player space* (world-axis-aligned, camera-relative). Store normals in
  **player space**: it is the space deferred passes want, and it survives the
  precision loss of an 8-bit buffer far better than world space does.

### 6.2 Fragment: albedo and lightmap

```glsl
#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D lightmap;

uniform float alphaTestRef;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    color *= texture(lightmap, lmcoord);

    if (color.a < alphaTestRef) discard;

    lightmapData = vec4(lmcoord, 0.0, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
}
```

- `gtexture` (the block atlas) and `lightmap` (vanilla's lightmap texture) are
  bound automatically in gbuffers programs.
- **`if (color.a < alphaTestRef) discard;`** reproduces the vanilla alpha cutout.
  Without it, cutout textures (leaves, fences, grass) render as opaque squares.
  `alphaTestRef` defaults to `0.1` and can be overridden per program with the
  `alphaTest.<program>` directive.
- **`RENDERTARGETS: 0,1,2`** with three `layout(location = …)` variables writes
  three buffers in one pass. `location` indexes **the list order**. If you write
  `/* RENDERTARGETS: 5,3 */`, then location `0` → `colortex5` and location `1` →
  `colortex3`.
- **Buffers default to RGBA8**, so a value stored in a channel must be in
  `[0,1]`. Hence `normal * 0.5 + 0.5` to encode `[-1,1]`, and hence **alpha must
  be `1.0`** in these data buffers — the alpha channel is not free.
- Buffers **persist across frames** unless cleared, and can be **flipped**
  (double-buffered) per program with `flip.<program>.<buffer>`.

At this point `composite` can stop sampling the lit screen and do its own
lighting instead. That is the next chapter.

> **Why the hand is missing / why everything looks translucent:** while only
> `gbuffers_terrain` exists, every other geometry group falls back to a
> different program. This is expected; see
> [the fallback table](#1111-gbuffers) and [Next steps](#10-next-steps-and-where-tutorials-stop).

---

## 7. Deferred lighting

### 7.1 Gamma: work in linear light

Textures and the framebuffer are **sRGB-encoded**: a stored value of `0.5` is
perceived as mid-grey but represents about `0.21` of the actual light. Adding and
multiplying sRGB values produces physically wrong results (too-dark shadows,
washed-out highlights). So:

- **in**, right after sampling: `color.rgb = pow(color.rgb, vec3(2.2));`
- **out**, in `final`: `color.rgb = pow(color.rgb, vec3(1.0/2.2));`

Create `final.vsh` (same as `composite.vsh`) and `final.fsh`:

```glsl
#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

layout(location = 0) out vec4 color;

void main() {
    color = texture(colortex0, texcoord);
    color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
}
```

`final` is the last pass and writes to the **backbuffer** (always window
resolution, regardless of the `scale` setting). Only one `final` can exist — and
because there is exactly one destination, `final` needs no `RENDERTARGETS`
comment.

### 7.2 Buffer precision

RGBA8 gives you 256 levels per channel; for normals and light data that bands
visibly. Raise the format — **in a block comment, on its own line**:

```glsl
/*
const int colortex0Format = RGB16;
*/
```

Iris parses this comment; it never reaches the GPU. `RGB16` gives 65 535 levels
per channel instead of 255 (16.7 M colours → 2.8 × 10¹⁴). The cost is VRAM:
16-bit triple-channel instead of 8-bit quad-channel is a 50 % increase per
buffer, and you have a dozen of them. Full catalogue of formats:
[Image formats](#1311-image-formats).

### 7.3 Reading the gbuffer data

```glsl
#version 330 compatibility

uniform sampler2D colortex0;   // lit scene (vanilla result)
uniform sampler2D colortex1;   // lightmap UVs
uniform sampler2D colortex2;   // player-space normals
uniform sampler2D depthtex0;   // scene depth

uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor   = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor   = vec3(1.0);
const vec3 ambientColor    = vec3(0.1);

void main() {
    color = texture(colortex0, texcoord);

    // early out on the sky
    float depth = texture(depthtex0, texcoord).r;
    if (depth == 1.0) return;

    vec4 data = texture(colortex1, texcoord);
    vec2 lightmap = data.rg;

    vec3 normal = normalize((texture(colortex2, texcoord).rgb - 0.5) * 2.0);

    color.rgb = pow(color.rgb, vec3(2.2));

    vec3 lighting = blocklightColor * lightmap.x
                  + skylightColor   * lightmap.y
                  + ambientColor;

    vec3 worldLightVector = mat3(gbufferModelViewInverse) * shadowLightPosition;
    lighting += sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * lightmap.y;

    color.rgb *= lighting;
}
```

Notes:

- **`if (depth == 1.0) return;`** — the sky. Fog and lighting applied to the sky
  looks obviously wrong, and it also costs performance. Note that depth is
  **non-linear**: it is not a distance, and `1.0` is the far plane exactly.
- **`shadowLightPosition`** is the sun by day and the moon by night, in **view
  space**, length always `100.0`. Normalise it, then rotate into player space
  with `mat3(gbufferModelViewInverse)` so it is comparable with stored normals.
- `clamp(dot(L, N), 0.0, 1.0)` is Lambert diffuse; multiplying by `lightmap.y`
  means the sun only lights surfaces the sky can see.
- Vanilla already applied its own lighting to `colortex0`. Multiplying by our
  lighting **on top** double-lights; the clean approach — used by real packs — is
  to have `gbuffers` write **raw albedo** (no lightmap multiply) and let
  `composite` do all of the lighting. The line
  `color *= texture(lightmap, lmcoord);` in `gbuffers_terrain.fsh` is what you
  delete to do that.

---

## 8. Shadows

This is the longest chapter, because shadows are where most packs live or die.

### 8.1 The shadow pass

`shadow.vsh` / `shadow.fsh` are almost copies of `gbuffers_terrain`. You only
need `texcoord` and `glcolor`:

```glsl
// shadow.vsh
#version 330 compatibility

out vec2 texcoord;
out vec4 glcolor;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
}
```

```glsl
// shadow.fsh
#version 330 compatibility

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 color;

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    if (color.a < 0.1) discard;
}
```

Key differences from a gbuffers fragment shader:

- **No `/* RENDERTARGETS: … */`.** In the shadow pass, `location = 0` writes
  `shadowcolor0` (there are two: `shadowcolor0`, `shadowcolor1`). `colortex*` is
  **not writable** here.
- `discard` here is what makes **transparent shadows** (leaves, glass, fences)
  work at all.
- Depth is written automatically by the rasteriser into `shadowtex0`/`shadowtex1`.

### 8.2 Reading the shadow map

```glsl
uniform sampler2D shadowtex0;

// ...
color.rgb = texture(shadowtex0, texcoord).rgb;
```

That is a useful sanity check — it shows you the shadow map itself as colour.

### 8.3 The shadow-space transform chain

To know whether a pixel is shadowed you must take its **screen position**, turn it
back into a position in the world, and then project *that* with the light's
matrices. In shader code:

```glsl
// utility: perspective divide, safely
vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}
```

```glsl
// in composite.fsh
float depth = texture(depthtex0, texcoord).r;
if (depth == 1.0) return; // sky

// 1. screen -> NDC
vec3 NDC = vec3(texcoord, depth) * 2.0 - 1.0;

// 2. NDC -> view space
vec4 viewPos = gbufferProjectionInverse * vec4(NDC, 1.0);
viewPos /= viewPos.w;

// 3. view -> feet player space
vec3 feetPlayerPos = (gbufferModelViewInverse * viewPos).xyz;

// 4. player space -> shadow view space
vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;

// 5. shadow view -> shadow clip -> shadow screen space
vec3 shadowScreenPos = projectAndDivide(shadowProjection, shadowViewPos) * 0.5 + 0.5;
```

Then a single comparison gives you the shadow factor:

```glsl
float shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
color.rgb *= shadow;
```

`step(edge, x)` returns `0.0` when `x < edge` and `1.0` otherwise — so the pixel
is lit when the stored shadow depth is nearer than the pixel's own depth.

### 8.4 Shadow acne, and the bias

Surfaces shadow themselves because the depth stored in the shadow map and the
depth computed for the same point differ by float rounding. The classic fix is a
small bias along the light direction:

```glsl
shadowScreenPos.z -= 0.001;
```

Do this **before** sampling. Too much bias causes **peter-panning** (shadows
detaching from their objects); too little leaves acne. Tune per pack.

### 8.5 Resolution and interval

```glsl
const int shadowMapResolution = 2048;
```

Square, in pixels, for both `shadowtex*` and `shadowcolor*`. Doubling it
quadruples shadow VRAM and costs fill rate; 2048 is the usual sweet spot, 4096
for high-end packs.

Declare it as **real code**, not in a block comment: this one you will actually
reference (a PCF kernel offsets its taps by `1.0 / shadowMapResolution`). Iris
reads a `const` from either place; only the block-comment form is necessary when
the value would not be valid GLSL — as with format names like `RGB16`.

`shadowIntervalSize` snaps shadow geometry to a grid so the shadow map does not
shimmer as you walk:

```glsl
/*
const float shadowIntervalSize = 2.0;
*/
```

`0.0` disables snapping.

### 8.6 Distortion — making shadow texels go further

A flat shadow map wastes most of its area around the camera and on the far
plane. Standard distortion stretches it so nearby texels get more resolution.
Put it in a library file, `shaders/lib/distort.glsl`:

```glsl
vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy);
    distortionFactor += 0.1;              // avoid divide-by-zero at the centre
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z  *= 0.5;
    return shadowClipPos;
}
```

Apply it **twice, symmetrically**:

- in the **shadow vertex shader**, to `gl_Position.xyz` after the projection;
- in the **consumer** (composite), to the sample position *after* the bias.

If you apply it in only one of the two places, the shadow map will look correct
but be sampled in the wrong spot.

`shadowDistanceRenderMul` must be positive for any of this to pay off:

```glsl
/*
const float shadowDistance = 160.0;
const float shadowDistanceRenderMul = 1.0;
*/
```

- `shadowDistance` (blocks) **scales the projection** — it does not cull anything
  on its own.
- `shadowDistanceRenderMul = -1.0` (the default) means *no culling*: geometry
  outside `shadowDistance` still renders into the map.
- `1.0` culls at `1 × shadowDistance`, `0.5` at half, `2.0` at double. It does
  **not** scale the geometry — it only culls.

### 8.7 Transparent shadows

The three shadow buffers:

- `shadowtex0` — **all** geometry, including translucent,
- `shadowtex1` — **opaque only**,
- `shadowcolor0` — the colour your `shadow.fsh` wrote (including its alpha).

That lets you distinguish "lit", "in opaque shadow" and "behind stained glass":

```glsl
float getShadow(vec3 shadowScreenPos, vec3 normal, vec2 lightmap) {
    vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
    float opaqueDepth = texture(shadowtex1, shadowScreenPos.xy).r;

    // is there any opaque geometry in front of us?
    float opaqueShadow = step(shadowScreenPos.z, opaqueDepth);

    // translucent geometry tints rather than blocks
    vec3 tint = shadowColor.rgb * (1.0 - shadowColor.a);

    return mix(tint, vec3(1.0), opaqueShadow);
}
```

### 8.8 Soft shadows

Hard `step()` shadows are aliased. Two cheap improvements:

```glsl
/*
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;
*/
```

Nearest-neighbour sampling makes every sample a crisp read, which is what you
want when you are doing your own filtering — filtering twice (hardware + your
kernel) turns a PCF kernel into mush.

**PCF** (percentage-closer filtering) averages a grid of taps:

```glsl
#define SHADOW_RADIUS 1.0
#define SHADOW_RANGE  4

float getSoftShadow(vec4 shadowClipPos) {
    float shadow = 0.0;
    float samples = 0.0;

    for (int x = -SHADOW_RANGE; x <= SHADOW_RANGE; x++) {
        for (int y = -SHADOW_RANGE; y <= SHADOW_RANGE; y++) {
            // offset in shadow-clip space, converted to texel size
            vec4 offsetClipPos = shadowClipPos;
            offsetClipPos.xy += vec2(x, y) * SHADOW_RADIUS / shadowMapResolution;

            vec3 distorted = distortShadowClipPos(offsetClipPos.xyz);
            vec3 shadowScreen = distorted * 0.5 + 0.5;

            shadow += step(shadowScreen.z, texture(shadowtex1, shadowScreen.xy).r);
            samples++;
        }
    }
    return shadow / samples;
}
```

The loop costs `(2 * SHADOW_RANGE + 1)²` taps per pixel. With `SHADOW_RANGE = 4`
that is 81 — too expensive at 4K, which is why real packs rotate the kernel:

```glsl
uniform sampler2D noisetex;
uniform float viewWidth;
uniform float viewHeight;

// per-pixel rotation angle from the noise texture
ivec2 coord = ivec2(gl_FragCoord.xy) % 64;
float noise = texelFetch(noisetex, coord, 0).r;
float theta = noise * radians(360.0);
float cosTheta = cos(theta);
float sinTheta = sin(theta);
mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
```

Apply `rotation` to the kernel offsets. Rotating per pixel turns a regular grid
(visible as banding) into noise, which the eye forgives and which a cheap blur
removes. A **Vogel disk** or **interleaved gradient noise** offset set is the
modern version of the same idea.

### 8.9 What the shadow pass needs from `shaders.properties`

```properties
shadowTerrain       = true   # blocks
shadowTranslucent   = true   # translucent geometry into the shadow map
shadowEntities      = true   # entities
shadowPlayer        = true   # the player model (forced on with shadowEntities)
shadowBlockEntities = true
shadowLightBlockEntities = true
```

Also useful: `shadow.culling=reversed` (see
[the rendering directives](#175-rendering)) and

```glsl
/*
const float shadowDistance = 160.0;
const float sunPathRotation = 0.0;
const float shadowMapFov = 90.0;
*/
```

`sunPathRotation` (degrees) tilts the sun's arc; `0.0` passes it directly
overhead. `shadowMapFov` switches the shadow projection from **orthographic**
(the default) to a perspective-like one — used by packs that want a
higher-resolution near field. `voxelDistance` + `REVERSED_CULLING` are the modern
way to get distant shadows without culling.

---

## 9. Fog

Create a new pass: copy `composite.vsh` to `composite1.vsh`, and start
`composite1.fsh` from `composite.fsh` with the colour/depth boilerplate only.

```glsl
#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D colortex1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 fogColor;
uniform float far;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    color = texture(colortex0, texcoord);

    float depth = texture(depthtex0, texcoord).r;
    if (depth == 1.0) return;

    vec4 viewPos = gbufferProjectionInverse * (vec4(texcoord, depth, 1.0) * 2.0 - 1.0);
    viewPos /= viewPos.w;

    // linear distance from the camera in blocks; `far` is the render distance
    float dist = length(viewPos.xyz) / far;

    color.rgb = pow(color.rgb, vec3(2.2));
    color.rgb = mix(color.rgb, pow(fogColor, vec3(2.2)), dist);
}
```

- **`far` is the render distance in blocks**, not the far clip plane (which is
  roughly `4 × far`).
- `fogColor` is vanilla's horizon colour and already carries biome, time-of-day
  and view direction. `pow(…, 2.2)` puts it in the same linear space as your
  scene.
- Names like `projectAndDivide` are worth factoring into `shaders/lib/util.glsl`
  and pulling in with `#include "/lib/util.glsl"` — a leading `/` means "relative
  to `shaders/`", no `/` means "relative to this file".

### 9.1 Exponential falloff

A linear fade looks like a wall of grey. Real fog attenuates exponentially
(Beer–Lambert):

```glsl
#define FOG_DENSITY 5.0

float fogFactor = exp(-FOG_DENSITY * (1.0 - dist));
color.rgb = mix(color.rgb, pow(fogColor, vec3(2.2)), clamp(fogFactor, 0.0, 1.0));
```

- The `clamp` matters: **diagonal** distances exceed `far`, so `dist > 1.0` at
  the corners of the screen; a negative multiplier turns `exp()` into a growing
  value, and `mix()` with a factor outside `[0,1]` is undefined behaviour
  (extrapolation) — it will look wrong on some GPUs and not others.
- **Watch out for double fog.** Vanilla already mixed its own fog into
  `colortex0` while drawing terrain, so fog added here stacks on top of it — the
  horizon gets fogged twice. Either accept it, or write raw albedo in the
  gbuffers (drop the lightmap multiply) and apply fog exactly once, here.
- If your pack renders translucent geometry and you are fogging, the pass order
  matters: `deferred` runs *between* opaque and translucent gbuffers, so fog in
  `composite` fogs translucents too. Fogging in `deferred` leaves water and
  glass unfogged — usually what you want.

---

## 10. Next steps and where tutorials stop

### 10.1 Two bugs you now have, and how to fix them

**Entities look wrong / translucent.** Now that only `gbuffers_terrain` exists,
entities fall back to `gbuffers_textured_lit` — a *different* program than the one
you wrote. Fix: **rename** `gbuffers_terrain` to `gbuffers_textured_lit`, which is
what most geometry groups fall back to, so your shader is used almost
everywhere. (Or write all the programs, which is what a real pack does.)

**Nights are blindingly bright.** `skylightColor` is a constant. Drive it from the
world clock:

```glsl
uniform int worldTime;   // 0..23999

// ...

float daylight = smoothstep(0.0, 0.05, ...);  // or use sunAngle
```

The standard approach is `sunAngle` / `shadowAngle` (`0` sunrise, `0.25` noon,
`0.5` sunset, `0.75` midnight) or `worldTime` (sunrise at ~`23215`, sunset at
~`12785`), feeding a smooth ramp between day, sunset and night colour sets. Also
use `rainStrength`, `wetness` and `thunderStrength` to desaturate and darken.

### 10.2 A realistic project list

Once the tutorial pack works, these are the natural next projects, roughly in
order of difficulty:

1. **Custom sky and atmosphere** — a skybox pass with a physically-plausible
   gradient, sun disc, moon with phase (`moonPhase`), and stars.
2. **Waving water and foliage** — vertex-shader displacement driven by
   `frameTimeCounter` and world position; `gl_Vertex`/`vaPosition`, plus
   `mc_Entity` to select blocks.
3. **Better shadow filtering** — Vogel disks, interleaved gradient noise, PCSS
   for contact-hardening shadows.
4. **Tonemapping** — ACES, AgX or Uncharted 2 curves in `composite`, plus
   exposure driven by `eyeBrightness` or an average-luminance pass.
5. **Volumetric clouds** — ray-marched from the depth buffer + `cloudHeight`.
6. **Cook-Torrance specular** — needs labPBR `_s` maps (see
   [PBR standards](#193-pbr-standards)), `at_tangent` for a TBN basis, and
   `shadowtex*` for shadowing.
7. **SSAO** — hemisphere sampling in view space from `depthtex0`, edge-aware blur.
8. **SSR** — raymarch the depth buffer, fade with roughness.
9. **HDR bloom** — an `RGBA16F` buffer, a mip chain with `colortexNMipmapEnabled`,
   then add the result back.
10. **TAA / reprojection** — `gbufferPreviousModelView`,
    `gbufferPreviousProjection`, `previousCameraPosition`.

### 10.3 Where to get help

- **shaderLABS Discord** — the main shader-development community; the docs
  themselves grew out of it.
- **Bálint's shader resource list** — curated links to tutorials and references.
- **OptiFine's `shaders.txt`** — the original specification of the pipeline.
- **Iris ShaderDoc** — the community reference for Iris behaviour.
- **The Iris Docs site itself** (`shaders.properties`) — every reference page
  in Parts 2 and 3 of this document.


---

# Part 2 — Reference

## 11. Programs

### 11.1 Overview

Program filename: `<program>.<stage>`.

| Stage | Extension |
|---|---|
| Compute | `.csh` |
| Vertex | `.vsh` |
| Geometry | `.gsh` |
| Fragment | `.fsh` |
| Tessellation control / evaluation | `.tcs`, `.tes` |

Examples: `composite.vsh`, `deferred8.fsh`, `gbuffers_terrain.gsh`, `setup.csh`.

### 11.2 Execution order

This is the single most important table in the whole pipeline:

1. `setup` (suffixless, 1–99) — **compute-only**
2. `begin` (suffixless, 1–99) — composite-style
3. `shadow` — gbuffers-style
4. `shadowcomp` (suffixless, 1–99) — composite-style
5. `prepare` (suffixless, 1–99) — composite-style
6. `gbuffers` — **opaque** geometry
7. `deferred` (suffixless, 1–99) — composite-style
8. `gbuffers` — **translucent** geometry
9. `composite` (suffixless, 1–99) — composite-style
10. `final` — composite-style (only one allowed, no suffix)

Apart from the opaque/translucent split around `deferred`, **the order of the
individual gbuffers programs is not fixed** — do not build effects that depend on
`gbuffers_terrain` running before `gbuffers_entities`.

### 11.3 The three families

**Gbuffers-style** (`gbuffers_*`, `shadow`, `shadow_*`):

- real geometry, vertex + fragment **required**
- geometry and tessellation allowed; **compute not allowed**
- the only programs that can read **vertex attributes**

**Composite-style** (`begin`, `shadowcomp`, `prepare`, `deferred`, `composite`,
`final`):

- one fullscreen quad; up to **100** programs per pass (suffixless + 1–99)
- vertex / fragment / geometry / **compute** all allowed
- compute shaders in a pass run **before** the vertex stage

**Compute-only** (`setup`):

- runs when the pack loads and when the screen is resized
- used to initialise buffers, build LUTs, precompute noise — anything static

### 11.4 Compute shaders

- Require **OpenGL 4.3** (so: not macOS).
- Declaration:

```glsl
#version 430 core

layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

void main() {
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    // ...
}
```

- Up to **27 compute shaders per pass**, with suffixes `_a` … `_z`, executed in
  **alphabetical order** (unless `allowConcurrentCompute`).
- Work-group count comes from one of:
  - `const ivec3 workGroups = ivec3(x, y, z);`
  - `const vec2 workGroupsRender = vec2(x, y);` — default `vec2(1.0, 1.0)`
  - `indirect.<pass> = <ssboIndex> <offsetBytes>` in `shaders.properties`
- **Compute shaders cannot write colour attachments.** Use `imageStore` on an
  `image2D` (from a [custom image](#139-custom-images-iris-only)) or an SSBO.
- Dispatch size in `workGroupsRender` terms:

```glsl
gl_NumWorkGroups == uvec3(
    ceil(vec2(viewWidth, viewHeight) * workGroupsRender / vec2(gl_WorkGroupSize.xy)),
    1u
);
```

### 11.5 Tessellation

- gbuffers-style programs only (`.tcs` + `.tes` alongside `.vsh`/`.fsh`).
- **Triangles only** (no quads or isolines).
- Requires the `TESSELLATION_SHADERS` feature flag; Iris accepts the misspelled
  `TESSELATION_SHADERS` too.

### 11.6 `setup`

Iris only. Compute-only. Runs at pack load and on every screen resize. Suffixes
`1`–`99` plus the suffixless one.

Use it for: zeroing buffers, filling a noise/LUT texture, initialising an SSBO.

### 11.7 `begin`

Iris only. Composite-style, runs **before** `shadow`. Writes `colortex`.

Use it for data the shadow pass needs — e.g. a heightmap of the scene, or a
precomputed light grid — that cannot be produced after `shadow`.

### 11.8 `shadow`

Buffers-style. **One** `.vsh` + `.fsh` pair for all geometry in the pass;
distinguish geometry with the `renderStage` uniform.

- Orthographic projection by default; `shadowMapFov` changes it.
- Outputs: `shadowcolor0/1` (via `layout(location = N)`) and `shadowtex0/1`
  (depth, automatic).
- `colortex*` is **not writable** in this pass.

Iris 1.8+ adds split shadow programs, each with independent geometry control:

| Program | Geometry |
|---|---|
| `shadow_solid` | solid terrain |
| `shadow_cutout` | cutout terrain |
| `shadow_water` | translucent terrain / water |
| `shadow_entities` | entities |
| `shadow_block` | block entities |

Fallback order: the split program → `shadow` → a built-in default.

### 11.9 `shadowcomp`

Composite-style, runs directly after `shadow`. Writes `shadowcolor`. Suffixes
1–99. Used to blur or otherwise process the shadow map before it is sampled.

### 11.10 `prepare`

Composite-style, after `shadow`/`shadowcomp`, before any gbuffers. Writes
`colortex`. Anything the gbuffers programs will want to read must be produced
here.

### 11.11 `gbuffers`

Where all world geometry is drawn: terrain, entities, block entities, particles,
the hand, weather, the sky. Missing programs **fall back** to another program in
the pack.

| Program | Geometry | Falls back to |
|---|---|---|
| `gbuffers_basic` | leash, debug chunk border overlay | N/A |
| `gbuffers_line` | block outline, fishing line | `gbuffers_basic` |
| `gbuffers_textured` | world border, particles that don't support lighting | `gbuffers_basic` |
| `gbuffers_textured_lit` | particles that support lighting (most particles) | `gbuffers_textured` |
| `gbuffers_skybasic` | sky colour/horizon, stars, void | `gbuffers_basic` |
| `gbuffers_skytextured` | sun and moon textures | `gbuffers_textured` |
| `gbuffers_clouds` | vanilla clouds | `gbuffers_textured` |
| `gbuffers_terrain` | static blocks | `gbuffers_textured_lit` |
| `gbuffers_damagedblock` | block breaking texture | `gbuffers_terrain` |
| `gbuffers_block` | block entities, sign text | `gbuffers_terrain` |
| `gbuffers_beaconbeam` | beacon beam | `gbuffers_textured` |
| `gbuffers_entities` | entities, nametag text | `gbuffers_textured_lit` |
| `gbuffers_armor_glint` | enchantment effect on items/armour | `gbuffers_textured` |
| `gbuffers_spidereyes` | spider/enderman/dragon eyes | `gbuffers_textured` |
| `gbuffers_hand` | player hand and held objects | `gbuffers_textured_lit` |
| `gbuffers_weather` | falling rain/snow (not particles) | `gbuffers_textured_lit` |
| `gbuffers_water` | translucent terrain (incl. water) | `gbuffers_terrain` |
| `gbuffers_hand_water` | translucent held objects | `gbuffers_hand` |

**Not recognised by Iris:** OptiFine's `gbuffers_entities_glowing` (the spectral
effect, not the outline).

**Iris additions:**

| Program | Geometry | Falls back to |
|---|---|---|
| `gbuffers_particles` | particles | `gbuffers_textured_lit` |
| `gbuffers_particles_translucent` | particles that support translucency (needs `particles.ordering=mixed`) | `gbuffers_particles` |
| `gbuffers_block_translucent` | translucent block entities | `gbuffers_block` |
| `gbuffers_entities_translucent` | translucent entities | `gbuffers_entities` |
| `gbuffers_terrain_solid` | solid terrain only | `gbuffers_terrain` |
| `gbuffers_terrain_cutout` | cutout terrain only | `gbuffers_terrain` |
| `gbuffers_lightning` | lightning, ender dragon death beams | `gbuffers_entities` |

**Why the extra translations exist.** In old OptiFine, only
`gbuffers_weather`, `gbuffers_water` and `gbuffers_hand_water` render **after**
`deferred`. Translucent entities, block entities and particles all rendered
*before* it, so a pack using deferred lighting could not light them correctly.
Iris adds the three `*_translucent` programs (use with the `ENTITY_TRANSLUCENT`
flag) and lets `particles.ordering` move particles.

**Gotcha:** the ender dragon's death beams write their **colour** in
`gbuffers_lightning` but their **depth** in `gbuffers_basic`. If you write depth
in one and colour in the other, beams look broken.

### 11.12 `deferred`

Composite-style, runs between **opaque** and **translucent** gbuffers. Suffixes
1–99. This is where deferred lighting conventionally lives, so that water and
glass — which come after — can be lit correctly using the now-finished
light buffer.

### 11.13 `composite`

Composite-style, after **all** gbuffers. Suffixes 1–99. The post-processing
stage: fog, bloom, tonemapping, colour grading, FXAA.

### 11.14 `final`

The last pass. Writes to the **backbuffer**, which is always at **window
resolution** regardless of the `scale` setting. Only one `final` may exist (no
suffix).

---

## 12. Attributes

Attributes are **per-vertex** data. They are available **only in vertex
shaders**, only in gbuffers-style programs. Pass them onward with a `varying`
(`out` in the vertex shader, `in` in the fragment shader) or write them into a
buffer.

| Attribute | Type | Meaning |
|---|---|---|
| `gl_Vertex` | `vec4` | model-space position |
| `gl_Normal` | `vec3` | model-space normal, **not** normalised |
| `gl_Color` | `vec4` | vertex colour (biome tint + AO) |
| `gl_MultiTexCoord0` | `vec4` | atlas UV |
| `gl_MultiTexCoord1` | `vec4` | lightmap UV |
| `mc_Entity` | `vec2` | block ID + render type (Iris/OptiFine) |
| `mc_midTexCoord` | `vec2` | UV of the quad's texture centre |
| `at_tangent` | `vec4` | tangent + handedness |
| `at_midBlock` | `vec4` | offset to block centre (Iris) |
| `mc_chunkFade` | `float` | chunk fade (Iris) |
| `vaUV1` | `ivec2` | entity overlay (core profile) |

### 12.1 `gl_Vertex` / `vaPosition`

Model-space position of the vertex.

```glsl
vec3 modelPos = gl_Vertex.xyz;
gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(modelPos, 1.0);
```

Core profile:

```glsl
in vec3 vaPosition;
in vec3 chunkOffset;      // NOT modelOffset — see below

vec3 modelPos = vaPosition + chunkOffset;
vec4 viewPos = modelViewMatrix * vec4(modelPos, 1.0);
gl_Position = projectionMatrix * viewPos;
```

`chunkOffset` is non-zero only while rendering terrain. Vanilla renamed it to
`modelOffset` in 1.21.2; **Iris did not follow**, so `chunkOffset` is the name to
use.

### 12.2 `gl_Normal` / `vaNormal`

Model-space normal — and **not guaranteed to be normalised**, which surprises
people. Always `normalize()` after transforming:

```glsl
vec3 normal = normalize(gl_NormalMatrix * normalize(gl_Normal));
```

Core profile: `vec3 normal = normalize(normalMatrix * vaNormal);`

### 12.3 `gl_Color` / `vaColor`

Vertex colour, carrying **biome tints**, **vanilla ambient occlusion**, and (if
`oldLighting` is enabled) vanilla's per-vertex directional shading.

With the `separateAo` directive, vanilla AO is moved into the **alpha** channel:

```properties
separateAo = true
```

```glsl
vec3 color = gl_Color.rgb * gl_Color.a;   // recombine
```

> **Bug:** `separateAo` requires the shadow pass to be enabled to work at all.

### 12.4 `gl_MultiTexCoord0` / `vaUV0`

Atlas UV. **Always multiply by `gl_TextureMatrix[0]`** — it is usually identity,
but it is not for the enchantment glint and some modded renderers, and ignoring it
produces visibly wrong UVs.

```glsl
vec2 coord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
```

Core profile:

```glsl
vec2 coord = (textureMatrix * vec4(vaUV0, 0.0, 1.0)).xy;
```

### 12.5 `gl_MultiTexCoord1` / `vaUV2`

Lightmap UV. `x` = **block light**, `y` = **sky light**. The exact raw range is
not documented as a contract; currently it is `0`–`240`, and rescaling by
`/(30.0/32.0) - (1.0/32.0)` maps it to `[0,1]`.

```glsl
vec2 lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
```

Core profile (`vaUV2` is an `ivec2`; use a hard-coded matrix):

```glsl
in ivec2 vaUV2;

const mat4 TEXTURE_MATRIX_2 = mat4(
    vec4(0.00390625, 0.0, 0.0, 0.0),
    vec4(0.0, 0.00390625, 0.0, 0.0),
    vec4(0.0, 0.0, 0.00390625, 0.0),
    vec4(0.03125, 0.03125, 0.03125, 1.0)
);

vec2 lmcoord = (TEXTURE_MATRIX_2 * vec4(vaUV2, 0.0, 1.0)).xy;
```

### 12.6 `vaUV1` / `entityColor`

Core-profile only. `in ivec2 vaUV1;` is the **entity overlay** attribute. In
compatibility profile use the `entityColor` uniform instead. **Not recommended**
in new code.

### 12.7 `at_tangent`

Iris only (needs tangents from a resource pack / labPBR).

```glsl
in vec4 at_tangent;
```

- `xyz` — the tangent, an **approximation**, not normalised
- `w` — **handedness**: a non-zero value in `[-1, 1]` used to flip the bitangent

```glsl
vec3 tangent   = normalize(at_tangent.xyz);
float signW    = at_tangent.w < 0.0 ? -1.0 : 1.0;
vec3 bitangent = normalize(cross(tangent, normal)) * signW;
```

Packs that want this branch-free build `±inf` from `0x7f800000` via
`uintBitsToFloat`, OR in the sign bit, and multiply by the result — clamping `w`
to exactly `±1` with no conditional. Either way, the important part is:
**multiply** the bitangent by the handedness, or every second UV island gets an
inverted normal map.

### 12.8 `at_midBlock` (Iris only)

```glsl
in vec4 at_midBlock;
```

- `xyz` — offset from the current vertex to the **centre of the block**, in
  **1/64 block units**:

```glsl
vec3 centerPosition = position + at_midBlock.xyz / 64.0;
```

- `w` — (`Iris 1.7+`) the block's light emission, `0`–`15`, together with the
  `BLOCK_EMISSION_ATTRIBUTE` feature flag.

Valid in `gbuffers_terrain`, `gbuffers_water` and `shadow` vertex shaders. It is
how you get an exact block centre for voxel work, waving foliage anchored at the
block, or per-block data writes.

### 12.9 `mc_Entity` (Iris/OptiFine)

```glsl
in vec2 mc_Entity;
```

- **`x`** — the block's ID from `block.properties`.
  - `-1.0` when the block is not assigned an ID.
  - Iris 1.8+ stores a **31-bit unsigned int offset by −1**, i.e. the representable
    range is `[-1, 2147483646]`. It is cast to `float`, so precision breaks once
    IDs reach `16777217` and above.
  - OptiFine uses a **signed 16-bit** range instead.
  - With no `block.properties` at all, Iris falls back to pre-1.13 numeric block
    IDs.
- **`y`** — render type: `1.0` for **fluids**, `-1.0` otherwise.

**Terrain only.** For entities, block entities, items and the hand use
`entityId`, `blockEntityId` and `currentRenderedItemId` instead.

### 12.10 `mc_midTexCoord` (Iris/OptiFine)

```glsl
in vec2 mc_midTexCoord;
```

The UV of the **centre of the current quad's texture region**. It is per-quad,
not per-block: a slab's top face points at the *slab's* portion of the atlas, not
at the parent block's texture.

Use it to find the UV distance from the vertex to the quad centre — the standard
technique for waving grass (weight the sway by distance from the block's base) and
for avoiding atlas bleeding.

### 12.11 `mc_chunkFade` (Iris only)

Chunk fading, added in 1.21.11.

```glsl
float mc_chunkFade;   // 0..1, in gbuffers_terrain.vsh
```

- `0`–`1` in `gbuffers_terrain.vsh`.
- In every other gbuffers program it is declared
  `const float mc_chunkFade = -1.0;` (i.e. "not applicable").
- Only exists when the `FADE_VARIABLE` feature flag is enabled.

### 12.12 `ftransform()`

```glsl
vec4 ftransform();
```

Model space → clip space. Deprecated in modern GLSL, but Iris **patches** it, so
it keeps working in every profile. Equivalent to
`gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex`.

---

## 13. Buffers

### 13.1 Default buffers

| Buffer | Format | Resolution |
|---|---|---|
| `colortexN` | RGBA* (RGBA8) | display resolution* |
| `depthtexN` | DEPTH24 / DEPTH32F + STENCIL8† | display resolution |
| `noisetex` | RGB8* | `noiseTextureResolution`* (square) |
| `shadowtexN` | DEPTH*† | `shadowMapResolution`* |
| `shadowColorN` | RGBA* | `shadowMapResolution`* |

\* configurable — see [constants](#14-constants) and
[`shaders.properties`](#175-rendering).
† always carries a **stencil** component too.

Plus three **atlases**, all RGBA8, sized from `atlasSize`:

- `gtexture` — the block/entity texture atlas
- `normals` — `_n` normal maps (labPBR / oldPBR)
- `specular` — `_s` specular maps

More buffers are available through
[custom textures](#138-custom-textures),
[custom images](#139-custom-images-iris-only) and
[SSBOs](#1310-ssbos-iris-only).

### 13.2 `colortex`

```glsl
uniform sampler2D colortexN;                    // read
layout(<format>) uniform image2D colorimgN;     // read/write
```

- Count: **16** by default, **32** since Iris 1.10.5 (`MAX_COLOR_BUFFERS`).
- **Readable** from every program.
- **Writable** from the fragment stage of `begin`, `prepare`, `gbuffers`,
  `deferred` and `composite`. Targets are chosen by `RENDERTARGETS` /
  `DRAWBUFFERS`.
- `colorimgN` images are the **only** way to write from a compute shader.
  OptiFine limits `colorimgN` to the first 6 buffers.
- Resolution defaults to display resolution. Change it with
  `size.buffer.<buffer>` — but **such a buffer can no longer be written by
  gbuffers**, and a single program can only write buffers of identical size.
- Format defaults to RGBA8. Change it with `colortexNFormat`.
- **Clearing:** on a new frame all buffers clear to `0`, **except**
  `colortex0` → vanilla fog colour with alpha `1`, and `colortex1` → `vec4(1.0)`.
  Override with `colortexNClear` / `colortexNClearColor`.
- **Flipping:** `flip.<program>.<buffer> = true` double-buffers that buffer for
  that program.
- **Legacy aliases:** `colortex0`…`colortex7` can also be referred to as
  `gcolor`, `gdepth`, `gnormal`, `composite`, `gaux1`…`gaux4`. If `gdepth`
  appears anywhere and its format is RGBA, **Iris upgrades it to `RGBA32F`**.
- **Warning:** `colortex0`–`colortex3` **cannot be read in gbuffers programs** —
  you get the wrong thing (the atlas). Use `colortex4`+ for inter-pass data.

### 13.3 `depthtex`

Three samplers, all fixed at **window resolution**, single `r` channel, 24- or
32-bit, cleared to `1.0`, and they **never flip**:

| Sampler | Contents |
|---|---|
| `depthtex0` | **all** geometry drawn so far |
| `depthtex1` | everything **except translucents** |
| `depthtex2` | everything except translucents **and the hand** |

- Contents are **garbage** until the matching gbuffers programs have run.
- Written automatically by the rasteriser. Override it with `gl_FragDepth` — but
  you must then set it on **every** code path:

```glsl
gl_FragDepth = gl_FragCoord.z;   // the default, restore it explicitly
```

- Alias: `gdepthtex`.
- Depth is **non-linear**; `1.0` means "far plane / nothing drawn".

### 13.4 `shadowtex`

```glsl
uniform sampler2D shadowtex0;   // all geometry
uniform sampler2D shadowtex1;   // opaque geometry only
```

- Written by `shadow` / `shadow_*`. Depth is automatic; `gl_FragDepth` works as
  above.
- Sized by `shadowMapResolution`; cleared to `1.0`; **never flip**.
- **Legacy aliases:** `waterShadow` → `shadowtex0`. If `waterShadow` appears
  anywhere in the pack, then `shadow` aliases `shadowtex1`.
- **Hardware filtering:** with `shadowHardwareFiltering` enabled, these samplers
  become `sampler2DShadow`, i.e. **compare-mode, hardware-filtered, nearly free**.
  That is great for basic shadows and **breaks PCSS-style algorithms** (you can
  no longer read the raw depth). Iris therefore adds `shadowtex0HW` /
  `shadowtex1HW` as plain depth samplers, but they require the
  `SEPARATE_HARDWARE_SAMPLERS` flag.

```glsl
/*
const bool shadowHardwareFiltering = true;
*/
```

```glsl
uniform sampler2DShadow shadowtex1;   // with hardware filtering on
// sample with a comparison:
float visible = texture(shadowtex1, vec3(shadowScreenPos.xy, shadowScreenPos.z));
```

### 13.5 `shadowcolor`

- `shadowcolor0`, `shadowcolor1`, plus `shadowcolorimgN` image bindings.
- **Writable** from `shadow` and `shadowcomp` fragment shaders.
- Default format RGBA8; **clears to white** `vec4(1.0)` (not black!).
- Override with `shadowcolorNClear` / `shadowcolorNClearColor`.
- Flipping supported.
- The `HIGHER_SHADOWCOLOR` flag unlocks `shadowcolor2`…`shadowcolor7`.
- Alias: `shadowcolor` → `shadowcolor0`.

```glsl
// shadow.fsh — colour + alpha for transparent shadows
layout(location = 0) out vec4 color;
```

### 13.6 `noisetex`

```glsl
uniform sampler2D noisetex;
```

- RGB white noise, always square, default **256 × 256** (`noiseTextureResolution`),
  RGB8.
- Cleared to random noise every frame.
- **Not writable**, never flips.
- Replace it with your own texture: `texture.noise = textures/rgba_noise.png`.
- Use it for per-pixel rotation, dithering, blue-noise dithering, rain patterns,
  film grain, or as a 2D random table: `texelFetch(noisetex, ivec2(gl_FragCoord.xy) % 64, 0).r`.

### 13.7 Atlases

```glsl
uniform sampler2D gtexture;   // block/entity atlas
uniform sampler2D normals;    // _n maps
uniform sampler2D specular;   // _s maps
```

- `gtexture` — sample with `(gl_TextureMatrix[0] * gl_MultiTexCoord0).xy`.
- `normals` — if a texture has no `_n` variant, this contains
  `(127, 127, 255, 255)`, i.e. a **flat** normal. This is deliberate: a default
  `0,0,0` would be an invalid direction.
- `specular` — if a texture has no `_s` variant, this is **all zeros**
  (no specular).
- **Atlases are NOT bound outside gbuffers programs.** In `composite`, `gtexture`
  is undefined. If you need a texture in a fullscreen pass, use a
  [custom texture](#138-custom-textures).
- Two traps: (a) any `sampler2D` name Iris does not recognise silently binds the
  atlas, so a typo gives you garbage rather than an error; (b) the name `texture`
  itself is a **reserved keyword** in GLSL 120+, so never call a sampler that.

### 13.8 Custom textures

Bind any texture into any stage:

```properties
texture.<stage>.<bufferName> = <path>
```

Stages: `setup`, `begin`, `shadowcomp`, `prepare`, `gbuffers` (and `shadow`),
`deferred`, `composite`, and `final` (**Iris only**; OptiFine cannot bind in
`final`).

Four kinds of path:

**1. An image in your pack** (`.png` only in Iris; OptiFine also accepts `.jpg`):

```properties
texture.composite.colortex4 = textures/perlin.png
```

**2. A resource-pack or vanilla texture:**

```properties
texture.composite.colortex4 = minecraft:textures/block/dirt.png
```

**3. An atlas or a dynamic texture:**

```properties
texture.composite.colortex4 = minecraft:textures/atlas/blocks.png
texture.composite.colortex4 = minecraft:dynamic/lightmap_1
```

**4. A raw binary texture** — with full control over type and format:

```
texture.<stage>.<buffer> = <path> <type> <internalFormat> <dimensions> <pixelFormat> <pixelType>
```

`<type>` ∈ `TEXTURE_1D`, `TEXTURE_2D`, `TEXTURE_3D`, `TEXTURE_RECTANGLE`.
Raw textures are the only way to get **3D textures** and non-RGBA8 formats.

PBR variants can be bound alongside by using the `_n` / `_s` naming suffix.

**`.mcmeta` for filtering and wrapping.** Next to an image or raw texture, create
`<name>.png.mcmeta`:

```json
{
  "texture": {
    "blur": true,
    "clamp": false
  }
}
```

- Images default to **nearest filtering + wrap**.
- Raw textures default to **bilinear + clamp**.
- Not available for resource-pack or atlas paths.

**`customTexture` — new samplers (Iris only).** `texture.*` **overwrites** an
existing buffer binding. To add a brand-new sampler:

```properties
customTexture.myNoise = textures/blue_noise.png
```

```glsl
uniform sampler2D myNoise;
```

### 13.9 Custom images (Iris only)

Requires the `CUSTOM_IMAGES` feature flag and **OpenGL 4.2+**. Up to **16**
images (8 before Iris 1.6.4).

```properties
image.<imageName> = <samplerName> <format> <internalFormat> <pixelType> <shouldClearOnNewFrame> <isRelative> <relativeX|absoluteX> <relativeY|absoluteY> <absoluteZ>
```

Examples:

```properties
# 2D image, half the screen size, cleared each frame
image.cimage1 = cSampler1 rgba rgba32f float false true 0.5 0.5

# 3D image, absolute 512^3, cleared each frame
image.cimage1 = cSampler1 rgba rgba8 float true false 512 512 512
```

Use it as a storage image:

```glsl
layout(rgba8) uniform image2D cimage1;

void main() {
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    vec4 value = imageLoad(cimage1, texel);
    imageStore(cimage1, texel, value + 1.0);
}
```

…or sample it with filtering through the sampler you declared:

```glsl
uniform sampler2D cSampler1;
vec4 smooth = texture(cSampler1, texcoord);
```

Images are the **only** way for a compute shader to write buffers.

### 13.10 SSBOs (Iris only)

Requires the `SSBO` flag and **OpenGL 4.3+**. 128 MB is guaranteed; running out
of VRAM is an error.

**Fixed size:**

```properties
bufferObject.<index> = <byteSize>
```

`<index>` is `0`–`8`.

**Screen-sized** (Iris 1.6.6+):

```properties
bufferObject.<index> = <byteSize> <isRelative> <scaleX> <scaleY>
```

Total bytes = `int(viewWidth * scaleX) * int(viewHeight * scaleY) * byteSize`.

**Declaration in GLSL:**

```glsl
layout(std430, binding = 0) buffer myBuffer {
    vec4  someData;
    float someExtraData;
};
```

Add an optional trailing `bufferAccess;` instance name if you have multiple
buffers or need to avoid redefinition errors:

```glsl
layout(std430, binding = 0) buffer myBuffer {
    vec4 someData;
} bufferAccess;
```

**Initialise from a file** (Iris 1.8+, fixed-size only):

```properties
bufferObject.0 = 1048576 data/initial.bin
```

A file larger than the buffer is an error; a smaller one leaves the remainder as
garbage.

SSBOs are how you do stable per-block data (voxel grids), atomics-based
accumulation, and `indirect` compute dispatch counts.

### 13.11 Image formats

The formats accepted by `bufferFormat` / `colortexNFormat` / custom textures:
bit depth, pixel format and pixel type. The ✔/✖ column (omitted here as
everything listed is valid unless marked) says whether a format is valid for
`image` / `sampler` bindings. **\* = Iris 1.8+ only.**

**Unsigned normalised**

| Format | Bits | Pixel format | Pixel type |
|---|---|---|---|
| `RGBA16` | 16 | RGBA | `unsigned short` |
| `RGBA8` | 8 | RGBA | `unsigned byte` |
| `RGB10_A2` | 10/2 | RGBA | `unsigned int_10_10_10_2` |
| `RGBA4`* | 4 | RGBA | `unsigned short_4_4_4_4` |
| `RGB5_A1` | 5/1 | RGBA | `unsigned short_5_5_5_1` |
| `RGB16` | 16 | RGB | `unsigned short` |
| `RGB8` | 8 | RGB | `unsigned byte` |
| `RGB565`* | 5/6/5 | RGB | `unsigned short_5_6_5` |
| `RG16` | 16 | RG | `unsigned short` |
| `RG8` | 8 | RG | `unsigned byte` |
| `R16` | 16 | RED | `unsigned short` |
| `R8` | 8 | RED | `unsigned byte` |
| `RGBA2`* | 2 | RGBA | `unsigned short_2_2_2_2` |
| `R3_G3_B2` | 3/3/2 | RGB | `unsigned byte_3_3_2` |

**Signed normalised**

`RGBA16_SNORM`, `RGBA8_SNORM`, `RGB16_SNORM`, `RGB8_SNORM`, `RG16_SNORM`,
`RG8_SNORM`, `R16_SNORM`, `R8_SNORM`.

**Float**

| Format | Bits | Pixel format | Pixel type |
|---|---|---|---|
| `RGBA32F` | 32 | RGBA | `float` |
| `RGBA16F` | 16 | RGBA | `half float` |
| `RGB32F` | 32 | RGB | `float` |
| `RGB16F` | 16 | RGB | `half float` |
| `R11F_G11F_B10F` | 11/11/10 | RGB | `unsigned int_10f_11f_11f_rev` |
| `RGB9_E5` | 9 (±shared 5-bit exponent) | RGB | `unsigned int_5_9_9_9_rev` |
| `RG32F` | 32 | RG | `float` |
| `RG16F` | 16 | RG | `half float` |
| `R32F` | 32 | RED | `float` |
| `R16F` | 16 | RED | `half float` |

`RGB9_E5` and `R11F_G11F_B10F` are both "three floats in 32 bits" and beat
`RGB16F` for HDR data you are going to sample; `RGB9_E5` has a shared exponent
(large dynamic range, relatively less precision) while `R11F_G11F_B10F` gives
more bits to red and green (better for colour).

**Unsigned integral**

`RGBA32UI`, `RGBA16UI`, `RGBA8UI`, `RGB32UI`, `RGB16UI`, `RGB8UI`, `RG32UI`,
`RG16UI`, `RG8UI`, `R32UI`, `R16UI`, `R8UI`.

**Signed integral**

`RGBA32I`, `RGBA16I`, `RGBA8I`, `RGB32I`, `RGB16I`, `RGB8I`, `RG32I`, `RG16I`,
`RG8I`, `R32I`, `R16I`, `R8I`.

Extra pixel types available for **raw textures**: `UNSIGNED_BYTE_3_3_2`,
`UNSIGNED_SHORT_5_6_5`, `UNSIGNED_SHORT_4_4_4_4`, `UNSIGNED_SHORT_5_5_5_1`,
`UNSIGNED_INT_8_8_8_8`, `UNSIGNED_INT_10_10_10_2`.

---

## 14. Constants

Constants are `const` declarations that configure the pack. Iris reads them out
of your source; the value never reaches the GPU (hence the block-comment form).

**Most need only appear in one file** — typically a `.fsh`, since fragment
shaders are what get scanned — but a declaration on its own line is safest.

```glsl
const int shadowMapResolution = 2048;
```

or, for formats that would otherwise be a syntax error:

```glsl
/*
const int colortex0Format = RGBA16;
*/
```

The `/* … */` form must be a **multi-line comment on its own line**.

### 14.1 `RENDERTARGETS`

```glsl
/* RENDERTARGETS: X,Y,Z */
```

Comma-separated destination buffer indices for this fragment shader, e.g.
`0,3,7,13`. In a `.fsh`. **Must be a multi-line comment on its own line.**
Defaults to the first 8 buffers if absent.

Three ways to write the outputs:

```glsl
// 1. legacy
gl_FragData[0] = value;

// 2. modern, explicit
out vec4 outColor0;
out vec4 outColor1;

// 3. modern, with explicit locations (recommended)
layout(location = 0) out vec4 albedo;
layout(location = 1) out vec4 dataOut;
```

Writing nothing to a requested target writes **garbage** into it.

### 14.2 `DRAWBUFFERS` (legacy)

```glsl
/* DRAWBUFFERS:XYZ */
```

The old OptiFine form. Indices are **single characters `0`–`9` only**, so
`colortex10`–`colortex15` are unreachable. **Prefer `RENDERTARGETS`.**

### 14.3 `bufferClear`

```glsl
const bool <bufferName>Clear = <true|false>;
```

Keeps a buffer's contents across frames instead of clearing it. Note the naming:
`colortex0Clear`, `shadowcolor0Clear`, `gdepthClear` (legacy alias).

### 14.4 `bufferClearColor`

```glsl
const vec4 <bufferName>ClearColor = vec4(r, g, b, a);
```

**All four components are required.**

Defaults: `vec4(0)` for every buffer except `colortex0` and `colortex1`
(see [`colortex`](#132-colortex)) and the `shadowcolor*` buffers, which default
to `vec4(1.0)` (white).

- A buffer with fewer components takes the leftmost components.
- Integer buffers **reinterpret the float bits**.
- 16-bit and 8-bit buffers clamp.

### 14.5 `bufferFormat`

```glsl
const int <bufferName>Format = <format>;
```

For `colortex*` and `shadowcolor*`. Must be in a block comment **or** have the
format name defined, and on its own line.

### 14.6 `colortexMipmaps`

```glsl
const bool <bufferName>MipmapEnabled = true;
```

Generates a mip chain for that `colortex` buffer **before the program it appears
in**. Valid in `begin`, `prepare`, `deferred`, `composite` `.fsh` files.

### 14.7 `shadowMipmaps`

Generated after `shadow`, before `shadowcomp`:

| Constant | Effect |
|---|---|
| `generateShadowMipmap` | mipmaps for the shadow maps |
| `shadowtexMipmap` | both |
| `shadowtex0Mipmap` | `shadowtex0` only |
| `shadowtex1Mipmap` | `shadowtex1` only |

Shadow-colour equivalents: `generateShadowColorMipmap`, `shadowcolor0Mipmap` /
`shadowColor0Mipmap`, `shadowcolor1Mipmap` / `shadowColor1Mipmap`.

> **Bug:** the shadow-*colour* mipmaps are currently **never generated**. Do not
> rely on them.

### 14.8 `ambientOcclusionLevel`

```glsl
const float ambientOcclusionLevel = 1.0;
```

`[0..1]`. `0.0` disables vanilla ambient occlusion entirely (useful when you
compute your own AO).

### 14.9 `centerDepthHalflife`

```glsl
const float centerDepthHalflife = 1.0;
```

Half-life in **ticks** for the temporal smoothing of `centerDepthSmooth`.

### 14.10 `eyeBrightnessHalflife`

```glsl
const float eyeBrightnessHalflife = 10.0;
```

Half-life in **ticks** for `eyeBrightnessSmooth`.

### 14.11 `wetnessHalflife` / `drynessHalflife`

```glsl
const float wetnessHalflife = 600.0;
const float drynessHalflife = 200.0;
```

Half-lives in ticks for the `wetness` uniform: how fast the world gets wet when
it rains (`wetnessHalflife`, default 600) and how fast it dries
(`drynessHalflife`, default 200). Larger = slower.

### 14.12 `entityShadowDistanceMul` (Iris only)

```glsl
const float entityShadowDistanceMul = 1.0;
```

A multiplier on the terrain shadow distance, applied to **entities**. Lets
entities cast shadows further than the terrain cull distance.

### 14.13 `noiseTextureResolution`

```glsl
const int noiseTextureResolution = 256;
```

Square resolution of `noisetex`. 256 is the default; higher costs VRAM but gives
finer dithering.

### 14.14 `shadowDistance`

```glsl
const float shadowDistance = 160.0;
```

In blocks. **Scales the shadow projection.** It does not cull geometry on its
own — see the next one.

### 14.15 `shadowDistanceRenderMul`

```glsl
const float shadowDistanceRenderMul = -1.0;
```

- `-1.0` (default) — **no culling**.
- `1.0` — cull at `1 × shadowDistance`.
- `0.5` — cull at half.
- `2.0` — cull at double.

It culls; it does **not** scale geometry.

### 14.16 `shadowFarPlane` (Iris only)

```glsl
const float shadowFarPlane = 256.0;
```

Explicit far plane for the shadow projection.

### 14.17 `shadowNearPlane` (Iris only)

```glsl
const float shadowNearPlane = 0.05;
```

Near plane for the shadow projection. Valid in `composite`, `deferred`, `final`,
`prepare`.

### 14.18 `shadowHardwareFiltering`

```glsl
const bool shadowHardwareFiltering = true;
```

Enables depth-compare (`sampler2DShadow`) sampling of `shadowtex0/1`. Nearly
free, but blocks PCSS-style algorithms; see
[`shadowtex`](#134-shadowtex).

### 14.19 `shadowIntervalSize`

```glsl
const float shadowIntervalSize = 2.0;
```

Snaps shadow geometry to a `<n>`-block grid to kill walking shimmer.
`0.0` disables snapping.

### 14.20 `shadowMapFov`

```glsl
const float shadowMapFov = 90.0;
```

Switches the shadow pass from **orthographic** to a **perspective-like**
projection with this field of view. Higher resolution near the camera, worse
coverage far away.

### 14.21 `shadowMapResolution`

```glsl
const int shadowMapResolution = 1024;
```

Square, in pixels. Default `1024`.

### 14.22 `sunPathRotation`

```glsl
const float sunPathRotation = 0.0;
```

In degrees. `0` = the sun passes directly overhead; other values rotate the
sun's arc (and therefore the shadow direction) around the world's X axis.

### 14.23 `voxelDistance` (Iris only)

```glsl
const float voxelDistance = 160.0;
```

The un-culled radius when `shadow.culling = reversed`. `shadowDistance` cannot
be lower than it. Valid in `composite`, `deferred`, `final`, `prepare`. Pair with
the `REVERSED_CULLING` flag.

### 14.24 `workGroups`

```glsl
const ivec3 workGroups = ivec3(x, y, z);
```

In a `.csh`. The number of work groups to dispatch.

### 14.25 `workGroupsRender`

```glsl
const vec2 workGroupsRender = vec2(x, y);
```

Effective default is `(1.0, 1.0)`. The dispatch count then follows the formula in
[Compute shaders](#114-compute-shaders).

---

## 15. Macros

Macros are **compile-time** definitions describing the environment your pack is
running in.

```glsl
#ifdef IS_IRIS
    // Iris-specific path
#else
    // OptiFine path
#endif
```

### 15.1 `IS_IRIS`

Defined when Iris loads the pack. The single most useful guard in the whole
pipeline.

### 15.2 `IRIS_VERSION`

Version, encoded as `<major><minor:2><patch:2>`:

- `1.8.2` → `10802`
- `1.8.10` → `10810`

Not defined before Iris 1.8. Usage:

```glsl
#if IRIS_VERSION >= 10800
    // needs 1.8+
#endif
```

### 15.3 `MC_VERSION`

Same encoding:

- `1.6.8` → `10608`
- `1.7.10` → `10710`
- `1.21.0` → `12100`

```glsl
#if MC_VERSION >= 11700
    // 1.17+ (OpenGL 3.2 core-ish world)
#endif
```

### 15.4 `MC_GL_VERSION`

The OpenGL version the game is running with: `210`, `330`, `460`, and so on. Can
be **lower than** `MC_GLSL_VERSION`.

### 15.5 `MC_GLSL_VERSION`

The GLSL version available: `120`, `330`, `460`, … Use it to gate
version-specific syntax.

### 15.6 `MC_OS_*`

Exactly one is defined:

`MC_OS_WINDOWS`, `MC_OS_MAC`, `MC_OS_LINUX`, `MC_OS_OTHER`.

### 15.7 `MC_GL_RENDERER_*`

Exactly one, based on the GPU vendor string:

`MC_GL_RENDERER_RADEON`, `MC_GL_RENDERER_GEFORCE`, `MC_GL_RENDERER_QUADRO`,
`MC_GL_RENDERER_INTEL`, `MC_GL_RENDERER_GALLIUM`, `MC_GL_RENDERER_MESA`,
`MC_GL_RENDERER_APPLE` (Iris 1.8+), `MC_GL_RENDERER_OTHER`.

### 15.8 `MC_GL_VENDOR_*`

Exactly one, based on the driver vendor:

`MC_GL_VENDOR_AMD`, `MC_GL_VENDOR_ATI`, `MC_GL_VENDOR_INTEL`, `MC_GL_VENDOR_MESA`,
`MC_GL_VENDOR_NVIDIA`, `MC_GL_VENDOR_XORG`, `MC_GL_VENDOR_OTHER`.

### 15.9 `MC_<extension>`

Every supported OpenGL extension defines a macro with its name upper-cased and
prefixed, e.g.:

```glsl
#ifdef MC_GL_ARB_shader_texture_lod
    // explicit LOD control is available
#endif
```

This is the correct way to decide whether you may use `textureLod`,
`imageStore`, `atomicAdd` on SSBOs, and so on.

### 15.10 `MC_HAND_DEPTH`

The clip-space depth multiplier applied to **hand** geometry. Hand geometry is
drawn with a compressed depth range so it never intersects the world; when
un-projecting hand pixels you must undo it in NDC:

```glsl
ndcDepth = (screenDepth * 2.0 - 1.0) / MC_HAND_DEPTH;
```

This is also why `gl_ProjectionMatrix` differs from `gbufferProjection` in
`gbuffers_hand` and `gbuffers_hand_water`.

### 15.11 `MC_MIPMAP_LEVEL` (Iris 1.8.1+)

The current maximum mip level.

### 15.12 `MC_TEXTURE_FORMAT_LAB_PBR`

Defined from the resource pack's declared PBR format:

```properties
# texture.properties
format=lab-pbr
```

→ defines `MC_TEXTURE_FORMAT_LAB_PBR`. With `format=lab-pbr/1.3`,
`MC_TEXTURE_FORMAT_LAB_PBR_1_3` is also defined (only 1.3 is supported).

### 15.13 `IRIS_TAG_SUPPORT`

Defined as `2` from Iris 1.8 onward. In that version, **individual block entries
take priority over tag entries**. Usable inside `block.properties`:

```properties
#ifdef IRIS_TAG_SUPPORT
block.5 = %minecraft:leaves
#endif
```

```glsl
#if IRIS_TAG_SUPPORT >= 2
    // tag priority behaves the 1.8 way
#endif
```

### 15.14 `IRIS_HAS_CONNECTED_TEXTURES`

Defined when a connected-textures mod (e.g. **Continuity**) is loaded. Lets you
skip UV-based tricks that assume vanilla atlas layout.

### 15.15 `IRIS_HAS_TRANSLUCENCY_SORTING`

Defined when Sodium ≥ 0.6 is present (i.e. translucency sorting is available).
Guard effects that require correctly sorted translucent geometry.

### 15.16 `MAX_COLOR_BUFFERS` (Iris 1.10.5+)

The number of `colortex` buffers (`16`, or `32` on the newer versions).

### 15.17 `MC_RENDER_STAGE_*`

The values `renderStage` can hold. Split `shadow` into per-geometry branches by
comparing against these:

```
MC_RENDER_STAGE_NONE
MC_RENDER_STAGE_SKY
MC_RENDER_STAGE_SUNSET
MC_RENDER_STAGE_CUSTOM_SKY
MC_RENDER_STAGE_SUN
MC_RENDER_STAGE_MOON
MC_RENDER_STAGE_STARS
MC_RENDER_STAGE_VOID
MC_RENDER_STAGE_TERRAIN_SOLID
MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED *
MC_RENDER_STAGE_TERRAIN_CUTOUT *
MC_RENDER_STAGE_ENTITIES
MC_RENDER_STAGE_BLOCK_ENTITIES
MC_RENDER_STAGE_DESTROY *
MC_RENDER_STAGE_OUTLINE
MC_RENDER_STAGE_DEBUG *
MC_RENDER_STAGE_HAND_SOLID
MC_RENDER_STAGE_TERRAIN_TRANSLUCENT
MC_RENDER_STAGE_TRIPWIRE *
MC_RENDER_STAGE_PARTICLES
MC_RENDER_STAGE_CLOUDS
MC_RENDER_STAGE_RAIN_SNOW
MC_RENDER_STAGE_WORLD_BORDER
MC_RENDER_STAGE_HAND_TRANSLUCENT
```

\* currently unused by Iris.


---

## 16. Uniforms

Uniforms are values the game provides to your program at draw time. Badge
meanings:

- **IE** — Iris Exclusive: not available in OptiFine at all.
- **OF-CU** — in OptiFine this value is only available to **custom uniforms**; in
  Iris it is also a normal uniform.

### 16.1 Camera and player model

| Declaration | Meaning |
|---|---|
| `uniform vec3 cameraPosition;` | camera position in world space. Modern Iris **resets** it every `30000` blocks walked, or on a teleport of more than `1000` blocks. OptiFine resets every `1000024` blocks. |
| `uniform float eyeAltitude;` | player altitude in blocks; equal to `cameraPosition.y`; matches F3. |
| `uniform vec3 cameraPositionFract;` **IE** | fractional part (`0`–`1`) of the camera position. Rebuild exact positions with `cameraPositionInt` to avoid precision error. |
| `uniform ivec3 cameraPositionInt;` **IE** | truncated integer part. **Not** shifted, unlike `cameraPosition`. |
| `uniform vec3 previousCameraPosition;` | `cameraPosition` of the previous frame. |
| `uniform vec3 previousCameraPositionFract;` **IE** | previous-frame `cameraPositionFract`. |
| `uniform ivec3 previousCameraPositionInt;` **IE** | previous-frame `cameraPositionInt`. |
| `uniform vec3 eyePosition;` **IE** | world position of the player's **head model**. Equals `cameraPosition` in first person; differs in third person. |
| `uniform vec3 relativeEyePosition;` **IE** | offset from the head model to the camera: `cameraPosition - eyePosition`. |
| `uniform vec3 playerBodyVector;` **IE** | intended to be the world-aligned body facing — **currently broken, reads the same as `playerLookVector`**. |
| `uniform vec3 playerLookVector;` **IE** | world-aligned head direction, unaffected by swim animation: camera direction in first person and rear third person, reversed in front third person. |
| `uniform vec3 vehicleLookVector;` **IE** (1.10.4+) | world-aligned facing of the ridden vehicle's model head. |
| `uniform vec3 relativeVehiclePosition;` **IE** (1.10.4+) | offset from the vehicle position to the camera. |
| `uniform vec3 upPosition;` | world up vector **in view space**, length `100.0`. Also `gbufferModelView[1].xyz`. |
| `uniform ivec2 eyeBrightness;` | the lightmap at the player: `x` = block light, `y` = sky light, `[0-240]`. |
| `uniform ivec2 eyeBrightnessSmooth;` | `eyeBrightness` smoothed over time; speed = `eyeBrightnessHalflife`. |
| `uniform float centerDepthSmooth;` | `depthtex0` at the screen centre, smoothed; speed = `centerDepthHalflife`. |
| `uniform bool firstPersonCamera;` | `true` in first person, `false` in any third-person view. |

### 16.2 Player status

| Declaration | Meaning |
|---|---|
| `uniform int isEyeInWater;` | `0` none/other, `1` water, `2` lava, `3` powder snow. |
| `uniform bool isSpectator;` **IE** | in spectator mode. |
| `uniform bool isRightHanded;` **IE** | `true` when the right hand is the main hand (the default); `false` when the player set left-handed. |
| `uniform float blindness;` | `0` none → `1` full; fractional only during transitions. |
| `uniform float darknessFactor;` | `0.0` no effect, `1.0` active, interpolated during transitions. |
| `uniform float darknessLightFactor;` | strength of the pulsating dimming: `0.0` minimum, `1.0` maximum. |
| `uniform float nightVision;` | `0` none → `1` full; fractional during transitions. |
| `uniform float playerMood;` | `0.0`–`1.0`, increments in caves/low light; **resets to `0.0` on reaching `1.0`**. |
| `uniform float constantMood;` **IE** | like `playerMood` but **does not reset** at `1.0`. |
| `uniform float currentPlayerAir;` **IE** | relative air `0`–`1`; **`-1` in creative/spectator**. Multiply by `maxPlayerAir` for absolute. |
| `uniform float maxPlayerAir;` **IE** | internal max air, **not** a bubble count: **`300`** in default survival; `-1` in creative/spectator. |
| `uniform float currentPlayerArmor;` **IE** | relative armour `0`–`1`; `-1` in creative/spectator. |
| `uniform float maxPlayerArmor;` **IE** | internal max armour, not icon count: **`50`** by default; same value in no-hunger modes. |
| `uniform float currentPlayerHealth;` **IE** | relative health `0`–`1`; `-1` in creative/spectator. |
| `uniform float maxPlayerHealth;` **IE** | **twice** the max hearts: `20` default, up to `1024` with mods/Health Boost; `-1` in creative/spectator; unaffected by Absorption. |
| `uniform float currentPlayerHunger;` **IE** | relative hunger `0`–`1`; `-1` in creative/spectator. |
| `uniform float maxPlayerHunger;` **IE** | twice the hunger icons: default `20`; same value in no-hunger modes. |
| `uniform bool vehicleInWater;` **IE** (1.10.4+) | the vehicle is touching water. |
| `uniform bool isRiding;` **IE** (1.10.4+) | the player is riding an entity. |
| `uniform bool inSwimmingAnimation;` **IE** (1.10.4+) | the swimming animation state is active. |
| `uniform bool feetInWater;` **IE** (1.10.4+) | the player is touching water. |
| `uniform bool isElytraFlying;` **IE** (1.10.6+) | flying with an elytra. |
| `uniform bool is_burning;` **OF-CU** | on fire. |
| `uniform bool is_hurt;` **OF-CU** | being hurt, and for a brief moment after. |
| `uniform bool is_invisible;` **OF-CU** | spectator mode or an invisibility potion. |
| `uniform bool is_on_ground;` **OF-CU** | touching the ground and not flying (false when flying, falling, or swimming off the bottom). |
| `uniform bool is_sneaking;` **OF-CU** | sneaking. |
| `uniform bool is_sprinting;` **OF-CU** | sprinting. |
| `uniform bool hideGUI;` | `false` while the GUI is visible, `true` when hidden (F1). |

### 16.3 Screen and system

| Declaration | Meaning |
|---|---|
| `uniform float viewHeight;` | screen height in pixels/fragments. |
| `uniform float viewWidth;` | screen width in pixels/fragments. |
| `uniform float aspectRatio;` | `viewWidth / viewHeight`. |
| `uniform float screenBrightness;` | user brightness setting, `0` lowest → `1` highest. |
| `uniform int frameCounter;` | frames since program start; **resets to `0` after `720719`**. |
| `uniform float frameTime;` | previous frame's duration in **seconds**. |
| `uniform float frameTimeCounter;` | running game time in seconds; **resets after `3600` s**; does not pause. |
| `uniform int currentColorSpace;` **IE** | `0` sRGB, `1` DCI_P3, `2` Display P3, `3` REC2020, `4` Adobe RGB. |
| `uniform ivec3 currentDate;` **IE** | `ivec3(year, month, day)` from the OS. |
| `uniform ivec3 currentTime;` **IE** | `ivec3(hour, minute, second)`, 24-hour (3 pm = `15`). |
| `uniform ivec2 currentYearTime;` **IE** | `ivec2(seconds_elapsed_in_year, seconds_remaining_in_year)`. |

Note `frameTimeCounter` resets hourly: **always** wrap time-based animation with a
period, e.g. `fract(frameTimeCounter)` or `sin(frameTimeCounter * 2.0 * pi)`, so
the reset is invisible.

### 16.4 IDs

| Declaration | Meaning |
|---|---|
| `uniform int entityId;` | `entity.properties` ID of the current entity. `0` if there is no `entity.properties`; **`65535`** if the file exists but the entity is not in it. |
| `uniform int blockEntityId;` | `block.properties` ID of the current block entity. `0` if no file, `65535` if unlisted. |
| `uniform int vehicleId;` **IE** (1.10.4+) | `entity.properties` ID of the ridden vehicle; same `0` / `65535` rules. |
| `uniform int currentRenderedItemId;` **IE** | ID of the item or armour being rendered right now (`item.properties` for items/armour, `block.properties` for block items). Like `heldItemId` but per-draw. New detectable ID: `trim_<material>` for armour trims. |
| `uniform int currentSelectedBlockId;` **IE** | `block.properties` ID of the block being outlined. `0` when nothing is selected, when it is not in `block.properties`, or when there is no file. |
| `uniform vec3 currentSelectedBlockPos;` **IE** | player-space centre of the selected block; **all components `-256.0`** when nothing is selected. |
| `uniform int heldItemId;` | `item.properties` ID of the main-hand item. `0` if no file; **`-1`** if the file exists and the item is not in it (including holding nothing). |
| `uniform int heldItemId2;` | the same for the off hand. |
| `uniform int heldBlockLightValue;` | light emission of the main-hand item, `0`–`15` vanilla (modded may exceed). With `oldHandLight` at its default (`true`) this is the **maximum of both hands**. |
| `uniform int heldBlockLightValue2;` | light emission of the off-hand item. |

### 16.5 World and weather

| Declaration | Meaning |
|---|---|
| `uniform vec3 sunPosition;` | sun position **in view space**, length always `100.0`. `vec3 sunDir = 0.01 * sunPosition;` |
| `uniform vec3 moonPosition;` | the same for the moon. |
| `uniform vec3 shadowLightPosition;` | the highest celestial body in view space — in the Overworld the sun by day, the moon by night. Matches the shadow pass direction. Length `100.0`. |
| `uniform float sunAngle;` | `0`–`1` over the cycle: **`0` sunrise, `0.25` noon, `0.5` sunset, `0.75` midnight**. |
| `uniform float shadowAngle;` | like `sunAngle` for the highest body. Day = `sunAngle`. At night: `0.0` sunset, `0.25` midnight, approaching `0.5` at sunrise. **Range `0.0`–`0.5`.** |
| `uniform int moonPhase;` | `0` full, `1` waning gibbous, `2` three quarters, `3` waning crescent, `4` new, `5` waxing crescent, `6` first quarter, `7` waxing gibbous. |
| `uniform float rainStrength;` | `0` dry → `1` storm; interpolated during transitions. |
| `uniform float wetness;` | like `rainStrength` but on the much slower `wetnessHalflife` / `drynessHalflife` clock. |
| `uniform float thunderStrength;` **IE** | like `rainStrength`, non-zero only during thunder. |
| `uniform vec4 lightningBoltPosition;` **IE** | player-space position of a lightning bolt being rendered; `vec4(0.0)` if none. If at least one exists, `w = 1`; random one chosen if several. |
| `uniform int worldTime;` | time within the day, **`0`–`23999`**, matches `time query daytime`, resets daily. Actual sunrise ≈ **`23215`**, sunset ≈ **`12785`** (day and night have slightly different lengths). |
| `uniform int worldDay;` | in-game days since world start; matches `time query day`; reset by any `time set`. |
| `uniform vec3 endFlashPosition;` **IE** | End-flash position in view space, length `100.0`; identical to `shadowLightPosition` when `endFlashShadows` is on. |
| `uniform float endFlashIntensity;` **IE** | flash intensity, max `1.0`; the sound cue happens at `0.1`; `0.0` when there is no flash. |
| `uniform float previousEndFlashIntensity;` **IE** | previous frame's flash intensity. |

### 16.6 Biome and dimension

| Declaration | Meaning |
|---|---|
| `uniform int biome;` **OF-CU** | biome at the player, compared against `BIOME_*` constants (`BIOME_PLAINS`, `BIOME_FOREST`, `BIOME_RIVER`, `BIOME_DESERT`, `BIOME_SWAMP`, `BIOME_MEADOW`, `BIOME_MANGROVE_SWAMP`, …). |
| `uniform int biome_category;` **OF-CU** | compared against `CAT_*`, below. |
| `uniform int biome_precipitation;` **OF-CU** | `0` none, `1` rain, `2` snow; define names `PPT_NONE`, `PPT_RAIN`, `PPT_SNOW`. |
| `uniform float rainfall;` **OF-CU** | `0`–`1`, a **biome property** independent of current weather. |
| `uniform float temperature;` **OF-CU** | vanilla range `-0.7`–`2.0`; mods may exceed. |
| `uniform float ambientLight;` **IE** | the dimension's ambient light — how much sky lighting affects light values. |
| `uniform int bedrockLevel;` **IE** | y of the bedrock floor (`min_y`). |
| `uniform float cloudHeight;` **IE** | cloud height in blocks from user settings; **`NaN` in dimensions without clouds**. |
| `uniform bool hasCeiling;` **IE** | the dimension has a ceiling (Nether). |
| `uniform bool hasSkylight;` **IE** | the dimension has sky and sky lighting. |
| `uniform int heightLimit;` **IE** | difference between the lowest and highest placeable block (`height`). |
| `uniform int logicalHeightLimit;` **IE** | `logical_height` — the chorus-growth / nether-portal limit. |

`CAT_*` values:

```
CAT_NONE  CAT_TAIGA  CAT_EXTREME_HILLS  CAT_JUNGLE  CAT_MESA  CAT_PLAINS
CAT_SAVANNA  CAT_ICY  CAT_THE_END  CAT_BEACH  CAT_FOREST  CAT_OCEAN
CAT_DESERT  CAT_RIVER  CAT_SWAMP  CAT_MUSHROOM  CAT_NETHER
```

`biome_category` is almost always the better choice than `biome`: it groups biomes
that should behave alike, and it does not need updating when Mojang adds a biome.

### 16.7 Rendering

| Declaration | Meaning |
|---|---|
| `uniform float near;` | near clip plane: `0.05` unless a mod changes it. |
| `uniform float far;` | **render distance in blocks** — *not* the far clip plane, which is roughly `far * 4.0`. |
| `uniform float alphaTestRef;` | recommended discard threshold, commonly `0.1`; affected by the `alphaTest` directive. |
| `uniform vec3 chunkOffset;` | model-space offset of the chunk being rendered: `vec3 modelPos = vaPosition + chunkOffset;`. All zeros outside terrain and on the compatibility profile. **Core profile + 1.17+ only**; vanilla renamed it `modelOffset` in 1.21.2 but Iris kept `chunkOffset`. |
| `uniform vec4 entityColor;` | `rgb` tint, `a` blend factor: `color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);`. **May be patched to a non-uniform value** despite the qualifier. |
| `uniform ivec4 blendFunc;` | `x` source RGB, `y` dest RGB, `z` source alpha, `w` dest alpha. Values below. |
| `uniform ivec2 atlasSize;` | texture atlas size; `0` when the atlas is not bound. |
| `uniform int renderStage;` | current geometry's render stage; compare with `MC_RENDER_STAGE_*`. |
| `uniform vec3 fogColor;` | vanilla horizon fog/sky colour; depends on biome, time of day **and view direction**. |
| `uniform vec3 skyColor;` | vanilla upper-sky colour; biome and time of day, **not** view direction. |
| `uniform float fogDensity;` | relative vanilla fog density, `0.0`–`1.0`. |
| `uniform float fogStart;` | vanilla fog start distance in blocks. |
| `uniform float fogEnd;` | vanilla fog end distance in blocks. |
| `uniform int fogMode;` | `GL_EXP` `2048`, `GL_EXP2` `2049`, `GL_LINEAR` `9729`. |
| `uniform int fogShape;` | `0` sphere, `1` cylinder. |
| `uniform int textureFilteringMode;` **IE** | `0` nearest, `1` RGSS (rotated-grid supersampling), `2` anisotropic. **Only defined when the `TEXTURE_FILTERING` feature flag is enabled.** |

`blendFunc` component values:

```
GL_ZERO                   0
GL_ONE                    1
GL_SRC_COLOR              768
GL_ONE_MINUS_SRC_COLOR    769
GL_SRC_ALPHA              770
GL_ONE_MINUS_SRC_ALPHA    771
GL_DST_ALPHA              772
GL_ONE_MINUS_DST_ALPHA    773
GL_DST_COLOR              774
GL_ONE_MINUS_DST_COLOR    775
GL_SRC_ALPHA_SATURATE     776
```

### 16.8 Matrices

| Declaration | Converts |
|---|---|
| `uniform mat4 gbufferModelView;` | **player space → view space**: `vec3 viewPos = mat3(gbufferModelView) * playerPos;` |
| `uniform mat4 gbufferModelViewInverse;` | `inverse(gbufferModelView)`, computed on the CPU. **View space → player space** — the single most-used matrix in a pack. |
| `uniform mat4 gbufferProjection;` | view space → clip space. Equals `gl_ProjectionMatrix` in every gbuffers program **except `gbuffers_hand` / `gbuffers_hand_water`**, where `gl_ProjectionMatrix` multiplies Z by `MC_HAND_DEPTH`. |
| `uniform mat4 gbufferProjectionInverse;` | clip space → view space (CPU inverse). |
| `uniform mat4 shadowModelView;` | shadow-pass model → shadow view; equals `gl_ModelViewMatrix` while the shadow map is being generated. |
| `uniform mat4 shadowModelViewInverse;` | its inverse. |
| `uniform mat4 shadowProjection;` | shadow view → shadow clip; equals `gl_ProjectionMatrix` in the shadow program. |
| `uniform mat4 shadowProjectionInverse;` | its inverse. |
| `uniform mat4 gbufferPreviousModelView;` | the previous frame's `gbufferModelView` (TAA / motion vectors). |
| `uniform mat4 gbufferPreviousProjection;` | the previous frame's `gbufferProjection`. |
| `gl_ModelViewMatrix` (built-in) | model space → view space. **Equal to `mat4(1.0)` in `begin`, `prepare`, `deferred`, `composite` and `final`.** Core: `uniform mat4 modelViewMatrix;` |
| `gl_ModelViewMatrixInverse` | its inverse (CPU). Core: `modelViewMatrixInverse`. |
| `gl_ProjectionMatrix` | view space → clip space. Core: `projectionMatrix`. |
| `gl_ProjectionMatrixInverse` | its inverse (CPU). Core: `projectionMatrixInverse`. |
| `gl_ModelViewProjectionMatrix` | `gl_ProjectionMatrix * gl_ModelViewMatrix` (up to rounding). |
| `gl_NormalMatrix` | model-space normal → view space. Core: `uniform mat3 normalMatrix;` |
| `gl_TextureMatrix[0]` | UV transform for `gl_MultiTexCoord0` — mainly the armour glint scroll, but mods apply it too. **Use it in every gbuffers-style program.** |
| `gl_TextureMatrix[1]` | UV transform for `gl_MultiTexCoord1` (lightmap). Use it in every gbuffers program that reads `gl_MultiTexCoord1`. |

Core-profile lightmap matrix (Iris does **not** expose `gl_TextureMatrix[1]` as
a uniform in core):

```glsl
const mat4 TEXTURE_MATRIX_2 = mat4(
    vec4(0.00390625, 0.0, 0.0, 0.0),
    vec4(0.0, 0.00390625, 0.0, 0.0),
    vec4(0.0, 0.0, 0.00390625, 0.0),
    vec4(0.03125, 0.03125, 0.03125, 1.0)
);
vec2 lmcoord = (TEXTURE_MATRIX_2 * vec4(vaUV2, 0.0, 1.0)).xy;
```

**The canonical un-projection chain** (memorise this):

```glsl
vec3 ndc      = vec3(texcoord, depth) * 2.0 - 1.0;
vec4 viewPos4 = gbufferProjectionInverse * vec4(ndc, 1.0);
viewPos4     /= viewPos4.w;
vec3 viewPos  = viewPos4.xyz;
vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
vec3 worldPos  = playerPos + cameraPosition;
```

---

## 17. `shaders.properties`

This is the pack's main configuration file: `shaders/shaders.properties`. It
configures user-visible options **and** internal settings. Directives are
`key = value`, one per line, in any order.

A representative file:

```properties
# feature requirements
iris.features.required = CUSTOM_IMAGES COMPUTE_SHADERS SSBO REVERSED_CULLING

# program ordering
separateEntityDraws = true

# shadows
shadow.culling = reversed

# a custom image
image.testImage = c_testImage rgba rgba32f float false true 0.5 0.5

# the settings screen
screen = <empty> <profile> <empty> [SHADOWS] [LIGHTING] [ATMOSPHERE] <empty> * 
screen.columns = 3
sliders = shadowDistance SSAO_RADIUS BLOOM_STRENGTH
profile.LOW = SHADOW_RES:0 SSAO:0 BLOOM:0
profile.MED = !SHADOW_RES:1 SSAO:1 BLOOM:1
profile.HIGH = SHADOW_RES:2 SSAO:1 BLOOM:2
```

Preprocessor `#if` blocks **may** be used in `shaders.properties`, with option
macros. **`#define` and `#include` may not.**

### 17.1 Shader pack settings (user options)

Options are plain `#define` macros in your shader source. Iris scans them and
builds a settings screen — you get the GUI for free.

**Boolean options**

```glsl
#define BLOOM // Adds a bloom effect
```

- Turning it off is done by **commenting out the define** — so the code that uses
  it must test with `#ifdef` / `#ifndef`, otherwise the option is not recognised
  as a boolean:
  ```glsl
  #ifdef BLOOM
      color.rgb += bloom;
  #endif
  ```
- An option that is only ever tested with `#if defined BLOOM && defined OTHER`
  will not appear in the menu at all. Keep a plain `#ifdef` somewhere.
- `#if defined A && defined B` works for combined conditions.

**Numeric options**

```glsl
#define SHADOW_RES 1 // [0 1 2] Shadow resolution
```

- The bracketed value list is **space-separated** — no commas. (A comma-separated
  list is treated as a single value.)
- Integer options can be tested with `#if`:
  ```glsl
  #if SHADOW_RES == 0
      #define shadowMapResolution 1024
  #elif SHADOW_RES == 1
      ...
  #endif
  ```

**Exposing existing constants.** Any `const` can be given a value list:

```glsl
const int shadowMapResolution = 2048; // [512 1024 2048 4096]
```

**Screen layout**

```properties
screen = OPTION | [SCREEN] | <profile> | <empty> | *
```

| Token | Meaning |
|---|---|
| `OPTION` | place a setting |
| `[SCREEN]` | place a sub-screen |
| `<profile>` | place the profile button |
| `<empty>` | a blank cell |
| `*` | **everything not already placed**, appended here |

Sub-screens:

```properties
screen = <empty> <profile> <empty> [SHADOWS] [LIGHTING] *
screen.SHADOWS = SHADOW_RES SHADOW_SOFTNESS SHADOW_BIAS
screen.LIGHTING = SSAO SSAO_RADIUS BLOCKLIGHT_STRENGTH
```

Sub-screens are **nestable** (`[A]` inside a screen definition).

Columns:

```properties
screen.columns = 3
screen.SHADOWS.columns = 2
```

Default `2`; Iris bumps it to `3` automatically when the screen is crowded.

**Sliders**

```properties
sliders = shadowDistance SSAO_RADIUS BLOOM_STRENGTH
```

- One **global** list — there is no per-screen slider list.
- The **order of the option's value comment** is what defines the slider's
  positions (`// [0 1 2 3]`). A slider is not a continuous control: it steps
  through the listed values.
- Options **not** in the `sliders` list cycle as buttons.

**Profiles**

```properties
profile.<name> = OPTION:value | OPTION=value | OPTION | !OPTION | profile.OTHER | !program.PROGRAM_NAME
```

| Form | Effect |
|---|---|---|
| `OPTION:value` | sets the option's selected value index |
| `OPTION=value` | sets the option to a value |
| `OPTION` | enables a boolean |
| `!OPTION` | disables a boolean |
| `profile.OTHER` | applies another profile first |
| `!program.PROGRAM_NAME` | disables a program |

A dimension prefix targets one world type, e.g. `world1/composite5`.

Full worked example:

```properties
screen = <empty> <profile> <empty> [SHADOWS] [LIGHTING] iScream uScream weAllScream forIceCream *
screen.columns = 3

screen.SHADOWS = SHADOW_RES SHADOW_SOFTNESS SHADOW_BIAS <empty> VOLUMETRIC_SHADOWS
screen.LIGHTING = SSAO SSAO_RADIUS <empty> BLOCKLIGHT_STRENGTH

sliders = SHADOW_SOFTNESS SHADOW_BIAS SSAO_RADIUS BLOCKLIGHT_STRENGTH

profile.LOW  = !SSAO !VOLUMETRIC_SHADOWS SHADOW_RES:0
profile.MED  = SSAO SHADOW_RES:1 BLOCKLIGHT_STRENGTH=3
profile.HIGH = SSAO VOLUMETRIC_SHADOWS SHADOW_RES:2 profile.MED
profile.ULTRA = profile.HIGH !program.composite12
```

`!program.composite12` is how a profile disables an expensive pass — Iris then
skips compiling and dispatching it entirely.

**Localisation — `shaders/lang/<lang_id>.lang`**

```properties
option.BLOOM = Bloom
value.BLOOM.0 = Off
value.BLOOM.1 = Low
value.BLOOM.2 = High
prefix.SSAO_RADIUS = Radius:
suffix.SSAO_RADIUS = blocks
screen.SHADOWS = Shadow Settings
option.SHADOW_SOFTNESS.comment = How soft the edge of shadows is. Higher is blurrier.
profile.comment = Presets range from Potato to Ultra.
```

| Key | Used for |
|---|---|
| `option.<opt>` | the option's label |
| `value.<opt>.<value>` | a value's label |
| `prefix.<opt>` | text before the control |
| `suffix.<opt>` | text after the control |
| `screen.<screen>` | a sub-screen's title |
| `option.<opt>.comment` | the tooltip |
| `profile.comment` | the profile button's tooltip |

Ship at minimum `en_us.lang`. Note that labels are the *only* place non-technical
users will meet your pack's documentation — write real tooltips.

### 17.2 Feature flags

```properties
iris.features.required = SSBO COMPUTE_SHADERS
iris.features.optional = BLOCK_EMISSION_ATTRIBUTE
```

**`required`** — if the running Iris does not support the feature the pack
**errors out** rather than misbehaving. It also **enables** the feature.

**`optional`** — defines `IRIS_FEATURE_<NAME>` (e.g.
`IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE`) so you can guard with `#ifdef`, and
enables nothing on its own.

| Flag | Notes |
|---|---|
| `BLOCK_EMISSION_ATTRIBUTE` | `at_midBlock.w` block emission |
| `CAN_DISABLE_WEATHER` | allows `weather = <geometry> <splashParticles>` |
| `COMPUTE_SHADERS` | `.csh`, needs OpenGL 4.3 |
| `CUSTOM_IMAGES` | **required** to use `image.*` |
| `ENTITY_TRANSLUCENT` | allows the `*_translucent` gbuffers programs |
| `HIGHER_SHADOWCOLOR` | **required** for `shadowcolor2`–`7` |
| `PER_BUFFER_BLENDING` | per-buffer `blend` targets |
| `REVERSED_CULLING` | required for `shadow.culling = reversed` |
| `SEPARATE_HARDWARE_SAMPLERS` | **required** for `shadowtex0HW` / `shadowtex1HW` |
| `SSBO` | **required** for `bufferObject` |
| `TESSELLATION_SHADERS` | **required** for `.tcs`/`.tes` (also spelled `TESSELATION_SHADERS`) |
| `FADE_VARIABLE` | **required** for `mc_chunkFade` |
| `TEXTURE_FILTERING` | **required** for `textureFilteringMode` |

```glsl
#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
    vec3 center = position + at_midBlock.xyz / 64.0;
    float emission = at_midBlock.w;
#endif
```

### 17.3 Programs / ordering

**Particle ordering**

```properties
particles.ordering = mixed
```

- `mixed` — opaque particles before `deferred`, translucent ones after. This is
  the default when the pack has **no** `deferred` program.
- `after` — all particles after `deferred`. The default when `deferred` exists.
- `before` — all particles before `deferred`.

`gbuffers_particles_translucent` requires `mixed`.

Legacy form: `particles.before.deferred` — still parsed, but overridden by
`particles.ordering`.

**`separateEntityDraws`**

```properties
separateEntityDraws = true
```

Draws translucent entities and block entities after `deferred`, through
`gbuffers_entities_translucent` / `gbuffers_block_translucent` (falling back to
the normal programs, but still drawn late).

> **Broken in newer Iris.** Do not depend on it; use `ENTITY_TRANSLUCENT` and
> `particles.ordering` instead.

**Enabling/disabling programs**

```properties
program.<program>.enabled = <boolean expression>
shadow.enabled = true
```

Concrete examples:

```properties
program.deferred.enabled = !BLOOM && (SSR || PARALLAX)
world1/program.composite12.enabled = VOLUMETRIC_CLOUDS
shadow.enabled = true
```

Modular pack architecture: each effect is a program guarded by an option, and
`program.*.enabled` means disabled passes cost **nothing** (not even a compile).

`shadow.enabled` gives explicit control over the whole shadow pass — useful for a
pack that only uses the shadow buffers for voxelisation via SSBOs/images.

**Shadow geometry selection**

```properties
shadowTerrain = true
shadowTranslucent = true
shadowEntities = true
shadowPlayer = true
shadowBlockEntities = true
shadowLightBlockEntities = true
```

`shadowPlayer` is **forced on** whenever `shadowEntities` is on (it also covers
ridden entities).

**`skipAllRendering`**

```properties
skipAllRendering = true
```

Kills all gbuffers geometry rendering but keeps the post passes and shadows. Aimed
at path tracers that synthesise the whole image themselves.

**`voxelizeLightBlocks`**

```properties
voxelizeLightBlocks = true
```

Light blocks (the invisible `/setblock light` blocks) are rendered into the shadow
pass as a **degenerate, invisible quad at the block centre**:

- `at_midBlock = 0`
- UV = 0
- `lmcoord.xy` = the block's light level

This is how modern packs get accurate light propagation from light blocks.

**`indirect` — GPU-driven compute dispatch**

```properties
indirect.<pass> = <ssboIndex> <offsetBytes>
```

The SSBO at `<ssboIndex>`, at `<offsetBytes>`, must contain a `uvec3` work-group
count.

> If you get this wrong your PC will most likely crash trying to dispatch
> `2147483647³` work groups. Clamp your counts on the GPU.

**`allowConcurrentCompute` and memory barriers**

```properties
allowConcurrentCompute = false
```

- **`false`** (and OptiFine's behaviour): one
  `glMemoryBarrier(TEXTURE_FETCH | SHADER_IMAGE_ACCESS)` runs **before and after
  every** compute dispatch. Safe, slow.
- **`true`**: a **single** barrier after the last compute of a composite pass.

Two consequences, stated as corollaries in the docs (credited to IMS's
ShaderDoc):

- **Sequential Dispatch Corollary** — pass A's compute always finishes before pass
  B's starts. So a compute-only pass may be defined **without** its composite
  counterpart, and pass ordering is a real synchronisation tool.
- **Parallel Dispatch Corollary** — two compute shaders **in the same pass** may
  overlap. So within one pass, either eliminate shared resources entirely or use
  **atomics only**.

If your compute results look half-written at random, this is why.

### 17.4 Features / options

```properties
clouds = fast
oldHandLight = false
supportsColorCorrection = true
```

| Directive | Values | Effect |
|---|---|---|
| `clouds` | `fast`, `fancy`, `off` | overrides the video setting for vanilla clouds |
| `moon` | `true`/`false` | whether vanilla draws the moon texture in `gbuffers_skytextured` |
| `sun` | `true`/`false` | same, for the sun |
| `sky` | `true`/`false` | vanilla sky disc, horizon and void in `gbuffers_skybasic` |
| `stars` | `true`/`false` | vanilla stars |
| `underwaterOverlay` | `true`/`false` | vanilla underwater overlay |
| `vignette` | `true`/`false` | vanilla vignette |
| `oldHandLight` | default **`true`** | `true` makes `heldBlockLightValue` the **max of both hands**; `false` gives each hand its own value |
| `oldLighting` | default `false` | vanilla per-orientation colour multiplier |
| `separateAo` | `true`/`false` | moves vanilla AO into the alpha channel of `gl_Color` |
| `supportsColorCorrection` | Iris 1.6.4+ | `true`: **you** handle DCI_P3 / Display P3 / REC2020 / Adobe RGB conversion. Otherwise Iris converts from sRGB for you. Read `currentColorSpace` for which space is in play |
| `weather` | `<geometry> <splashParticles>` | independently toggle weather geometry and splash particles; needs `CAN_DISABLE_WEATHER` |
| `endFlashShadows` | `true`/`false` | End flashes cast shadows; `shadowLightPosition` becomes `endFlashPosition` |

> **Bug:** `separateAo` requires the shadow pass to be enabled in order to work.

### 17.5 Rendering

**Alpha test**

```properties
alphaTest.<program> = <off|func ref>
```

Functions: `NEVER`, `LESS`, `EQUAL`, `LEQUAL`, `GREATER`, `NOTEQUAL`, `GEQUAL`,
`GL_ALWAYS`. Example:

```properties
alphaTest.gbuffers_water = GREATER 0.1
alphaTest.gbuffers_terrain = off
```

- On the **compatibility profile** Iris applies the test to `gl_FragData`-style
  outputs automatically.
- With **modern** syntax (`out vec4 color`) you only get the `alphaTestRef`
  uniform — *you* must call `discard`.

**Blending**

```properties
blend.<program>[.<buffer>] = <off|src dst srcA dstA>
```

The optional `.buffer` part needs `PER_BUFFER_BLENDING`.

```properties
blend.gbuffers_water = SRC_ALPHA ONE_MINUS_SRC_ALPHA ONE ONE_MINUS_SRC_ALPHA
blend.composite.colortex7 = off
```

Values: `ZERO`, `ONE`, `SRC_COLOR`, `ONE_MINUS_SRC_COLOR`, `DST_COLOR`,
`ONE_MINUS_DST_COLOR`, `SRC_ALPHA`, `ONE_MINUS_SRC_ALPHA`, `DST_ALPHA`,
`ONE_MINUS_DST_ALPHA`, `SRC_ALPHA_SATURATE`.

Default for transparent programs:
`SRC_ALPHA, ONE_MINUS_SRC_ALPHA, ONE, ONE_MINUS_SRC_ALPHA`.

**Viewport scale**

```properties
scale.<program> = <scale>
scale.<program> = <scale> <offsetX> <offsetY>
```

Scales the **viewport only** — buffer resolution is unchanged, so this is *not*
how you render at a lower resolution (use `size.buffer` for that). Useful for
split-screen, magnifiers, and camera feeds.

**Flipping**

```properties
flip.<program>.<buffer> = true
```

- `gbuffers` and `shadow` read **and** write the main buffer.
- `begin`, `shadowcomp`, `prepare`, `deferred`, `composite` read the **main**
  buffer and write the **alternate**, then swap.
- **No flip happens after a pass with no fragment shader** — a compute-only pass
  does not swap.

**Buffer size**

```properties
size.buffer.<buffer> = <width> <height>
```

- Integers = pixels; floats = a **fraction of the screen**.
- Buffers resized this way **cannot be written by gbuffers**.
- A **single program** can only write buffers of **identical size**.

**Culling**

```properties
backFace.solid = true
backFace.cutout = true
backFace.cutoutMipped = true
backFace.translucent = true
frustum.culling = true
occlusion.culling = false
shadow.culling = reversed
```

- `backFace.*` — back-face culling per render layer.
- `frustum.culling` — off-screen geometry culling.
- `occlusion.culling` — Iris only. Turning it off helps light-leak-free caves and
  fixes geometry popping in with custom culling, at a cost.
- `shadow.culling` — `true`, `false`, or **`reversed`**: no culling within
  `voxelDistance`, culling beyond it. Needs the `REVERSED_CULLING` flag.

**Depth control**

```properties
rain.depth = false
beacon.beam.depth = false
```

Whether rain and beacon beams write depth.

### 17.6 Custom uniforms

Declare uniforms computed from expressions, entirely in `shaders.properties` —
no shader code required:

```properties
uniform.<type>.<name> = <expression>
variable.<type>.<name> = <expression>
```

- `uniform.*` — uploaded to the shader (usable as `uniform <type> <name>;`).
- `variable.*` — an **intermediate** value, not uploaded. Used to build
  multi-step expressions, and to work around the no-swizzling rule.
- **Types:** `float`, `int`, `bool`, `vec2`, `vec3`, `vec4`. **No matrices.**
- **Not allowed:** dynamic per-draw uniforms — `entityColor`, `blockEntityId`,
  `fogMode`, `fogColor`, `chunkOffset`.

**Operators and literals:** `+ - * / %`, unary `-`, comparisons, boolean
`&& || !`, `? :`, parentheses, numeric literals, and `pi`.

**Functions** (about forty):

| Category | Functions |
|---|---|
| angles | `torad`/`radians`, `todeg`/`degrees` |
| trig | `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2` |
| exponential | `exp`, `pow`, `exp2`, `exp10`, `log(x)`, `log(base, value)`, `log2`, `log10` |
| common | `sqrt`, `abs`, `sign`/`signum`, `floor`, `ceil`, `frac`, `min`, `max`, `clamp`, `mix`, `fmod` |
| step | `edge(k, x)` — equivalent to GLSL `step` |
| random | `random()`, `random(min, max)`, `randomInt()`, `randomInt(min, max)` |
| logic | `if(cond, val, [cond2, val2, …], else)`, `between`, `equals(a, b, eps)`, `in(x, v1, v2, …)` |
| smoothing | `smooth([id], val, [fadeUp, [fadeDown]])` |

**Vector-capable:** `abs`, `floor`, `ceil`, `min`, `max`, `clamp`, `smooth`.

**Element access** — single components only, **no swizzling**:

```properties
# legal
uniform.float.sunHeight = sin(2.0 * pi * sunAngle)
uniform.float.viewAspect = viewWidth / viewHeight

# matrices: matrix.<row>.<column>, 0-based
uniform.float.camY = gbufferModelView.0.3
```

To combine components, go through `variable.*`:

```properties
variable.float.waterColorR = if(in(biome, BIOME_SWAMP, BIOME_MANGROVE_SWAMP), 0.2, 0.05)
variable.float.waterColorG = if(in(biome, BIOME_SWAMP, BIOME_MANGROVE_SWAMP), 0.25, 0.15)
variable.float.waterColorB = if(in(biome, BIOME_SWAMP, BIOME_MANGROVE_SWAMP), 0.12, 0.08)
uniform.vec3.waterColor = vec3(waterColorR, waterColorG, waterColorB)
```

**Worked examples**

```properties
# is the player in a forest-like biome?
uniform.bool.isOakBiome = in(biome, BIOME_FOREST, BIOME_DARK_FOREST)

# smoothed sprint factor: 2-tick fade, 0.25-tick lag
uniform.float.sprintFactor = smooth(if(is_sprinting, 1.0, 0.0), 2, 0.25)

# sun height above the horizon
uniform.float.sunHeight = sin(2.0 * pi * sunAngle)
```

```glsl
// in a shader
uniform bool  isOakBiome;
uniform float sprintFactor;
uniform float sunHeight;
uniform vec3  waterColor;
```

Custom uniforms make a lot of "just dab some settings" logic possible without
touching GLSL at all, and they keep the option surface in one file — but they are
evaluated **once per frame on the CPU**, so never put anything in them that must
vary per pixel.


---

# Part 3 — Auxiliary files, techniques, ecosystems

## 18. Auxiliary `*.properties` files

### 18.1 `block.properties`

Assigns IDs to blocks, which you read as `mc_Entity.x` (or `blockEntityId`,
`currentRenderedItemId` for block items).

```properties
block.<ID> = [<namespace>:]<block_id>[:<property>=<v1>,<v2>,...]
```

```properties
block.5  = stone minecraft:oak_trapdoor:open=true
block.6  = minecraft:oak_door:facing=north,south:hinge=right
block.10 = minecraft:water minecraft:flowing_water
```

- **One block → one ID; many blocks → one ID.** A single line may list any number
  of blocks and share one ID.
- **Block states** are selected with `:property=value` suffixes. Several values
  for the same property go in a comma-separated list
  (`facing=north,south`); several different properties are chained
  (`:facing=…:hinge=right`).
- **IDs are signed 16-bit** since Iris 1.3: `-32768` … `32767`. OptiFine has
  always been signed; Iris before 1.3 was unsigned.
- **Data-pack tags** (Iris 1.7+):

```properties
#ifdef IRIS_TAG_SUPPORT
block.7 = %minecraft:leaves
block.8 = %minecraft:logs
#endif
```

With `IRIS_TAG_SUPPORT >= 2` (Iris 1.8+), **individual block entries take
priority over tag entries** — so you can tag a whole group and then override one
block.

**Render layers.** Instead of listing blocks, assign them to a render layer, which
maps them onto specific gbuffers programs:

```properties
layer.solid = minecraft:stone
layer.cutout = minecraft:oak_leaves
layer.cutout_mipped = minecraft:grass_block
layer.translucent = minecraft:water
```

| Layer | Program |
|---|---|
| `solid` | `gbuffers_terrain_solid` |
| `cutout` | `gbuffers_terrain_cutout` |
| `cutout_mipped` | `gbuffers_terrain_cutout` (**identical to `cutout` in Iris**) |
| `translucent` | `gbuffers_water` |

> **Warning:** render layers do **not** change culling or sorting. Moving blocks
> from `solid` to `translucent` can punch visible holes in the world, because the
> geometry still renders in the solid pass's order. Use layers for *shader
> selection*, not to re-sort geometry.

### 18.2 `entity.properties`

```properties
entity.<ID> = [<namespace>:]<entity_id>
```

```properties
entity.1 = minecraft:skeleton minecraft:sheep
entity.2 = minecraft:zombie
```

- Read as `entityId`, and `vehicleId` for the ridden entity.
- 16-bit **unsigned**: `0`–`65535`.
- Hard-coded IDs that always exist:

```
minecraft:name_tag
entity_shadow
entity_flame
zombie_villager_converting
current_player
end_crystal_beam
```

`entity_shadow` and `entity_flame` are Iris conveniences — the fake entities that
render name tags and fire.

### 18.3 `item.properties`

```properties
item.<ID> = [<namespace>:]<item_id|armor_id>
```

```properties
item.1 = minecraft:diamond_sword
item.2 = minecraft:diamond_helmet
```

- Read as `heldItemId`, `heldItemId2` anywhere, and `currentRenderedItemId` in
  gbuffers / shadow programs.
- 16-bit unsigned.
- Hard-coded IDs: `trim_<material>` (e.g. `trim_emerald`, `trim_gold`),
  `minecraft:player_cape`, `minecraft:elytra_with_cape`.

### 18.4 `dimension.properties`

Point different dimensions at different shader folders:

```properties
dimension.<folder_name> = [<namespace>:]<dimension_name> [more dimensions...]
```

```properties
dimension.netherShaders    = minecraft:the_nether
dimension.endShaders       = minecraft:the_end
dimension.supportsShadows  = minecraft:the_overworld minecraft:the_end *
```

- `<folder_name>` is a real folder inside `shaders/`, containing a full set of
  programs.
- `*` is a wildcard, so the last line above means "the Overworld, the End, and
  anything else".
- Dimensions not matched use the programs **directly in `shaders/`**.
- **Legacy form:** `world0` (Overworld), `world-1` (Nether), `world1` (End)
  folders. If **any** `worldN` folder exists, only `worldN` folders are used and
  the `dimension.*` routes are ignored.

Note the `dimension.*` form is also how Iris decides **which programs exist for
which dimension** — a program absent from the dimension's folder simply is not
compiled there, which is the cheapest possible way to ship a Nether-specific
pipeline.

### 18.5 `texture.properties` (resource pack side)

Never written by you; read by you. A resource pack declares its PBR format:

```properties
format=lab-pbr
```

or

```properties
format=lab-pbr/1.3
```

which becomes the `MC_TEXTURE_FORMAT_LAB_PBR` / `MC_TEXTURE_FORMAT_LAB_PBR_1_3`
macros. Only `1.3` is supported.

---

## 19. How-to topics: profiles, coordinate spaces, PBR

### 19.1 Compatibility vs. Core Profiles

**TL;DR: use `#version <n> compatibility`.** Iris patches compatibility-profile
code into valid modern GLSL internally, and that patcher is far better tested
than the core path.

Background:

- OpenGL 2.0 exposed legacy `gl_*` attributes (`gl_Vertex`, `gl_Color`, …).
- GLSL 150 introduced **`compatibility`** (legacy built-ins available) vs
  **`core`** (they are not).
- Minecraft 1.17 moved to OpenGL 3.2, whose compatibility profile is gone from the
  API, so the game now exposes its own attributes: `vaColor`, `vaPosition`,
  `vaNormal`, `vaUV0`, `vaUV2`.
- OptiFine and Iris **patch compatibility code to core internally**, so both
  profiles work and behave identically.

Two concrete reasons not to use `core`:

1. **Game attributes get renamed.** Minecraft 1.21.2 renamed `chunkOffset` to
   `modelOffset`; **Iris only supports `chunkOffset`**. Core-profile packs are
   directly exposed to that kind of churn; compatibility packs are insulated by
   the patcher.
2. **The core path is much less exercised.** Bugs in it are found by you.

Full mapping:

| Compatibility | Core equivalent |
|---|---|
| `gl_Vertex` | `vaPosition + chunkOffset` |
| `gl_ModelViewMatrix` | `modelViewMatrix` |
| `gl_ProjectionMatrix` | `projectionMatrix` |
| `gl_Color` | `vaColor` |
| `gl_Normal` | `vaNormal` |
| `gl_NormalMatrix` | `normalMatrix` |
| `gl_MultiTexCoord0` | `vaUV0` |
| `gl_TextureMatrix[0]` | `textureMatrix` |
| `entityColor` | `vaUV1` (*not recommended*) |
| `gl_MultiTexCoord1` | `vaUV2` |
| `gl_MultiTexCoord2` | `vaUV2` |
| `gl_TextureMatrix[1]` | user-defined `TEXTURE_MATRIX_2` |

### 19.2 Coordinate Spaces

These are the spaces you will move between constantly, and getting them wrong is
the number-one source of "why does my effect slide when I turn?" bugs.

**Model space** — the space vertices arrive in. Its relation to the world is
**unknown and variable** (chunks are in their own local origin, entities have
their own origins and transforms). **Never assume model space is world space.**
Always convert via the matrix chain, or in core profile via `vaPosition +
chunkOffset`.

**View space** (eye space) — relative to the camera, rotated with it. `z` points
"backwards" (towards the viewer in OpenGL convention), so a point in front of you
has a **negative** z.

```glsl
vec3 viewPos = (gl_ModelViewMatrix * vec4(modelPos, 1.0)).xyz;
```

**Player space** (world-aligned player space) — centred on the camera but with the
world's axis directions. This is the space you want for lighting, because sun
direction and surface normals must agree on axes.

```glsl
vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
```

**Feet player space vs eye player space** — both are "player space", and they
differ only by a vertical offset (view bobbing):

```glsl
const vec3 eyeOffset = gbufferModelViewInverse[3].xyz;
// feet = eye - eyeOffset
```

They are identical in third person, because the camera is not the model's eye.
Mixing the two is what makes a shader's lighting pop by a few pixels while
walking.

**World space** — absolute. `worldPos = playerPos + cameraPosition`.

`cameraPosition` is **precision-wrapped**: modern Iris resets it every `30000`
blocks walked or on a teleport over `1000` blocks (OptiFine every `1000024`). For
exact positions that survive the wrap, use the Iris-exclusive pair:

```glsl
vec3 exactCameraPos = cameraPositionInt + cameraPositionFract;
```

`cameraPositionInt` is the truncated value and is **not shifted**. This matters
for anything you key a texture or a voxel grid to: using wrapped
`cameraPosition` makes the pattern jump every 30000 blocks.

**Shadow spaces** — shadow view → shadow clip → shadow NDC → shadow screen. In
the shadow pass use the `gl_*` matrices; anywhere else use `shadowModelView` /
`shadowProjection`. See [the shadow-space chain](#83-the-shadow-space-transform-chain).

### 19.3 PBR Standards

A resource pack can ship `_n` (normal) and `_s` (specular) variants of block
textures. Iris binds them as two atlases:

```glsl
uniform sampler2D normals;
uniform sampler2D specular;
```

Two competing conventions exist:

**labPBR** — the preferred, modern convention (from shaderLABS). Recommended for
anything new: it is well-specified, has a version tag, and supports extra channels
(porosity, subsurface scattering, hardness) beyond the basics.

**oldPBR / seusPBR** — the pre-labPBR convention. Channel layout:

| Texture | Channels |
|---|---|
| `_n` | `rgb` = normal, `a` = height |
| `_s` | `r` = smoothness, `g` = metallness, `b` = emissiveness |

Most modern packs have dropped oldPBR, so support it only if you are taking over
an old pack.

**Detection.** Read the resource pack's declared format, via the macros:

```glsl
#ifdef MC_TEXTURE_FORMAT_LAB_PBR
    // labPBR resource pack detected
    #ifdef MC_TEXTURE_FORMAT_LAB_PBR_1_3
        // spec 1.3 features available
    #endif
#else
    // oldPBR or no PBR data
#endif
```

Remember the atlas defaults: `normals` falls back to a **flat** normal
`(127,127,255,255)` and `specular` falls back to **all zeros** (no specular), so
your code is safe without any PBR resource pack installed — but it must handle
"everything is either perfectly flat or fully non-specular", which is exactly what
a pack without PBR looks like.

### 19.4 Include files

```glsl
#include "<path>"
```

- A **leading slash** means the path is relative to `shaders/`:
  `#include "/lib/util.glsl"`
- **No leading slash** means relative to the current file:
  `#include "util.glsl"`

Node-canonical layout: `shaders/lib/` for shared code, and `#include
"/lib/util.glsl"` everywhere. Iris resolves includes itself; `moj_import` is a
different mechanism (`moj_import` becomes a reserved prefix — see the patcher).

### 19.5 The Iris patcher

Iris does not send your source to the driver. It runs it through
**`glsl-transformer`** and sends the **patched** result. Consequences:

- **Whitespace is removed**, so error messages' line numbers do **not** match your
  file. With debug mode on, the patched source is in `.minecraft/patched_shaders/`
  — read *that* file at the reported line.
- **Reserved identifiers:** you may not use `iris_`, `irisMain` or `moj_import`
  as (parts of) your identifier names.
- The patcher **fixes some invalid code and sometimes introduces bugs**. If a
  shader works in one pack but not another, and the code is identical, suspect the
  patch pass — check `/patched_shaders/`.

### 19.6 macOS and the OpenGL ceiling

Apple caps OpenGL at **4.1** and blocks third-party drivers. Therefore on macOS
there are:

- **no compute shaders** (`setup`, `.csh`, compute in composite passes),
- **no custom images** (needs 4.2),
- **no SSBOs** (needs 4.3),
- **no atomic counters**,
- and OptiFine additionally caps `colortex` to **8** buffers (Iris gives all 16).

Experimental workarounds exist — **Zink**, **Whisky/GPTK** (D3DMetal-based),
Parallels/VMware — and are explicitly **unsupported**. Guard advanced features
with `iris.features.required` so the pack fails loudly and cleanly rather than
producing a black screen.

---

## 20. Mod support

Iris integrates with several mods that render geometry through the shader
pipeline. Each has its own defines and uniforms.

### 20.1 Distant Horizons (DH)

DH renders far-away LOD terrain. It has its own programs and attributes, and one
hard rule.

**Programs:** `dh_terrain`, `dh_water`, `dh_shadow`.

> `dh_*` programs **must** use `compatibility` — the core profile does not work
> for them.

**Attributes available** (a deliberately small set):

- `gl_Vertex`
- `gl_MultiTexCoord2`
- `gl_Normal`
- `gl_Color`
- `dhMaterialId` (**no `mc_Entity`** — LOD chunks have no block IDs)

**Matrices:** `gl_ModelViewMatrix`, `gl_ModelViewMatrixInverse`,
`gl_ProjectionMatrix`, `gl_ProjectionMatrixInverse`, `gl_NormalMatrix`.

**Shadow pass:** enabled by default; toggle with `dhShadow.enabled`.

**No shadow distance:** all LOD chunks render into the shadow map, which is why
DH shadows are expensive.

**Depth samplers:** `dhDepthTex0`, `dhDepthTex1` — the LOD equivalent of
`depthtex0/1`.

**Uniforms:**

```glsl
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float dhRenderDistance;
uniform mat4  dhProjection;
uniform mat4  dhProjectionInverse;
uniform mat4  dhPreviousProjection;
```

**Material IDs.** `int dhMaterialId` with these defines:

```
DH_BLOCK_UNKNOWN  DH_BLOCK_LEAVES   DH_BLOCK_STONE   DH_BLOCK_WOOD
DH_BLOCK_METAL    DH_BLOCK_DIRT     DH_BLOCK_GRASS   DH_BLOCK_LAVA
DH_BLOCK_DEEPSLATE DH_BLOCK_SNOW    DH_BLOCK_SAND    DH_BLOCK_TERRACOTTA
DH_BLOCK_NETHER_STONE  DH_BLOCK_WATER  DH_BLOCK_AIR  DH_BLOCK_ILLUMINATED
```

**Define:** `DISTANT_HORIZONS` is available in all programs and in the
`.properties` files, so you can conditionally enable DH code paths.

### 20.2 Vivecraft (VR)

**Define:** `VIVECRAFT`.

```glsl
uniform bool vivecraftIsVR;
uniform int  vivecraftRenderpass;
```

`vivecraftRenderpass` compared against:

```
VIVECRAFT_PASS_LEFT   VIVECRAFT_PASS_RIGHT  VIVECRAFT_PASS_CENTER
VIVECRAFT_PASS_THIRD  VIVECRAFT_PASS_GUI    VIVECRAFT_PASS_SCOPER
VIVECRAFT_PASS_SCOPEL VIVECRAFT_PASS_CAMERA VIVECRAFT_PASS_MIRROR
VIVECRAFT_PASS_VANILLA
```

**Hand uniforms:**

```glsl
uniform vec3  vivecraftRelativeMainHandPos;
uniform vec3  vivecraftRelativeOffHandPos;
uniform mat4  vivecraftRelativeMainHandRot;   // holds a 3x3 rotation; cast to mat3
uniform mat4  vivecraftRelativeOffHandRot;
```

The rotation matrices hold a **3×3** rotation inside a `mat4` — cast with
`mat3(vivecraftRelativeMainHandRot)`.

In VR, "the camera" is not "the eyes": expect to handle left/right eyes as
separate `renderpass` values in a single frame.

### 20.3 Voxy

A LOD renderer in the same family as Distant Horizons. The docs page is a stub
pointing at **the `#docs` channel in Cortex's Discord Server**. Treat it as
undocumented: no official uniform/attribute contract exists yet.

### 20.4 Colorwheel

The docs page is a stub linking to `djefrey.github.io/colorwheel/` — a rendering
library/mod with its own documentation site. Nothing authoritative in Iris Docs.

### 20.5 Photonics

Also a stub, linking to the **PhotonicEngine wiki**. Read that wiki for the
uniform contract.

### 20.6 Aperture (legacy)

Aperture was the older Iris-adjacent alternative pipeline, built on a TypeScript
pipeline (`pack.ts`) with `configureRenderer`, `configurePipeline`, object
shaders, and mandatory "combination passes". **It has since moved to Slang and the
migration guide is explicitly marked "extremely outdated".** Do not start a new
project on Aperture; the Iris/OptiFine pipeline documented here is the supported
path.

---

## 21. Debugging, performance and shipping

### 21.1 Reading compile errors

With debug mode on (**Ctrl + D** on the shader selection screen, restart), the log
prints compilation errors. The line numbers refer to the **patched** source, which
lives in `.minecraft/patched_shaders/`. Example:

```
deferred2.fsh: ERROR: 0:336
```

means: read line 336 of `patched_shaders/005_deferred2.fsh` (the numeric prefix
varies).

**AMD + "use no error context" can prevent the game from loading at all.** Fix:

```
.minecraft/config/sodium-options.json → "use_no_error_g_l_context": false
```

### 21.2 GPU debuggers

**RenderDoc** — the free, cross-vendor choice. It captures a whole frame with
every draw call, every buffer and every shader.

- **Windows with the GFX-Debuggers mod**: run the game with the mod, then
  *File ▸ Attach to Running Instance ▸ javaw*.
- **Without the mod**: process injection must happen **before** OpenGL
  initialises, which means launching Minecraft from inside RenderDoc.
- **Linux**: `LD_PRELOAD=/usr/lib64/renderdoc/librenderdoc.so <launcher>`.

**NVIDIA Nsight** — NVIDIA-only, but with better vendor-specific insight. Use it
via the GFX-Debuggers mod, or by launching the launcher from Nsight.

Captures let you do what the docs cannot: *look at the buffer* and see whether it
actually contains what you think.

### 21.3 Performance checklist

1. **Resolution dominates.** Shadow map and screen resolution are the two biggest
   costs. Most slow packs are simply running too many full-resolution passes.
2. **Every tap costs.** A 81-tap PCF kernel at 4K is 81 × 8.3 M samples per frame.
   Rotate + fewer taps, or blur in a separate lower-resolution pass.
3. **Disable unused programs.** `program.<name>.enabled` prevents compilation and
   dispatch entirely — the cheapest optimisation there is.
4. **Use lower-resolution buffers** for anything that is blurred anyway:
   `size.buffer.colortex7 = 0.5 0.5`.
5. **Prefer `RENDERTARGETS` over `DRAWBUFFERS`** and pack multiple values per
   buffer rather than adding buffers; VRAM bandwidth is usually the real limit.
6. **Compute where the GPU is starving.** `workGroupsRender` with modest local
   sizes (8×8) beats giant work groups.
7. **Avoid `discard` where it hurts.** It disables early-z on many drivers. Do
   alpha test only where needed.
8. **`colortex` formats matter.** `RGBA32F` per buffer at 4K is 33 MB each; 16
   buffers of that is half a gigabyte.

### 21.4 Shipping checklist

- [ ] `iris.features.required` lists every advanced feature you actually use, so
      unsupported systems **error instead of breaking silently**.
- [ ] Every option is tested with a plain `#ifdef`, or it will not appear in the
      menu.
- [ ] Value lists are **space-separated**, and `sliders` matches them.
- [ ] `shaders/lang/en_us.lang` exists with real labels and tooltips.
- [ ] Profiles (`LOW` / `MED` / `HIGH`) exist and are tested — this is what saves
      a pack from a review saying "unusable at 5 fps".
- [ ] Defaults are the *low* preset, not the showcase preset.
- [ ] Behaviour without a PBR resource pack is correct (flat normals, zero
      specular).
- [ ] `compatibility` profile everywhere, including `dh_*`.
- [ ] A `dimension.properties` or `worldN` folder setup exists if the Nether/End
      need different programs.
- [ ] A licence is present and its terms are compatible with what you took from
      Base-330 or other packs.
- [ ] No `#version` mismatch between included files.
- [ ] Tested at both 1080p and 4K, and with Fabulous graphics off (Fabulous breaks
      many packs).

---

## 22. Cheat sheet

### 22.1 Pass order

```
setup → begin → shadow → shadowcomp → prepare
      → gbuffers (opaque) → deferred → gbuffers (translucent)
      → composite → final
```

### 22.2 What writes what

| Program | Writable |
|---|---|
| `setup` | images, SSBOs (compute only) |
| `begin` | `colortex`, images |
| `shadow` / `shadow_*` | `shadowcolor0/1`, `shadowtex0/1` (depth) — **not** `colortex` |
| `shadowcomp` | `shadowcolor`, images |
| `prepare` | `colortex`, images |
| `gbuffers_*` | `colortex` (4+), `depthtex` via `gl_FragDepth` |
| `deferred` | `colortex`, images |
| `composite` | `colortex`, images |
| `final` | the **backbuffer** |

### 22.3 The five outputs every pack needs

```glsl
/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA16;

const int shadowMapResolution = 2048;
const float shadowDistance = 160.0;
const float shadowDistanceRenderMul = 1.0;
const float sunPathRotation = -40.0;
const float shadowIntervalSize = 2.0;
const bool shadowHardwareFiltering = false;
*/
```

### 22.4 Most-used uniform one-liners

```glsl
vec3 sunDir     = normalize(0.01 * shadowLightPosition);      // view space
vec3 sunDirPl   = mat3(gbufferModelViewInverse) * sunDir;    // player space
float dayFactor = smoothstep(0.0, 0.2, sunDir.y);            // crude daylight
float dist      = length(viewPos) / far;                     // 0..1 render distance
vec2 uv         = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
vec2 lm         = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy / (30.0/32.0) - (1.0/32.0);
vec3 normalWS   = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
```

### 22.5 Buffer defaults and clearing

| Buffer | Default format | Clear value |
|---|---|---|
| `colortex0` | RGBA8 | vanilla fog colour, alpha `1` |
| `colortex1` | RGBA8 | `vec4(1.0)` |
| `colortex2`…`15` | RGBA8 | `vec4(0.0)` |
| `depthtex0/1/2` | depth+stencil | `1.0` |
| `shadowtex0/1` | depth+stencil | `1.0` |
| `shadowcolor0/1` | RGBA8 | `vec4(1.0)` (white) |
| `noisetex` | RGB8 | random noise |

### 22.6 Symptom → cause

| Symptom | Likely cause |
|---|---|
| Cutout textures are opaque squares | missing `if (a < alphaTestRef) discard;` |
| Shader compiles but output is black | `RENDERTARGETS` missing, or writing `location` beyond the list |
| Buffers contain garbage in a gbuffers program | reading `colortex0`–`3` in gbuffers (you get the atlas) |
| Everything slides when you turn | mixing view-space and player-space data |
| Pattern jumps every 30000 blocks | using wrapped `cameraPosition` for world-space keys |
| Shadow acne | missing `shadowScreenPos.z -= bias` |
| Peter-panning | bias too large |
| Shadows shimmer while walking | `shadowIntervalSize = 0`, or missing distortion symmetry |
| A pass mysteriously does nothing | a `flip.*` after a pass with no fragment shader, or `program.*.enabled` |
| Compute results are half-written | `allowConcurrentCompute = true` with shared buffers, no atomics |
| Textures wrong only on glint / modded items | forgot `gl_TextureMatrix[0]` |
| `MC_HAND_DEPTH`-related depth errors | un-projecting hand pixels without dividing by it |
| Works in OptiFine, not in Iris | `gbuffers_entities_glowing`, or a core-profile assumption |
| `transparent`/`separateAo` effects misbehave | `separateEntityDraws` is broken in new Iris; `separateAo` needs shadows on |

### 22.7 Glossary

**gbuffers** — the passes that draw real geometry into screen buffers.
**composite** — fullscreen passes that process those buffers.
**colortex** — screen-sized colour buffers; 16 by default.
**depthtex** — screen-sized depth buffers; three variants.
**shadowtex** — shadow-map depth buffers; `0` all geometry, `1` opaque only.
**shadowcolor** — shadow-map colour, used for translucent shadows.
**RENDERTARGETS** — the comment that says which buffers a fragment shader writes.
**flip** — double-buffering a buffer for a program.
**deferred** — lighting done in a later pass from stored surface data.
**player space** — camera-relative but world-axis-aligned.
**features flags** — `iris.features.required/optional`; capability declaration.

---

## Appendix: source map

Everything above is drawn from **https://shaders.properties**, the official Iris
documentation (framework: Starlight; content: `IrisShaders/docs`). Its structure,
for reference:

- **Home** (`/`) — splash page, links to the guide and the reference.
- **Reference** (`/current/reference/…`) — Overview, Attributes, Buffers,
  Constants, Macros, Miscellaneous, Programs, Shaders.Properties, Uniforms,
  Mod Support.
- **Guides** (`/current/guides/your-first-shaderpack/`) — the seven-chapter
  tutorial followed in Part 1:
  `0_intro`, `1_composite`, `2_gbuffers`, `3_deferred_lighting`, `4_shadows`,
  `5_fog`, `6_next_steps`.
- **How To** (`/current/how-to/…`) — `compatibility_vs_core`,
  `coordinate_spaces`, `pbr_standards`.
- **Legacy** (`/aperture/migration/`) — the outdated Aperture guide.

Badges used throughout the docs, and here: **Iris Only / Iris Exclusive** (an
addition over OptiFine), **OptiFine Custom Uniforms / Iris** (OptiFine exposes it
only to custom uniforms), **Legacy**, **Unfinished**.

The docs are honest about being incomplete — the Programs overview carries an
"Unfinished" badge and several mod-support pages are one-line stubs — so for
anything not covered, the authoritative supplements are OptiFine's `shaders.txt`
(the original pipeline specification), the **Iris ShaderDoc**, and the
**shaderLABS** community.
