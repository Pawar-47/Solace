/* Solace - lib/pack_textures.glsl

The pack's optional texture files. Nothing here is needed for the pack to work: the
water ripples and the cloud density are computed in the shader, which is why a fresh
copy without these files still renders.

With PACK_TEXTURES 1 the samplers below are declared and the shaders read them
instead. Iris binds a declared sampler named `noise` to textures/noise.png and one
named `clouds` to textures/clouds.png, so the files have to carry those names.

Generate them once with textures/generate_textures.py - they are not shipped as
binaries, nothing here is copied from another pack, and one run is enough for every
installation. */

#ifndef SOLACE_PACK_TEXTURES
#define SOLACE_PACK_TEXTURES

#include "/lib/config.glsl"

#if PACK_TEXTURES == 1

/* 256x256 RGB. R and G are two independent ripple fields, B is unused. */
uniform sampler2D noise;

/* 512x512 grey. A tileable fBm field: the cloud density the march reads. */
uniform sampler2D clouds;

/* The blocky style of the cloud texture, same field with two octaves. */
uniform sampler2D clouds_blocky;

#endif

#endif
