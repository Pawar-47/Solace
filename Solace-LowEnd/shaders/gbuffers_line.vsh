/* Solace - gbuffers_line.vsh
Debug lines and the fishing line. Same treatment as untextured geometry. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec4 tint;

void main() {
    /* Not gl_ModelViewProjectionMatrix: the mods do not patch that built-in. */
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    tint = gl_Color;
}
