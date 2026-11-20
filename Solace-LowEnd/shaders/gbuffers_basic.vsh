/* Solace - gbuffers_basic.vsh
Untextured vanilla geometry: the block outline, the hitting box, debug shapes.
They carry their colour in the vertex colour, so that is all that is passed on. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec4 tint;

void main() {
    gl_Position = ftransform();
    tint = gl_Color;
}
