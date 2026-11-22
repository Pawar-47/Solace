/* Solace - shadow.vsh

The shadow pass, which only runs when SHADOWS is 1. Nothing here shades anything:
the vertex stage is the plain transform plus the texture coordinates, the tint and
the block id that decide which fragments are allowed to cast a shadow.

It is also where the shadow lock lives. A shader cannot ask the mod to skip a pass,
but it can push every vertex outside the clip volume, which culls the whole frame -
and because the shadow maps are never cleared (lib/buffers.glsl), the map from the
last drawn frame stays exactly where it was. With SHADOW_LOCK 64 the pass costs a
sixty-fourth of what it did, at the price of shadows that lag the world by a frame or
two.
*/

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
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;
    blockId = mc_Entity.x;

    #if SHADOW_LOCK > 0
        /* mod(), not %: the integer modulus operator is GLSL 1.30 and this pack is
           written for 1.20. The result is a whole number below SHADOW_LOCK. */
        if (mod(float(frameCounter), float(SHADOW_LOCK)) > 0.5) {
            /* Every vertex of every triangle lands at the same point behind the
               near plane, so nothing is rasterised and the old map survives. */
            gl_Position = vec4(0.0, 0.0, -2.0, 1.0);
            return;
        }
    #endif

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
