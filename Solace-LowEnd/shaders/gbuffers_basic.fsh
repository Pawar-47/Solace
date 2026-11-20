/* Solace - gbuffers_basic.fsh
The tint, unchanged: outlines and selection boxes keep vanilla's colour. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"

varying vec4 tint;

void main() {
    gl_FragData[0] = tint;
}
