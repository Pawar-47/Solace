/* Solace - gbuffers_armor_glint.fsh

The glint is additive sparkle over the item, so it is brightened and kept mostly
transparent, and divided by the exposure the vertex stage fetched: the final pass
multiplies the whole picture by the exposure, and a sparkle that is supposed to read
as pure light should not ride up and down with it.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"

uniform sampler2D gcolor;

varying vec2 texcoord;
varying vec4 tint;
varying float glintExposure;

void main() {
    vec4 glint = texture2D(gcolor, texcoord) * tint;
    if (glint.a < 0.01) discard;

    gl_FragData[0] = vec4(glint.rgb * (1.50 / max(glintExposure, 0.05)),
                          glint.a * 0.85);
}
