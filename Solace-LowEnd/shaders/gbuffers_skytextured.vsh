/* Solace - gbuffers_skytextured.vsh
Sun and moon quads, textured and tinted by vanilla, with the same sub-pixel jitter
as the rest of the frame so the temporal antialiasing does not smear them. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;
varying vec4 tint;

void main() {
    /* Not gl_ModelViewProjectionMatrix: the mods do not patch that built-in. */
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;

    /* The same jitter the geometry gets, from lib/uniforms.glsl, so the sun and moon do
       not drift against the sky they sit in. */
    #if AA_TYPE == 1 || AA_TYPE == 2
        gl_Position.xy += solaceJitter() * gl_Position.w;
    #endif
}
