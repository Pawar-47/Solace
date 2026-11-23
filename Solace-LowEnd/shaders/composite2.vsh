/* Solace - composite2.vsh
Full-screen quad for the antialiasing and motion blur pass. */

#version 120

varying vec2 texcoord;

void main() {
    /* Not gl_ModelViewProjectionMatrix: the mods do not patch that built-in. */
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
