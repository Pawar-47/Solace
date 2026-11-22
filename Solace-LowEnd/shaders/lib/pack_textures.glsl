/* Solace - lib/pack_textures.glsl

The pack's optional texture file. Nothing here is needed for the pack to work: the
water ripples and the cloud density are computed in the shader, which is why a fresh
copy without these files still renders.

With PACK_TEXTURES 1 the sampler below is declared and the shaders read it instead.

The name matters, and it is not free. `noisetex` is the one sampler the loader binds by
itself, and by default it binds the loader's own random noise at
`noiseTextureResolution` - not this file. Pointing it here is one properties line,
`texture.noise = textures/noise.png` in shaders.properties (shipped commented out,
because the png is generated rather than committed). Without it PACK_TEXTURES 1 reads
random noise instead of the ripple field: it still draws, but it is not what the option
says. Anything else has to be bound to one of the fixed buffer names with a
`texture.<program>.<name>` line. This file used to declare samplers called `noise` and
`clouds`, which nothing binds: the first fetch from either returned an unbound texture,
so the option quietly turned the water black. Everything reads `noisetex` now, which
needs at most that one line and cannot go stale.

Generate the file once with textures/generate_textures.py - it is not shipped as a
binary, nothing here is copied from another pack, and one run is enough for every
installation. */

#ifndef SOLACE_PACK_TEXTURES
#define SOLACE_PACK_TEXTURES

#include "/lib/config.glsl"

#if PACK_TEXTURES == 1 || CLOUD_STYLE == 2

/* 256x256 RGB, tileable. R and G are two independent ripple fields for the water, and
   R is also the cloud density when the cloud style asks for a texture. */
uniform sampler2D noisetex;

#endif

#endif
