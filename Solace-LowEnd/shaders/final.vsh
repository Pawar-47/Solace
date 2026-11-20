/* Solace - final.vsh
One full-screen quad, texture coordinates from the model matrix. */

#version 120

varying vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
