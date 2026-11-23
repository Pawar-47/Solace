/* Solace - gbuffers_basic.fsh

The vertex colour times the light the vertex stage worked out: one multiply, which is
all a block outline or a leash can show.
*/

#version 120

/* DRAWBUFFERS:0 - at the top with the other programs, not after main(): the directive
   belongs to the program, and a reader should meet it before the code it applies to. */

#include "/lib/config.glsl"
#include "/lib/math.glsl"

varying vec4 tint;
varying vec3 basicLight;

void main() {
    gl_FragData[0] = vec4(tint.rgb * basicLight, tint.a);
}
