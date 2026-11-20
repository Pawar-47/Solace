/* Solace - world-1/gbuffers_skybasic.vsh
Nether sky: the dome is drawn with the Nether's ceiling colour. */

#version 120

#define SOLACE_DIM_NETHER 1

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
