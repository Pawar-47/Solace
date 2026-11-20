/* Solace - gbuffers_basic.fsh

The vertex colour times the light the vertex stage worked out. The reference's
`basic_blocks_fragment.glsl` is exactly this: `blockColor.rgb *= basicLight`.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"

varying vec4 tint;
varying vec3 basicLight;

void main() {
    gl_FragData[0] = vec4(tint.rgb * basicLight, tint.a);
}
