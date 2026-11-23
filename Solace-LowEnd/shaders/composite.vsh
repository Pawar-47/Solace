/* Solace - composite.vsh
Full-screen quad for the light-shaft and exposure pass. */

#version 120

varying vec2 texcoord;

void main() {
    /* gl_ModelViewProjectionMatrix is one of the legacy built-ins the mods do NOT
       patch - the documented list has gl_ModelViewMatrix and gl_ProjectionMatrix, and
       nothing that multiplies them for you. In this pass the model-view is identity, so
       the product is the projection. */
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
