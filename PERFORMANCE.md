# Performance experiments

This is the `perf-experiments` branch. `main` is untouched: it still has the pack as
it was, and its rolling `latest` release still points there. Nothing here ships until
it has been tried on the actual machine and has earned its place.

The target is an Intel HD 5500 — about 823 GFLOPs and 23 GB/s of shared memory
bandwidth, with no VRAM of its own. On a GPU like that, the bill is paid per pixel and
per byte moved, and the two currencies are not interchangeable: an ALU instruction is
cheap, a texture fetch and a full-screen write are not.

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
from the same source and nothing else changes.

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

## What I looked at and did not do

Being straight about the popular advice that does not pay here:

- **`a / b` → `a * rcp(b)`**, **`sqrt(a)` → `1 / inversesqrt(a)`**, **`normalize(v)` →
  `v * inversesqrt(dot(v, v))`**: the compiler already emits exactly those
  instructions. Writing them by hand changes nothing and makes the source worse.
- **`pow(a, b)` → `exp2(log2(a) * b)`**: that is what `pow` is. Where the exponent is a
  constant integer the pack already uses a multiply chain, which *is* a win.
- **LUT textures for sin/cos or noise**: a lookup is a texture fetch, and on this GPU
  bandwidth is the scarce resource, not ALU. The procedural noise here is already
  cheaper than fetching a texture would be — which is why `PACK_TEXTURES` exists as an
  option but defaults off.
- **`texelFetch`**: needs GLSL 1.30; this pack targets `#version 120` so OptiFine and
  older Iris builds can read it.
- **`mediump`/half precision**: not available in desktop GLSL at all; that is an ES
  feature.
- **Compute shaders for lighting**: possible on this GPU (GL 4.4 through Mesa) but a
  different pipeline for a pack whose whole design is draw calls. Not a change to make
  blind.
- **Divergent branches**: the hot loops are all constant-count with early-outs, which
  is the property that matters; there is nothing to flatten.

## How to judge it

Flip `VERTEX_LIGHTING` between 0 and 1 and look at a torch on a wall — that is where
the difference would show. `intel_gpu_top` while playing tells you whether you are
GPU-bound (the GPU sits at 100% and the CPU idles); if you are, these changes are the
kind that matter. If the CPU is the limit, no shader change will help and the JVM and
render distance are the levers — see [docs/linux-jvm.md](docs/linux-jvm.md).
