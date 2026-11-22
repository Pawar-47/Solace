/* Solace - world0/prepare.vsh
Overworld entry point for the sky fill. */

#version 120

#define SOLACE_DIM_OVERWORLD 1

varying vec2 texcoord;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
