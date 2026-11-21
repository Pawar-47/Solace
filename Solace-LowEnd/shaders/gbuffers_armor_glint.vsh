/* Solace - gbuffers_armor_glint.vsh

The enchantment glint layer on armour, tools and books. It shares none of the
geometry vertex stage: it needs a texture coordinate and the tint, so this is
written out small instead of pulling in waving, fog and the rest.

The exposure it is divided by is read in the fragment stage, which can sample the
buffer it lives in. A vertex stage cannot do that without an extension, and the pack
targets GLSL 1.20.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;
varying vec4 tint;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    tint = gl_Color;
    gl_Position = ftransform();
}
