/* Solace - shadow.fsh
Depth only. The alpha test is what keeps leaves, grass and glass from casting
solid squares, so it has to be here and it has to be the same threshold the
solid geometry uses. */

#version 120

#include "/lib/config.glsl"
#include "/lib/shadowmap.glsl"

uniform sampler2D gcolor;

varying vec2 texcoord;
varying vec4 tint;

void main() {
    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    gl_FragData[0] = vec4(1.0);
}
