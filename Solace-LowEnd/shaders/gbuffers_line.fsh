/* Solace - gbuffers_line.fsh
The line colour, unchanged. */

#version 120

/* One target. The directive below is alone on its line, and nothing may follow it: the
   mod reads every character between its colon and its closing marker as a buffer index,
   so a dash and a note are read as index -1 and the game stops with
   "Index -1 out of bounds for length 32". Explanations go above it, like this one. */
/* DRAWBUFFERS:0 */

#include "/lib/config.glsl"
#include "/lib/math.glsl"

varying vec4 tint;

void main() {
    gl_FragData[0] = tint;
}
