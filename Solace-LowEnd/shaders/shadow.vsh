/* Solace - shadow.vsh
The shadow pass, which only runs when SHADOWS is 1. Nothing here shades anything:
the vertex stage is the plain transform plus the texture coordinates, the tint and
the block id that decide which fragments are allowed to cast a shadow. */

#version 120

#include "/lib/config.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/blockids.glsl"
#include "/lib/shadowmap.glsl"

attribute vec4 mc_Entity;

varying vec2 texcoord;
varying vec4 tint;
varying float blockId;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;
    blockId = mc_Entity.x;
}
