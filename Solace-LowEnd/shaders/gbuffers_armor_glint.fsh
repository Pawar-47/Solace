/* Solace - gbuffers_armor_glint.fsh

The glint is additive sparkle over the item, so it is brightened and kept mostly
transparent, and divided by the current exposure: the final pass multiplies the whole
picture by the exposure, and a sparkle that is supposed to read as pure light should
not ride up and down with it.

The exposure is read here, not in the vertex stage: implicit-LOD sampling exists in a
fragment shader and not in a vertex one.
*/

#version 120

/* DRAWBUFFERS:0 - at the top with the rest of the pack, not after main(). */

#include "/lib/config.glsl"
#include "/lib/math.glsl"

uniform sampler2D gtexture;

/* The exposure value the exposure pass leaves in gaux3 (colortex6), the same for every
   pixel. */
#if AUTO_EXPOSURE == 1
    uniform sampler2D colortex6;
#endif

varying vec2 texcoord;
varying vec4 tint;

void main() {
    vec4 glint = texture2D(gtexture, texcoord) * tint;
    if (glint.a < 0.01) discard;

    float exposure = EXPOSURE;
    #if AUTO_EXPOSURE == 1
        float kept = texture2D(colortex6, vec2(0.5)).r;
        exposure = kept > 0.0 ? kept : 1.0;
    #endif

    gl_FragData[0] = vec4(glint.rgb * (1.50 / max(exposure, 0.05)),
                          glint.a * 0.85);
}
