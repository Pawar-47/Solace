/* Solace - world1/gbuffers_skybasic.vsh
End sky: the void and the star field, with the End palette. */

#version 120

#define SOLACE_DIM_END 1

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
