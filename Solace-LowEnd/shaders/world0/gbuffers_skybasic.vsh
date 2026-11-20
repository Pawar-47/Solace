/* Solace - world0/gbuffers_skybasic.vsh
Overworld sky. Only the texture coordinates matter: the fragment stage rebuilds a
ray per pixel. */

#version 120

#define SOLACE_DIM_OVERWORLD 1

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;
/* The ray, worked out once per vertex instead of once per sky pixel. */
varying vec3 skyRay;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    vec4 ray = gbufferProjectionInverse
             * vec4(gl_Position.xy / gl_Position.w, 1.0, 1.0);
    skyRay = ray.xyz / ray.w;
}
