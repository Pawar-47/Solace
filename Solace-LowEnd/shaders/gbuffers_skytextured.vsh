/* Solace - gbuffers_skytextured.vsh
Sun and moon quads, textured and tinted by vanilla. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;
varying vec4 tint;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;
}
