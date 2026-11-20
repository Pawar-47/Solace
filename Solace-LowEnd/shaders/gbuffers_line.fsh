/* Solace - gbuffers_line.fsh
The line colour, unchanged. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"

varying vec4 tint;

void main() {
    gl_FragData[0] = tint;
}
