/* Solace - world-1/prepare.vsh
Nether entry point for the sky fill. */

#version 120

#define SOLACE_DIM_NETHER 1

varying vec2 texcoord;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
