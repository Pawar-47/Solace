/* Solace - gbuffers_skybasic.vsh
The sky dome. Only the texture coordinates are needed: the fragment stage
rebuilds a ray per pixel from the projection matrices, so the dome shape does
not matter. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
