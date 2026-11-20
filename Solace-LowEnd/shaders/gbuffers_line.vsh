/* Solace - gbuffers_line.vsh
Debug lines and the fishing line. Same treatment as untextured geometry. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec4 tint;

void main() {
    gl_Position = ftransform();
    tint = gl_Color;
}
