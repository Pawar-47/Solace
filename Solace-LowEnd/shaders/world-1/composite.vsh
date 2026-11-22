/* Solace - world-1/composite.vsh
Nether light shafts and exposure pass. */

#version 120

#define SOLACE_DIM_NETHER 1

#include "/lib/config.glsl"

varying vec2 texcoord;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
