/* Solace - gbuffers_armor_glint.vsh

The enchantment glint layer on armour, tools and books. It shares none of the
geometry vertex stage: it needs a texture coordinate, the tint, and the exposure the
final pass will apply, so this is written out small instead of pulling in waving,
fog and the rest.

The exposure comes from the same buffer the reference reads for its glint
(gaux3 there, colortex6 here), so with auto exposure on the sparkle keeps a fixed
brightness instead of brightening with the rest of the picture.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

uniform sampler2D colortex6;

varying vec2 texcoord;
varying vec4 tint;
varying float glintExposure;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;
    gl_Position = ftransform();

    #if AUTO_EXPOSURE == 1
        float kept = texture2D(colortex6, vec2(0.5)).r;
        glintExposure = kept > 0.0 ? kept : 1.0;
    #else
        glintExposure = EXPOSURE;
    #endif
}
