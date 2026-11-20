/* Solace - shadow.vsh
The shadow pass, which only runs when SHADOWS is 1. Nothing here shades
anything: the vertex stage is the plain transform plus the texture coordinates
and tint the fragment stage needs for its alpha test. */

#version 120

#include "/lib/config.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/shadowmap.glsl"

varying vec2 texcoord;
varying vec4 tint;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;
}
