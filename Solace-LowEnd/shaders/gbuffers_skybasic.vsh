/* Solace - gbuffers_skybasic.vsh
The sky dome. The texture coordinates are all the fragment stage needs, and the
sub-pixel jitter belongs here too: if the sky does not move with the temporal
antialiasing, every edge against it smears. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

void main() {
    /* Not gl_ModelViewProjectionMatrix: the mods do not patch that built-in. */
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    /* The same jitter the geometry gets, from lib/uniforms.glsl. A four-phase square
       pattern here used to disagree with the geometry's eight-phase one, and the
       disagreement is what the history cannot absorb: a smeared horizon. */
    #if AA_TYPE == 1 || AA_TYPE == 2
        gl_Position.xy += solaceJitter() * gl_Position.w;
    #endif
}
