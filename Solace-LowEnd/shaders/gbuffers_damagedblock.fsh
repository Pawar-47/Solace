/* Solace - gbuffers_damagedblock.fsh
The overlay is drawn a little in front of the block, so it must not be lit or
fogged - only its own alpha matters. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"

uniform sampler2D gcolor;

void main() {
    vec4 crack = texture2D(gcolor, texcoord) * tint;
    if (crack.a < 0.02) discard;

    gl_FragData[0] = vec4(crack.rgb, crack.a);
}
