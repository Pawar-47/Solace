/* Solace - prepare.vsh
Full-screen quad for the pass that fills the scene buffer before anything is drawn
into it, so a pixel nothing covers shows the horizon colour instead of the clear
colour. */

#version 120

varying vec2 texcoord;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
