/* Solace - gbuffers_armor_glint.fsh
The glint is additive sparkle over the item, so it is brightened and kept mostly
transparent. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"

uniform sampler2D gcolor;

void main() {
    vec4 glint = texture2D(gcolor, texcoord) * tint;
    if (glint.a < 0.01) discard;

    gl_FragData[0] = vec4(glint.rgb * 1.50, glint.a * 0.85);
}
