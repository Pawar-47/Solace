/* Solace - gbuffers_basic.fsh

The vertex colour times the light the vertex stage worked out: one multiply, which is
all a block outline or a leash can show.
*/

#version 120

/* One target. The directive below is alone on its line, and nothing may follow it: the
   mod reads every character between its colon and its closing marker as a buffer index,
   so a dash and a note are read as index -1 and the game stops with
   "Index -1 out of bounds for length 32". Explanations go above it, like this one. */
/* DRAWBUFFERS:0 */

#include "/lib/config.glsl"
#include "/lib/math.glsl"

varying vec4 tint;
varying vec3 basicLight;

void main() {
    gl_FragData[0] = vec4(tint.rgb * basicLight, tint.a);
}
