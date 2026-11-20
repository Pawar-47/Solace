# Performance experiments

This is the `perf-experiments` branch. `main` is untouched: it still has the pack as
it was, and its rolling `latest` release still points there. Nothing here ships until
it has been tried on the actual machine and has earned its place.

Where to get it, though: every push to this branch publishes
`perf-experiments-Solace-LowEnd.zip` into that same `latest` release, beside the stable
`Solace-LowEnd.zip`, which it never touches. Same install steps as the pack itself.

The target is an Intel HD 5500: 23 execution units, no VRAM of its own, about 23 GB/s
of system memory shared with the CPU. The FP32 arithmetic works out at roughly
370 GFLOPs (23 EU x 8 lanes x 2 for FMA x ~1 GHz) and special functions at a quarter of
that. The numbers that matter are the ratios, not the totals, and they say the opposite
of what most optimisation advice assumes: **arithmetic is nearly free here and bytes are
not.**

## What was already on main

- One `sin()` per pixel instead of four to six: the day mixers and the sun colour are
  pure functions of the sun's height, computed once and passed down.
- Constant powers as multiplies (`solPow4/5/6`): `pow(x, 6.0)` is a log and an exp.
- Fog per vertex, not per pixel.
- Bloom gathered from a mip level instead of 40 full-resolution taps.
- The reflection march in exponential steps with three bisections, so six fetches cover
  more than twelve linear ones.
- Water waves at one octave per layer (six noise evaluations, not fifteen).
- Everything heavy behind an option that is off by default, and five profiles.

## What this branch adds

### 1. Ambient and block light per vertex (`VERTEX_LIGHTING`, on here)

The fragment stage was computing, for every lit pixel: the palette mix for ambient
light, a square root, a sixth power, and the whole candle curve for block light. None
of those change faster than the lightmap does, and Minecraft's own smooth lighting
interpolates the lightmap per vertex already.

They now run once per vertex in `lib/vertex_geometry.glsl` and arrive as one varying.
What leaves the fragment stage: a `sqrt`, a `x^6` (six multiplies), the palette mix,
two multiplies and an add. What arrives: three interpolated floats.

The trade is real but small: where a lightmap value changes across a single block face
— a torch right against a wall — the light is now interpolated across that face
instead of sampled per pixel. That is the same approximation vanilla has always made.

Turn it off with `VERTEX_LIGHTING 0` to get the per-pixel path back; both are compiled
from the same source and nothing else changes. Water uses the same varying now, so a
water pixel no longer pays the palette mix and the candle curve either.

### 2. Loops walk, they do not recompute

The ambient-occlusion ring, the bloom gather and the depth-of-field ring each called
`cos()` and `sin()` **per tap** to place the tap. With six AO taps that is 12
transcendentals per pixel in a full-screen pass before a single depth fetch is issued.

Each loop now takes one `cos`/`sin` pair for its starting direction and rotates that
direction by the golden angle per iteration: four multiplies and two adds, on the ALU
instead of the SFU. The tap pattern is unchanged — the golden angle is what both forms
walked around.

### 3. Hardware PCF

`shadowtex1` is declared as a `sampler2DShadow`, and the shadow lookup uses
`shadow2D()`. With `shadowHardwareFiltering = true` one comparison already filters
four texels, so the soft path gets 16-texel coverage for four instructions instead of
four fetches and four `step()`, and the hard path gets a filtered tap for free.

### 4. One noise octave per cloud sample

The cloud march sampled two octaves per step. With four to ten steps and the second
octave being averaged away as noise, it doubled the cost of every sky pixel while
clouds are on. Single octave now, with the same coverage.

### 5. Two buffers are no longer cleared

`colortex0` is filled edge to edge by `prepare` before anything else is drawn, and
`colortex1` is only read when the pass that writes it has run. Neither needs its old
contents wiped: that is two full-screen writes saved per frame, 1.4 million pixels
each at 1600x900.

### 6. One render target instead of eight

No gbuffer program declared its outputs, and Iris binds the **first eight colour
attachments** when it finds no `DRAWBUFFERS` or `RENDERTARGETS` directive. Every
`gbuffers_*` program here writes exactly one target, so every one of them now says so.

Two reasons this is worth more than it looks. The obvious one is bandwidth and
setup: eight attachments configured for a pass that fills one. The other is a
compatibility problem: Intel's GLSL compiler documents support for **seven**
framebuffer attachments, so the default configuration was one over the limit on the
very GPU this pack is written for.

The directive lives in the shared libraries the programs already include
(`lib/fragment_geometry.glsl`, `fragment_water`, `fragment_glowing`, `fragment_clouds`,
`fragment_skybasic`) and in each small program that has no library, so there is one per
program and no chance of drift.

### 7. Solid terrain keeps early-Z

A `discard` is documented by NVIDIA as one of the things that makes a driver turn
early-Z off, and terrain hidden behind terrain is the largest source of overdraw in a
Minecraft world. Solid terrain has no transparency to test, so the test was costing
early-Z for nothing.

Iris has separate programs for the solid and cutout layers, with `gbuffers_terrain` as
the fallback for both. The pack now ships all three: `gbuffers_terrain_solid` compiles
the alpha test out, `gbuffers_terrain_cutout` keeps it, and `gbuffers_terrain` (which
OptiFine uses for both layers) keeps it too. The whole difference is one define,
`SOLACE_ALPHA_TEST`, read in `lib/fragment_geometry.glsl`.

### 8. Two more small powers as multiplies

The sky's sun halo needs `x^9`, the cloud lining needs `x^8`, and the water fresnel
needs `x^5`. All three were `pow()`, which is two special functions each; all three are
now three or four multiplies. The tight ones stay: `pow(x, 110)` for the sun's core and
`pow(x, 44)` for the gloss highlight would need longer chains than the pair of special
functions costs.

### 9. Exposure from a mip level

Auto exposure averaged the frame with nine strided texture fetches, on every pixel of
the screen, to produce **one** number. `colortex0` already carries a mip chain for the
bloom, and a mip level is a true box average of the whole frame — a better average than
nine taps, for one fetch.

### 10. No `sqrt` for nothing

`normalize(reflectedWorld)` in the water glint: that vector is a rotation of a unit
vector, so it is already unit length. The square root is gone.

### 11. Water ripples: two noise evaluations instead of six

The ripple normal was a finite difference of two noise layers: the height at the point
and at two offsets, per layer. That is six evaluations, and each evaluation is four
hashes, so 24 hashes for one water pixel — the most expensive single thing in the
default frame, on a surface that can fill the screen.

The patch is a smoothstep-interpolated bilinear surface, so its slope has a closed
form: the four corner hashes are already there, and the derivative of the smoothstep
weights (`6f(1-f)`) is one multiply each. `solNoiseSlope()` returns height and slope
together, the two layers cost two evaluations, and the eight hashes it saves per layer
buy the rest of the water shader. The finite difference's 0.08 step is kept as a gain,
so the amplitude is the one the pack shipped with.

### 12. The sky ray is per vertex

`skyViewRay()` rebuilt the view ray per pixel with an inverse projection and a divide,
on a third of the screen. The map from screen position to ray is affine, so it
interpolates exactly: the vertex stage now computes one ray per vertex and the
fragment stage normalises what arrives. Slightly smoother than "one per pixel" sounds,
because nothing is lost to interpolation.

### 13. A dependency the profile table hid

`composite2` (temporal AA, motion blur) and `final` both read the shaded scene from
`colortex1`, and `composite` is the pass that puts it there. But `composite` was only
enabled for the light shafts and the exposure average:

```
program.composite.enabled   = VOL_LIGHT || AUTO_EXPOSURE
program.composite2.enabled  = AA_TYPE == 1 || AA_TYPE == 2 || MOTION_BLUR
```

with `colortex1Clear = false`. So the **Beauty profile** — temporal AA on, shafts off,
exposure off — had `composite2` reading a buffer nothing had written this frame. That is
a real bug, not a performance note: it would have shown as a smeared or garbage frame
the moment anyone tried AA.

Fixed by making the dependency explicit: `composite` runs whenever anything downstream
reads `colortex1`. When only AA is on, that pass is a plain copy of the frame, which is
exactly what the pass after it needs.

## The budget, and what it says to ignore

At 1366x768 and 60 fps there are about 63 megapixels per second to shade, so:

| Resource | Available | Per pixel |
| --- | --- | --- |
| ALU (add/mul/mad) | ~184 G ops/s | ~2900 ops |
| Special functions (sin, exp2, log2, rcp, inversesqrt) | ~46 G ops/s | ~730 ops |
| Memory | 23 GB/s | ~365 bytes |

That table is why this branch looks the way it does. Four `sin()` calls per pixel, or
twelve, are not what is costing frames at 768p; a pass that reads and writes a
half-float buffer, an eight-attachment framebuffer, or a shadow map re-rendered every
frame are. The ordering of levers, best first:

1. Fewer passes, and fewer attachments per pass.
2. Narrower formats (this pack already uses `R11F_G11F_B10F` for the scene copy and
   `R16F` for the exposure value rather than RGBA16F).
3. Shadow resolution and distance before shadow filtering.
4. Then per-pixel arithmetic.

### Measured, derived, and folklore

Being explicit about which is which, since this file is making claims:

- **Documented**: special functions run at a quarter of the ALU rate (shaderLABS' cost
  model, matching Gen8's single extended-math FPU per EU); Intel supports seven
  framebuffer attachments; Iris binds eight when no directive is present; blending
  costs a framebuffer read that is skipped when blending is off; MRT costs bandwidth,
  not extra shading; `discard` can disable early-Z (NVIDIA's guidance — *not* documented
  for Intel, and unverified here).
- **Measured, on the wrong GPU**: a 1K-entry LUT beats `__sincosf` by 2x, but at 64M
  random samples it is 1.5x *slower*; and a 3-term polynomial for sin/cos was slower
  than the hardware function. Shape transferable, numbers not.
- **Derived arithmetic**: the table above, and the claim that a mul chain beats `pow()`
  up to about 16.
- **Folklore, repeated everywhere and unfalsifiable here**: "X gave me +20 fps". No
  pack author publishes per-pass timings, and this branch has not been run either.

## What I looked at and did not do

Being straight about the popular advice that does not pay here:

- **`a / b` → `a * rcp(b)`**, **`sqrt(a)` → `1 / inversesqrt(a)`**, **`normalize(v)` →
  `v * inversesqrt(dot(v, v))`**: the compiler already emits exactly those
  instructions. Writing them by hand changes nothing and makes the source worse.
- **`pow(a, b)` → `exp2(log2(a) * b)`**: that is what `pow` is. Where the exponent is a
  constant integer up to about 16 the pack uses a multiply chain, which *is* a win;
  above that the chain is longer than the two special functions and the `pow()` stays.
- **LUT textures for sin/cos**: the clearest "no" in the whole survey. A `sin` is one
  special function, no bytes, no cache; a LUT is a fetch that can miss, and the sampler
  L1 is only 4-8 KB. The measured LUT-vs-sincos numbers above lose at scale.
- **Polynomial sin/cos**: measured slower than the hardware function in the one
  benchmark I found, and it is three or four multiplies to save a quarter-rate op on a
  GPU where arithmetic is the resource we have spare.
- **LUT noise**: a genuinely tiny table (32x32, point filtered, inside the sampler's L1)
  is defensible; `noise.png` is bigger than that and `PACK_TEXTURES` therefore stays an
  option, off by default. The procedural hash chain is cheaper and cannot miss.
- **Half-rate post effects via `size.buffer` or `scale`**: both are Iris features and
  both are real (AO, bloom and exposure could each run at half resolution or in every
  other pixel). They are not done here because they need a resolve pass and a second
  buffer to land the result in, and a half-rate buffer cannot be written by a gbuffer
  program. That is a restructure, and restructuring passes while nothing can be
  compiled or looked at is how a saving turns into a bug. It is the next thing to try
  once the branch has been seen.
- **`texelFetch`**: needs GLSL 1.30; this pack targets `#version 120` so OptiFine and
  older Iris builds can read it.
- **`mediump`/half precision**: not available in desktop GLSL at all; that is an ES
  feature, and on desktop the precision conversion can cost more than it saves.
- **Compute shaders for lighting**: possible on this GPU (GL 4.4 through Mesa) but a
  different pipeline for a pack whose whole design is draw calls. Not a change to make
  blind.
- **Divergent branches**: the hot loops are all constant-count with early-outs, which
  is the property that matters; there is nothing to flatten.

## How to judge it

The two changes to look at are the terrain split and `VERTEX_LIGHTING`. Flip
`VERTEX_LIGHTING` between 0 and 1 and stand at a torch on a wall — that is where the
interpolation would show. The terrain split should be invisible, which is the point:
if anything changes except the frame rate, it is a bug.

`intel_gpu_top` while playing tells you whether you are GPU-bound (the GPU sits at 100%
and the CPU idles); if you are, these changes are the kind that matter. If the CPU is
the limit, no shader change will help and the JVM and render distance are the levers —
see [docs/linux-jvm.md](docs/linux-jvm.md).
