/* Solace - gbuffers_basic.fsh

The vertex colour times the light the vertex stage worked out: one multiply, which is
all a block outline or a leash can show.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"

/* DRAWBUFFERS:0 */

varying vec4 tint;
varying vec3 basicLight;

void main() {
    gl_FragData[0] = vec4(tint.rgb * basicLight, tint.a);
}
