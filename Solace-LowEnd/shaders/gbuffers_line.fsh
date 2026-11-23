/* Solace - gbuffers_line.fsh
The line colour, unchanged. */

#version 120

/* DRAWBUFFERS:0 - at the top with the other programs, not after main(): the directive
   belongs to the program, and a reader should meet it before the code it applies to. */

#include "/lib/config.glsl"
#include "/lib/math.glsl"

varying vec4 tint;

void main() {
    gl_FragData[0] = tint;
}
